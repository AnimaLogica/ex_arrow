defmodule ExArrow.FileSystem do
  @moduledoc """
  Capability-oriented filesystem abstraction for Dataset discovery.

  Reads still go through path-based NIFs (`Parquet`, `IPC`). This module only
  answers discovery questions: what paths exist, which match a glob, and
  whether a path is present.

  ## Implementations

  - `ExArrow.FileSystem.Local` — OS filesystem (default for Dataset)
  - `ExArrow.FileSystem.Memory` — in-memory tree for tests (no tmp dirs)

  S3 / object-store adapters are out of scope for 0.9.0; the behaviour leaves
  room for them later.

  ## Hidden entries

  When `ignore_hidden: true` (the default), any path component whose basename
  starts with `.` or `_` is skipped. That matches Dataset's
  `:ignore_hidden` option (dotfiles and `_`-prefixed Hive / staging dirs).

  ## Typical usage

      fs = ExArrow.FileSystem.Local.new()
      {:ok, entries} = ExArrow.FileSystem.list(fs, "/data/events", recursive: true)
      {:ok, paths} = ExArrow.FileSystem.glob(fs, "/data/events/**/*.parquet")
      true = ExArrow.FileSystem.exists?(fs, "/data/events")

      {:ok, dataset} = ExArrow.Dataset.open("/data/events", filesystem: fs)
  """

  @typedoc "Filesystem handle (struct whose module implements this behaviour)."
  @type t :: struct()

  @typedoc """
  One discovered path.

  ## Keys

    * `:path` — absolute or normalized path string
    * `:type` — `:file` or `:directory`
    * `:size` — byte size for files; `0` for directories (and when unknown)
  """
  @type entry :: %{
          path: String.t(),
          type: :file | :directory,
          size: non_neg_integer()
        }

  @typedoc "Option for `list/3`."
  @type list_opt :: {:recursive, boolean()} | {:ignore_hidden, boolean()}

  @typedoc "Option for `glob/3`."
  @type glob_opt :: {:ignore_hidden, boolean()}

  @callback list(t(), String.t(), keyword()) :: {:ok, [entry()]} | {:error, String.t()}
  @callback glob(t(), String.t(), keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  @callback exists?(t(), String.t()) :: boolean()

  @doc """
  List entries under `path`.

  ## Parameters

    * `fs` — filesystem handle (`Local` or `Memory`)
    * `path` — directory or file to list
    * `opts`:

      * `:recursive` — when `true` (default), walk the whole tree; when
        `false`, only immediate children
      * `:ignore_hidden` — when `true` (default), skip `.` / `_`-prefixed names

  ## Returns

    * `{:ok, entries}` — list of `t:entry/0` maps, typically path-sorted
    * `{:error, message}` — missing path, invalid opts, or backend failure

  ## Examples

      fs = ExArrow.FileSystem.Local.new()
      {:ok, entries} = ExArrow.FileSystem.list(fs, "/data/events", recursive: false)
      Enum.map(entries, &{&1.type, &1.path})
  """
  @spec list(t(), String.t(), [list_opt()]) :: {:ok, [entry()]} | {:error, String.t()}
  def list(fs, path, opts \\ [])

  def list(%mod{} = fs, path, opts) when is_binary(path) and is_list(opts) do
    with :ok <- validate_opts(opts, [:recursive, :ignore_hidden]) do
      mod.list(fs, path, opts)
    end
  end

  def list(_fs, path, _opts) when not is_binary(path),
    do: {:error, "path must be a UTF-8 string"}

  def list(_fs, _path, opts) when not is_list(opts),
    do: {:error, "opts must be a keyword list"}

  @doc """
  Return file paths matching `pattern` (sorted).

  Patterns use `/` separators. `*` matches within one path segment; `**`
  matches across segments (including zero segments).

  ## Parameters

    * `fs` — filesystem handle
    * `pattern` — glob string (for example `"/data/**/*.parquet"`)
    * `opts`:

      * `:ignore_hidden` — when `true` (default), skip matches with a `.` /
        `_`-prefixed path component

  ## Returns

    * `{:ok, paths}` — sorted list of matching **file** paths
    * `{:error, message}` — invalid pattern or opts

  ## Examples

      fs = ExArrow.FileSystem.Local.new()
      {:ok, paths} = ExArrow.FileSystem.glob(fs, "/data/events/year=*/**/*.parquet")
  """
  @spec glob(t(), String.t(), [glob_opt()]) :: {:ok, [String.t()]} | {:error, String.t()}
  def glob(fs, pattern, opts \\ [])

  def glob(%mod{} = fs, pattern, opts) when is_binary(pattern) and is_list(opts) do
    with :ok <- validate_opts(opts, [:ignore_hidden]) do
      mod.glob(fs, pattern, opts)
    end
  end

  def glob(_fs, pattern, _opts) when not is_binary(pattern),
    do: {:error, "pattern must be a UTF-8 string"}

  def glob(_fs, _pattern, opts) when not is_list(opts),
    do: {:error, "opts must be a keyword list"}

  @doc """
  Return whether `path` exists as a file or directory.

  ## Parameters

    * `fs` — filesystem handle
    * `path` — path string (non-binaries return `false`)

  ## Examples

      fs = ExArrow.FileSystem.Local.new()
      ExArrow.FileSystem.exists?(fs, "/data/events")
  """
  @spec exists?(t(), String.t()) :: boolean()
  def exists?(%mod{} = fs, path) when is_binary(path), do: mod.exists?(fs, path)
  def exists?(_fs, _path), do: false

  @doc false
  @spec hidden_basename?(String.t()) :: boolean()
  def hidden_basename?(name) when is_binary(name) do
    name != "." and name != ".." and
      (String.starts_with?(name, ".") or String.starts_with?(name, "_"))
  end

  @doc false
  @spec path_has_hidden_component?(String.t()) :: boolean()
  def path_has_hidden_component?(path) when is_binary(path) do
    path
    |> Path.split()
    |> Enum.any?(&hidden_basename?/1)
  end

  @doc false
  @spec match_glob?(String.t(), String.t()) :: boolean()
  def match_glob?(path, pattern) when is_binary(path) and is_binary(pattern) do
    match_parts?(Path.split(path), Path.split(pattern))
  end

  defp match_parts?([], []), do: true
  defp match_parts?(_path, ["**"]), do: true

  defp match_parts?(path, ["**" | rest_pat]) do
    Enum.any?(0..length(path), fn n ->
      match_parts?(Enum.drop(path, n), rest_pat)
    end)
  end

  defp match_parts?([name | path_rest], [pat | pat_rest]) do
    match_segment?(name, pat) and match_parts?(path_rest, pat_rest)
  end

  defp match_parts?([], _pat), do: false
  defp match_parts?(_path, []), do: false

  defp match_segment?(_name, "*"), do: true

  defp match_segment?(name, pat) do
    if String.contains?(pat, "*") do
      regex =
        pat
        |> Regex.escape()
        |> String.replace("\\*", ".*")
        |> then(&("^" <> &1 <> "$"))
        |> Regex.compile!()

      Regex.match?(regex, name)
    else
      name == pat
    end
  end

  defp validate_opts(opts, allowed) do
    if Keyword.keyword?(opts) do
      bad = Enum.reject(Keyword.keys(opts), &(&1 in allowed))

      if bad == [] do
        :ok
      else
        {:error, "unknown option(s): #{inspect(bad)}"}
      end
    else
      {:error, "opts must be a keyword list"}
    end
  end
end
