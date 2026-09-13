defmodule ExArrow.Parquet.Reader do
  @moduledoc """
  Parquet file reader: open a `.parquet` file or an in-memory binary and
  receive an `ExArrow.Stream` that yields record batches.

  The stream interface is identical to `ExArrow.IPC.Reader` and ADBC streams —
  use `ExArrow.Stream.schema/1`, `ExArrow.Stream.next/1`, and
  `ExArrow.Stream.to_list/1` to consume it.

  ### How Parquet is read (lazy row-group streaming)

  Parquet has a footer that is scanned once when the stream is opened, making
  the schema immediately available via `ExArrow.Stream.schema/1`.  Row groups
  are then decoded **on demand**: each call to `ExArrow.Stream.next/1` reads
  and decodes the next row group without touching the rest of the file.

  ### Pushdown options (v0.8+)

  Pass a keyword list as the second argument:

  * `:columns` — list of column name strings (projection pushdown)
  * `:row_groups` — list of 0-based row-group indices to read
  * `:filters` — predicate AST evaluated during decode, with row-group
    statistics pruning when min/max stats allow it:

        {:gt, "score", 0.5}
        {:and, [{:gte, "id", 10}, {:lt, "id", 100}]}
        {:or, [{:eq, "name", "alice"}, {:eq, "name", "bob"}]}

    An `ExArrow.Compute.Expression` is also accepted here, but it must be
    **fully** Parquet-pushable (`Expression.to_parquet_filters/1` returns a
    tuple with `residual == nil`). Filters that need residual evaluation
    (for example `not_/1`, temporal scalars, or mixed partition keys) must
    use `ExArrow.Dataset.scanner/2` instead.

  Supported comparison ops: `:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`.
  Values may be integers, floats, UTF-8 strings, or booleans.

  After open, `ExArrow.Parquet.Reader.read_stats/1` reports how many row
  groups were selected vs skipped.

  ## Examples

      {:ok, stream} =
        ExArrow.Parquet.Reader.from_file("/data/events.parquet",
          columns: ["user_id", "score"],
          filters: {:gt, "score", 0.9}
        )

      stats = ExArrow.Parquet.Reader.read_stats(stream)
      # %{row_groups_total: 12, row_groups_selected: 3, row_groups_skipped: 9}
  """

  alias ExArrow.Native
  alias ExArrow.Parquet.Opts
  alias ExArrow.Stream

  @doc """
  Open a Parquet file at `path` for lazy row-group streaming.

  See the module documentation for pushdown `opts`.
  """
  @spec from_file(Path.t(), keyword()) :: {:ok, Stream.t()} | {:error, String.t()}
  def from_file(path, opts \\ []) when is_binary(path) and is_list(opts) do
    with {:ok, opts} <- Opts.validate_read(opts) do
      case Native.parquet_reader_from_file(path, opts) do
        {:ok, ref} -> {:ok, %Stream{resource: ref, backend: :parquet}}
        {:error, msg} -> {:error, msg}
      end
    end
  end

  @doc """
  Open a Parquet file from an in-memory `binary`.

  See the module documentation for pushdown `opts`.
  """
  @spec from_binary(binary(), keyword()) :: {:ok, Stream.t()} | {:error, String.t()}
  def from_binary(binary, opts \\ []) when is_binary(binary) and is_list(opts) do
    with {:ok, opts} <- Opts.validate_read(opts) do
      case Native.parquet_reader_from_binary(binary, opts) do
        {:ok, ref} -> {:ok, %Stream{resource: ref, backend: :parquet}}
        {:error, msg} -> {:error, msg}
      end
    end
  end

  @doc """
  Return row-group selection stats for a Parquet-backed stream.

  Keys: `:row_groups_total`, `:row_groups_selected`, `:row_groups_skipped`.
  """
  @spec read_stats(Stream.t()) :: %{
          row_groups_total: non_neg_integer(),
          row_groups_selected: non_neg_integer(),
          row_groups_skipped: non_neg_integer()
        }
  def read_stats(%Stream{resource: ref, backend: :parquet}) do
    Native.parquet_stream_read_stats(ref)
  end
end
