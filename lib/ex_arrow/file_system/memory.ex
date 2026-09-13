defmodule ExArrow.FileSystem.Memory do
  @moduledoc """
  In-memory filesystem for Dataset discovery tests.

  Holds a flat map of normalized absolute paths to entries. Adding a file
  also registers parent directories so `list/3` can walk a Hive-style tree
  without touching the OS.

  ## Fields

  * `:entries` — `%{path => ExArrow.FileSystem.entry()}`

  ## Examples

      iex> {:ok, fs} = ExArrow.FileSystem.Memory.new(%{"/data/a.parquet" => 128})
      iex> ExArrow.FileSystem.exists?(fs, "/data/a.parquet")
      true

      iex> fs = ExArrow.FileSystem.Memory.new()
      iex> {:ok, fs} = ExArrow.FileSystem.Memory.put_file(fs, "/data/year=2026/part.parquet", size: 64)
      iex> {:ok, paths} = ExArrow.FileSystem.glob(fs, "/data/**/*.parquet")
      iex> paths
      ["/data/year=2026/part.parquet"]
  """

  @behaviour ExArrow.FileSystem

  alias ExArrow.FileSystem

  defstruct entries: %{}

  @typedoc "Internal path => entry map."
  @type entry_map :: %{optional(String.t()) => FileSystem.entry()}

  @typedoc """
  Memory filesystem handle.

  ## Fields

    * `:entries` — normalized paths to `t:ExArrow.FileSystem.entry/0` maps
  """
  @type t :: %__MODULE__{entries: entry_map()}

  @doc """
  Build an empty memory filesystem.

  ## Examples

      iex> %ExArrow.FileSystem.Memory{entries: %{}} = ExArrow.FileSystem.Memory.new()
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Build a memory filesystem from a path → size map or `{path, size}` list.

  ## Parameters

    * `seed` — `%{path => size}` or `[{path, size}, ...]` where `size` is a
      non-negative integer (file byte size)

  ## Returns

    * `{:ok, fs}` on success
    * `{:error, message}` for invalid paths or sizes

  ## Examples

      iex> {:ok, fs} = ExArrow.FileSystem.Memory.new(%{"/data/a.parquet" => 10})
      iex> ExArrow.FileSystem.exists?(fs, "/data")
      true
  """
  @spec new(map() | [{String.t(), non_neg_integer()}]) ::
          {:ok, t()} | {:error, String.t()}
  def new(seed) when is_map(seed), do: seed |> Map.to_list() |> new_from_list()
  def new(seed) when is_list(seed), do: new_from_list(seed)

  @doc """
  Register a file at `path` with `size` (default `0`).

  Creates missing parent directories. Returns `{:ok, fs}` or `{:error, msg}`.

  ## Parameters

    * `fs` — memory filesystem
    * `path` — absolute-style path string (normalized with a leading `/`)
    * `opts`:

      * `:size` — non-negative integer byte size (default `0`)

  ## Examples

      iex> fs = ExArrow.FileSystem.Memory.new()
      iex> {:ok, fs} = ExArrow.FileSystem.Memory.put_file(fs, "/data/x.parquet", size: 32)
      iex> ExArrow.FileSystem.exists?(fs, "/data/x.parquet")
      true
  """
  @spec put_file(t(), String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def put_file(fs, path, opts \\ [])

  def put_file(%__MODULE__{} = fs, path, opts) when is_binary(path) and is_list(opts) do
    with :ok <- validate_put_opts(opts),
         {:ok, norm} <- normalize_path(path) do
      size = Keyword.get(opts, :size, 0)

      if not is_integer(size) or size < 0 do
        {:error, "size must be a non-negative integer"}
      else
        entries =
          norm
          |> parent_dirs()
          |> Enum.reduce(fs.entries, fn dir, acc ->
            Map.put_new(acc, dir, %{path: dir, type: :directory, size: 0})
          end)
          |> Map.put(norm, %{path: norm, type: :file, size: size})

        {:ok, %{fs | entries: entries}}
      end
    end
  end

  def put_file(%__MODULE__{}, path, _opts) when not is_binary(path),
    do: {:error, "path must be a UTF-8 string"}

  def put_file(%__MODULE__{}, _path, opts) when not is_list(opts),
    do: {:error, "opts must be a keyword list"}

  @impl true
  def list(%__MODULE__{} = fs, path, opts) when is_binary(path) and is_list(opts) do
    recursive = Keyword.get(opts, :recursive, true)
    ignore_hidden = Keyword.get(opts, :ignore_hidden, true)

    with {:ok, root} <- normalize_path(path) do
      list_at(fs, root, recursive, ignore_hidden)
    end
  end

  defp list_at(fs, root, recursive, ignore_hidden) do
    case Map.fetch(fs.entries, root) do
      {:ok, %{type: :file} = entry} ->
        list_file_entry(entry, root, ignore_hidden)

      {:ok, %{type: :directory}} ->
        {:ok, select_children(fs, root, recursive, ignore_hidden, include_root?: false)}

      :error ->
        if implicit_dir?(fs, root) do
          {:ok, select_children(fs, root, recursive, ignore_hidden, include_root?: false)}
        else
          {:error, "path does not exist: #{root}"}
        end
    end
  end

  defp list_file_entry(entry, root, ignore_hidden) do
    if ignore_hidden and FileSystem.path_has_hidden_component?(root) do
      {:ok, []}
    else
      {:ok, [entry]}
    end
  end

  defp select_children(fs, root, recursive, ignore_hidden, include_root?: include_root?) do
    fs.entries
    |> Map.values()
    |> Enum.filter(fn %{path: p} -> child_path?(p, root, recursive, include_root?) end)
    |> Enum.reject(fn %{path: p} ->
      ignore_hidden and hidden_under_root?(p, root)
    end)
    |> Enum.sort_by(& &1.path)
  end

  defp child_path?(path, root, recursive, include_root?) do
    cond do
      path == root -> include_root?
      not under?(path, root) -> false
      recursive -> true
      true -> Path.dirname(path) == root
    end
  end

  @impl true
  def glob(%__MODULE__{} = fs, pattern, opts) when is_binary(pattern) and is_list(opts) do
    ignore_hidden = Keyword.get(opts, :ignore_hidden, true)

    with {:ok, norm_pat} <- normalize_path(pattern) do
      paths =
        fs.entries
        |> Map.values()
        |> Enum.filter(&(&1.type == :file))
        |> Enum.map(& &1.path)
        |> Enum.filter(&FileSystem.match_glob?(&1, norm_pat))
        |> Enum.reject(fn p ->
          ignore_hidden and FileSystem.path_has_hidden_component?(p)
        end)
        |> Enum.sort()

      {:ok, paths}
    end
  end

  @impl true
  def exists?(%__MODULE__{} = fs, path) when is_binary(path) do
    case normalize_path(path) do
      {:ok, root} ->
        Map.has_key?(fs.entries, root) or implicit_dir?(fs, root)

      {:error, _} ->
        false
    end
  end

  defp new_from_list(list) do
    Enum.reduce_while(list, {:ok, %__MODULE__{}}, fn
      {path, size}, {:ok, fs} when is_binary(path) and is_integer(size) and size >= 0 ->
        case put_file(fs, path, size: size) do
          {:ok, fs2} -> {:cont, {:ok, fs2}}
          {:error, _} = err -> {:halt, err}
        end

      other, _ ->
        {:halt, {:error, "seed entries must be {path, size} pairs, got: #{inspect(other)}"}}
    end)
  end

  defp validate_put_opts(opts) do
    if Keyword.keyword?(opts) do
      bad = Enum.reject(Keyword.keys(opts), &(&1 in [:size]))

      if bad == [], do: :ok, else: {:error, "unknown option(s): #{inspect(bad)}"}
    else
      {:error, "opts must be a keyword list"}
    end
  end

  defp normalize_path(path) when is_binary(path) do
    if String.valid?(path) do
      norm =
        path
        |> String.replace("\\", "/")
        |> String.replace(~r/\/+/, "/")
        |> ensure_absolute()
        |> trim_trailing_slash()

      if norm == "" do
        {:error, "path must be a UTF-8 string"}
      else
        {:ok, norm}
      end
    else
      {:error, "path must be a UTF-8 string"}
    end
  end

  defp ensure_absolute("/" <> _ = path), do: path
  defp ensure_absolute(path), do: "/" <> path

  defp trim_trailing_slash("/"), do: "/"
  defp trim_trailing_slash(path), do: String.trim_trailing(path, "/")

  defp parent_dirs("/"), do: []

  defp parent_dirs(path) do
    path
    |> Path.split()
    |> Enum.drop(-1)
    |> Enum.scan(fn part, acc -> Path.join(acc, part) end)
    |> Enum.map(fn
      "/" <> _ = p -> p
      p -> "/" <> p
    end)
  end

  defp under?(path, root) do
    root == "/" or String.starts_with?(path, root <> "/")
  end

  defp implicit_dir?(%__MODULE__{entries: entries}, root) do
    Enum.any?(entries, fn {p, _} -> under?(p, root) end)
  end

  defp hidden_under_root?(path, root) do
    relative =
      cond do
        root == "/" -> path
        String.starts_with?(path, root <> "/") -> String.replace_prefix(path, root <> "/", "")
        true -> path
      end

    relative
    |> Path.split()
    |> Enum.any?(&FileSystem.hidden_basename?/1)
  end
end
