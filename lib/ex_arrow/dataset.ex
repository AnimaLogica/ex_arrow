defmodule ExArrow.Dataset do
  @moduledoc """
  Dataset discovery over Parquet (and IPC) files.

  A Dataset is a discovered set of fragments — usually files under a directory,
  optionally with Hive partition values parsed from the path. Scanning is
  handled by `ExArrow.Scanner` (v0.9.0 M5); this module only discovers and
  describes fragments.

  ## Example

      {:ok, dataset} =
        ExArrow.Dataset.open("/data/events",
          format: :parquet,
          partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
        )

      ExArrow.Dataset.fragments(dataset)
      ExArrow.Dataset.schema(dataset)

  ## Sources

  `open/2` accepts:

  - a directory path (recursive discovery)
  - a single file path
  - a glob pattern (`*` / `**`)
  - an explicit list of file paths

  ## Options

    * `:format` — `:parquet` (default) or `:ipc`
    * `:partitioning` — `:none` (default) or `{:hive, schema: [{name, type}, ...]}`
    * `:filesystem` — `ExArrow.FileSystem` handle (default `FileSystem.Local.new()`)
    * `:ignore_hidden` — skip `.` / `_`-prefixed path components (default `true`)
    * `:schema` — optional `ExArrow.Schema` to skip footer schema resolution
    * `:root` — dataset root for Hive relative paths (inferred when omitted)
  """

  alias ExArrow.Dataset.Fragment
  alias ExArrow.Dataset.Hive
  alias ExArrow.FileSystem
  alias ExArrow.FileSystem.Local
  alias ExArrow.IPC
  alias ExArrow.Parquet
  alias ExArrow.Schema
  alias ExArrow.Stream

  @enforce_keys [:format, :partitioning, :filesystem, :ignore_hidden, :root, :fragments, :schema]
  defstruct [:format, :partitioning, :filesystem, :ignore_hidden, :root, :fragments, :schema]

  @typedoc "Arrow-ish type atom used when coercing Hive `key=value` path segments."
  @type partition_type ::
          :int8
          | :int16
          | :int32
          | :int64
          | :uint8
          | :uint16
          | :uint32
          | :uint64
          | :float32
          | :float64
          | :utf8
          | :boolean
          | :date32

  @typedoc "Ordered list of `{name, type}` pairs for `{:hive, schema: ...}`."
  @type partition_schema :: [{String.t(), partition_type()}]

  @type partitioning :: :none | {:hive, partition_schema()}
  @type format :: :parquet | :ipc

  @type t :: %__MODULE__{
          format: format(),
          partitioning: partitioning(),
          filesystem: FileSystem.t(),
          ignore_hidden: boolean(),
          root: String.t(),
          fragments: [Fragment.t()],
          schema: Schema.t()
        }

  @allowed_opts [:format, :partitioning, :filesystem, :ignore_hidden, :schema, :root]

  @doc """
  Discover fragments for `source` and resolve the dataset schema.
  """
  @spec open(String.t() | [String.t()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def open(source, opts \\ [])

  def open(source, opts) when (is_binary(source) or is_list(source)) and is_list(opts) do
    with :ok <- validate_opts_keys(opts),
         {:ok, format} <- fetch_format(opts),
         {:ok, partitioning} <- fetch_partitioning(opts),
         {:ok, filesystem} <- fetch_filesystem(opts),
         {:ok, ignore_hidden} <- fetch_ignore_hidden(opts),
         {:ok, sized_paths, root} <-
           discover_paths(source, filesystem, format, ignore_hidden, opts),
         root = finalize_root(root, filesystem, sized_paths),
         {:ok, fragments} <- build_fragments(sized_paths, root, format, partitioning),
         {:ok, schema} <- resolve_schema(fragments, format, opts) do
      {:ok,
       %__MODULE__{
         format: format,
         partitioning: partitioning,
         filesystem: filesystem,
         ignore_hidden: ignore_hidden,
         root: root,
         fragments: fragments,
         schema: schema
       }}
    end
  end

  def open(_source, opts) when not is_list(opts), do: {:error, "opts must be a keyword list"}
  def open(_source, _opts), do: {:error, "source must be a path string or a list of paths"}

  @doc """
  Return discovered fragments in path-sorted order.
  """
  @spec fragments(t()) :: [Fragment.t()]
  def fragments(%__MODULE__{fragments: fragments}), do: fragments

  @doc """
  Return the dataset schema resolved at open time (footer / IPC metadata only).
  """
  @spec schema(t()) :: Schema.t()
  def schema(%__MODULE__{schema: schema}), do: schema

  @doc """
  Build a lazy `ExArrow.Scanner` over this dataset (no IO).

  See `ExArrow.Scanner.new/2` for options (`:columns`, `:filter`, `:batch_size`).
  """
  @spec scanner(t(), keyword()) :: {:ok, ExArrow.Scanner.t()} | {:error, String.t()}
  def scanner(%__MODULE__{} = dataset, opts \\ []) when is_list(opts) do
    ExArrow.Scanner.new(dataset, opts)
  end

  # --- options --------------------------------------------------------------

  defp validate_opts_keys(opts) do
    if Keyword.keyword?(opts) do
      bad = Enum.reject(Keyword.keys(opts), &(&1 in @allowed_opts))

      if bad == [] do
        :ok
      else
        {:error, "unknown option(s): #{inspect(bad)}"}
      end
    else
      {:error, "opts must be a keyword list"}
    end
  end

  defp fetch_format(opts) do
    case Keyword.get(opts, :format, :parquet) do
      format when format in [:parquet, :ipc] -> {:ok, format}
      other -> {:error, "format must be :parquet or :ipc, got #{inspect(other)}"}
    end
  end

  defp fetch_partitioning(opts) do
    case Keyword.get(opts, :partitioning, :none) do
      :none ->
        {:ok, :none}

      {:hive, schema: schema} ->
        with {:ok, schema} <- Hive.validate_schema(schema) do
          if schema == [] do
            {:error, "hive partition schema must not be empty"}
          else
            {:ok, {:hive, schema}}
          end
        end

      {:hive, kw} when is_list(kw) ->
        case Keyword.fetch(kw, :schema) do
          {:ok, schema} -> fetch_partitioning(partitioning: {:hive, schema: schema})
          :error -> {:error, "hive partitioning requires schema: [{name, type}, ...]"}
        end

      other ->
        {:error, "partitioning must be :none or {:hive, schema: ...}, got #{inspect(other)}"}
    end
  end

  defp fetch_filesystem(opts) do
    case Keyword.get(opts, :filesystem) do
      nil -> {:ok, Local.new()}
      %_{} = fs -> {:ok, fs}
      other -> {:error, "filesystem must be a FileSystem struct, got #{inspect(other)}"}
    end
  end

  defp fetch_ignore_hidden(opts) do
    case Keyword.get(opts, :ignore_hidden, true) do
      bool when is_boolean(bool) -> {:ok, bool}
      other -> {:error, "ignore_hidden must be a boolean, got #{inspect(other)}"}
    end
  end

  # --- discovery ------------------------------------------------------------

  defp discover_paths(paths, filesystem, format, ignore_hidden, opts) when is_list(paths) do
    with :ok <- validate_path_list(paths),
         {:ok, root} <- resolve_root(opts, paths),
         {:ok, sized} <- attach_sizes(paths, filesystem) do
      filtered =
        sized
        |> Enum.filter(fn {path, _} -> format_match?(path, format) end)
        |> Enum.reject(fn {path, _} ->
          ignore_hidden and FileSystem.path_has_hidden_component?(path)
        end)
        |> Enum.sort_by(&elem(&1, 0))

      if filtered == [] do
        {:error, "no #{format} files found in path list"}
      else
        {:ok, filtered, root}
      end
    end
  end

  defp discover_paths(path, filesystem, format, ignore_hidden, opts) when is_binary(path) do
    if glob_pattern?(path) do
      discover_glob(path, filesystem, format, ignore_hidden, opts)
    else
      discover_single_source(path, filesystem, format, ignore_hidden, opts)
    end
  end

  defp discover_glob(pattern, filesystem, format, ignore_hidden, opts) do
    with {:ok, root} <- resolve_root(opts, glob_root(pattern)),
         {:ok, paths} <- FileSystem.glob(filesystem, pattern, ignore_hidden: ignore_hidden),
         {:ok, sized} <- attach_sizes(Enum.filter(paths, &format_match?(&1, format)), filesystem) do
      sized = Enum.sort_by(sized, &elem(&1, 0))

      if sized == [] do
        {:error, "no #{format} files matching #{pattern}"}
      else
        {:ok, sized, root}
      end
    end
  end

  defp discover_single_source(path, filesystem, format, ignore_hidden, opts) do
    if FileSystem.exists?(filesystem, path) do
      with {:ok, root} <- resolve_root(opts, inferred_root(path, format)),
           {:ok, entries} <-
             FileSystem.list(filesystem, path, recursive: true, ignore_hidden: ignore_hidden) do
        sized =
          entries
          |> Enum.filter(&(&1.type == :file))
          |> Enum.filter(&format_match?(&1.path, format))
          |> Enum.map(&{&1.path, &1.size})
          |> Enum.sort_by(&elem(&1, 0))

        if sized == [] do
          {:error, "no #{format} files under #{path}"}
        else
          {:ok, sized, root}
        end
      end
    else
      {:error, "path does not exist: #{path}"}
    end
  end

  defp inferred_root(path, format) do
    if format_match?(path, format), do: Path.dirname(path), else: path
  end

  defp validate_path_list([]), do: {:error, "path list must not be empty"}

  defp validate_path_list(paths) do
    if Enum.all?(paths, &is_binary/1) do
      :ok
    else
      {:error, "path list entries must be strings"}
    end
  end

  defp attach_sizes(paths, filesystem) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, acc} ->
      case lookup_size(filesystem, path) do
        {:ok, size} -> {:cont, {:ok, acc ++ [{path, size}]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp lookup_size(filesystem, path) do
    case FileSystem.list(filesystem, path, recursive: false) do
      {:ok, [%{type: :file, size: size}]} -> {:ok, size}
      {:ok, []} -> {:error, "path does not exist: #{path}"}
      {:ok, _} -> {:error, "expected a file at #{path}"}
      {:error, _} = err -> err
    end
  end

  defp resolve_root(opts, inferred) when is_binary(inferred) do
    case Keyword.fetch(opts, :root) do
      {:ok, root} when is_binary(root) -> {:ok, normalize_root(root)}
      {:ok, other} -> {:error, "root must be a string, got #{inspect(other)}"}
      :error -> {:ok, normalize_root(inferred)}
    end
  end

  defp resolve_root(opts, paths) when is_list(paths) do
    case Keyword.fetch(opts, :root) do
      {:ok, root} when is_binary(root) ->
        {:ok, normalize_root(root)}

      {:ok, other} ->
        {:error, "root must be a string, got #{inspect(other)}"}

      :error ->
        dirnames = Enum.map(paths, &Path.dirname(normalize_root(&1)))

        case Enum.uniq(dirnames) do
          [only] -> {:ok, only}
          _ -> {:error, "cannot infer dataset root from path list; pass root:"}
        end
    end
  end

  defp normalize_root(root) do
    root =
      root
      |> String.replace("\\", "/")
      |> String.replace(~r/\/+/, "/")

    if root in ["", "/"] do
      "/"
    else
      String.trim_trailing(root, "/")
    end
  end

  defp glob_pattern?(path), do: String.contains?(path, ["*", "?"])

  defp glob_root(pattern) do
    pattern
    |> Path.split()
    |> Enum.take_while(&(not String.contains?(&1, ["*", "?"])))
    |> case do
      [] -> "/"
      parts -> Path.join(parts)
    end
  end

  defp format_match?(path, :parquet), do: String.ends_with?(path, ".parquet")
  defp format_match?(path, :ipc), do: String.ends_with?(path, [".arrow", ".ipc"])

  # Local discovery expands paths; align the Hive root to that absolute form.
  defp finalize_root(root, %Local{}, [{path, _} | _]) do
    expanded = normalize_root(Path.expand(root))

    if path == expanded or String.starts_with?(path, expanded <> "/") do
      expanded
    else
      normalize_root(root)
    end
  end

  defp finalize_root(root, _filesystem, _sized), do: normalize_root(root)

  # --- fragments ------------------------------------------------------------

  defp build_fragments(sized_paths, _root, format, :none) do
    fragments =
      Enum.map(sized_paths, fn {path, size} ->
        %Fragment{path: path, format: format, partition_values: %{}, size: size}
      end)

    {:ok, fragments}
  end

  defp build_fragments(sized_paths, root, format, {:hive, schema}) do
    Enum.reduce_while(sized_paths, {:ok, []}, fn {path, size}, {:ok, acc} ->
      case Hive.parse_path(path, root, schema) do
        {:ok, values} ->
          frag = %Fragment{
            path: path,
            format: format,
            partition_values: values,
            size: size
          }

          {:cont, {:ok, acc ++ [frag]}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  # --- schema ---------------------------------------------------------------

  defp resolve_schema(fragments, format, opts) do
    case Keyword.fetch(opts, :schema) do
      {:ok, %Schema{} = schema} ->
        {:ok, schema}

      {:ok, other} ->
        {:error, "schema option must be an ExArrow.Schema, got #{inspect(other)}"}

      :error ->
        case fragments do
          [%Fragment{path: path} | _] -> read_schema(path, format)
          [] -> {:error, "cannot resolve schema: no fragments"}
        end
    end
  end

  defp read_schema(path, :parquet) do
    # Opening the reader parses the footer only; we never call Stream.next/1.
    case Parquet.Reader.from_file(path) do
      {:ok, stream} ->
        result = Stream.schema(stream)
        _ = Stream.close(stream)
        result

      {:error, msg} ->
        {:error, "cannot read schema from #{path}: #{msg}"}
    end
  end

  defp read_schema(path, :ipc) do
    case IPC.File.from_file(path) do
      {:ok, file} ->
        case IPC.File.schema(file) do
          {:ok, schema} -> {:ok, schema}
          {:error, msg} -> {:error, "cannot read schema from #{path}: #{msg}"}
        end

      {:error, msg} ->
        {:error, "cannot read schema from #{path}: #{msg}"}
    end
  end
end
