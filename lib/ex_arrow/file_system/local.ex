defmodule ExArrow.FileSystem.Local do
  @moduledoc """
  Local OS filesystem implementation of `ExArrow.FileSystem`.

  Paths are expanded with `Path.expand/1` before use. File contents are not
  read here; Dataset / Parquet NIFs open paths returned by discovery.

  ## Example

      fs = ExArrow.FileSystem.Local.new()
      {:ok, entries} = ExArrow.FileSystem.list(fs, "/data/events")
      {:ok, paths} = ExArrow.FileSystem.glob(fs, "/data/**/*.parquet")
      ExArrow.FileSystem.exists?(fs, "/data/events")
  """

  @behaviour ExArrow.FileSystem

  alias ExArrow.FileSystem

  defstruct []

  @typedoc "Empty handle; all state is the OS filesystem."
  @type t :: %__MODULE__{}

  @doc """
  Build a local filesystem handle.

  ## Examples

      iex> %ExArrow.FileSystem.Local{} = ExArrow.FileSystem.Local.new()
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @impl true
  def list(%__MODULE__{}, path, opts) when is_binary(path) and is_list(opts) do
    recursive = Keyword.get(opts, :recursive, true)
    ignore_hidden = Keyword.get(opts, :ignore_hidden, true)
    root = Path.expand(path)

    cond do
      not File.exists?(root) ->
        {:error, "path does not exist: #{root}"}

      File.regular?(root) ->
        list_file(root, ignore_hidden)

      File.dir?(root) ->
        case collect_dir(root, recursive, ignore_hidden) do
          {:ok, entries} -> {:ok, Enum.sort_by(entries, & &1.path)}
          {:error, _} = err -> err
        end

      true ->
        {:error, "path is not a file or directory: #{root}"}
    end
  end

  @impl true
  def glob(%__MODULE__{}, pattern, opts) when is_binary(pattern) and is_list(opts) do
    ignore_hidden = Keyword.get(opts, :ignore_hidden, true)

    try do
      paths =
        pattern
        |> Path.wildcard(match_dot: not ignore_hidden)
        |> Enum.filter(&File.regular?/1)
        |> Enum.map(&Path.expand/1)
        |> Enum.reject(fn p ->
          ignore_hidden and FileSystem.path_has_hidden_component?(p)
        end)
        |> Enum.sort()

      {:ok, paths}
    rescue
      e in [ErlangError, ArgumentError] ->
        {:error, "invalid glob pattern: #{Exception.message(e)}"}
    end
  end

  @impl true
  def exists?(%__MODULE__{}, path) when is_binary(path) do
    File.exists?(Path.expand(path))
  end

  defp list_file(root, ignore_hidden) do
    if ignore_hidden and FileSystem.path_has_hidden_component?(root) do
      {:ok, []}
    else
      case file_entry(root) do
        {:ok, entry} -> {:ok, [entry]}
        {:error, _} = err -> err
      end
    end
  end

  defp collect_dir(dir, recursive, ignore_hidden) do
    case File.ls(dir) do
      {:ok, names} -> reduce_names(Enum.sort(names), dir, recursive, ignore_hidden, [])
      {:error, reason} -> {:error, "cannot list #{dir}: #{inspect(reason)}"}
    end
  end

  defp reduce_names([], _dir, _recursive, _ignore_hidden, acc), do: {:ok, acc}

  defp reduce_names([name | rest], dir, recursive, ignore_hidden, acc) do
    if ignore_hidden and FileSystem.hidden_basename?(name) do
      reduce_names(rest, dir, recursive, ignore_hidden, acc)
    else
      case append_child(Path.join(dir, name), recursive, ignore_hidden, acc) do
        {:ok, acc2} -> reduce_names(rest, dir, recursive, ignore_hidden, acc2)
        {:error, _} = err -> err
      end
    end
  end

  defp append_child(full, recursive, ignore_hidden, acc) do
    cond do
      File.dir?(full) ->
        entry = %{path: full, type: :directory, size: 0}

        if recursive do
          case collect_dir(full, true, ignore_hidden) do
            {:ok, child} -> {:ok, Enum.reverse(child, [entry | acc])}
            {:error, _} = err -> err
          end
        else
          {:ok, [entry | acc]}
        end

      File.regular?(full) ->
        case file_entry(full) do
          {:ok, entry} -> {:ok, [entry | acc]}
          {:error, _} = err -> err
        end

      true ->
        {:ok, acc}
    end
  end

  defp file_entry(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when is_integer(size) and size >= 0 ->
        {:ok, %{path: path, type: :file, size: size}}

      {:ok, _} ->
        {:error, "cannot stat file size for #{path}"}

      {:error, reason} ->
        {:error, "cannot stat #{path}: #{inspect(reason)}"}
    end
  end
end
