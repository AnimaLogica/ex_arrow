defmodule ExArrow.Batch do
  @moduledoc """
  Lightweight `ExArrow.RecordBatch` transformations.

  This module provides a small, Arrow-native set of column and row operations
  that preserve the underlying native batch handle.  It is **not** a dataframe
  implementation and **not** a replacement for Explorer — use Explorer for
  analytics and ExArrow.Batch for in-flight pipeline transformations where
  keeping data in Arrow memory matters.

  Every function returns either `{:ok, batch}` / `{:ok, schema}` or
  `{:error, message}`.  Column data is never converted to row maps.

  ## Column-wise implementation

  - `select/2`, `drop/2`, and `filter/2` delegate to the native compute kernels
    (`ExArrow.Compute`) and work for **all** Arrow types ExArrow supports.
  - `take/2` builds a boolean mask and filters through `ExArrow.Compute.filter/2`,
    so it also works for **all** Arrow types ExArrow supports.
  - `rename/2` rebuilds a batch from raw column buffers.  The buffer-extraction
    NIF supports the fixed-width numeric and boolean types (`s8`–`s64`,
    `u8`–`u64`, `f32`, `f64`, `bool`).  Columns of other types (utf8, binary,
    timestamps, dates, durations) return `{:error, "unsupported column type..."}`.
    For workloads that need to rename string columns, round-trip through
    `ExArrow.Explorer` (which exposes its own rename) or project to a
    numeric-only batch first.

  ## Schema and metadata preservation

  Field order, field types, and nullability are preserved across `select/2`,
  `drop/2`, and `filter/2`.  `rename/2` preserves types and order, changing
  only the field names supplied in the mapping.  Arrow schema metadata is not
  currently exposed by the NIF layer and is therefore not modified.

  ## Examples

      {:ok, stream} = ExArrow.Stream.from_parquet("/data/events.parquet")
      batch = ExArrow.Stream.next(stream)

      {:ok, slim}    = ExArrow.Batch.select(batch, ["user_id", "score"])
      {:ok, renamed} = ExArrow.Batch.rename(slim, %{"user_id" => "id"})
      {:ok, top10}   = ExArrow.Batch.take(renamed, 10)
  """

  alias ExArrow.Compute
  alias ExArrow.Compute.Expression
  alias ExArrow.Native
  alias ExArrow.RecordBatch
  alias ExArrow.Schema

  @doc """
  Return the `ExArrow.Schema` handle for `batch`.

  Equivalent to `ExArrow.RecordBatch.schema/1`.  Provided here so callers can
  stay within the `ExArrow.Batch` API for inspection.
  """
  @spec schema(RecordBatch.t()) :: Schema.t()
  def schema(batch), do: RecordBatch.schema(batch)

  @doc """
  Project a subset of `columns` from `batch` by name.

  Columns appear in the result in the order given.  Delegates to
  `ExArrow.Compute.project/2` and works for every Arrow type ExArrow supports.

  Returns `{:ok, projected_batch}` or `{:error, message}`.

  ## Examples

      {:ok, two} = ExArrow.Batch.select(batch, ["user_id", "score"])

      {:ok, reordered} = ExArrow.Batch.select(batch, ["score", "user_id"])

      {:error, "column 'missing' not found"} = ExArrow.Batch.select(batch, ["missing"])
  """
  @spec select(RecordBatch.t(), [String.t()]) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def select(batch, columns) when is_list(columns) do
    Compute.project(batch, columns)
  end

  @doc """
  Return a batch with `columns` removed.

  All remaining columns keep their original relative order.  Delegates to
  `ExArrow.Compute.project/2` over the complement of `columns`.

  Returns `{:ok, batch}` or `{:error, message}`.

  ## Examples

      {:ok, rest} = ExArrow.Batch.drop(batch, ["internal_flag", "debug"])

      # Dropping an unknown column is an error.
      {:error, _} = ExArrow.Batch.drop(batch, ["no_such_column"])
  """
  @spec drop(RecordBatch.t(), [String.t()]) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def drop(batch, columns) when is_list(columns) do
    existing = RecordBatch.column_names(batch)
    unknown = Enum.reject(columns, &(&1 in existing))

    if unknown != [] do
      {:error, "unknown column(s) for drop: #{inspect(unknown)}"}
    else
      keep = Enum.reject(existing, &(&1 in columns))
      Compute.project(batch, keep)
    end
  end

  @doc """
  Rename one or more columns of `batch`.

  `mapping` is a map of `%{old_name => new_name}` or a keyword list of
  `{atom, new_name}` where the atom is the old column name.  Columns not
  present in `mapping` keep their names.  Column order and types are
  preserved.

  Rebuilds the batch from raw column buffers, so only the buffer-extractable
  fixed-width numeric and boolean types are supported (see the moduledoc).
  Returns `{:ok, batch}` or `{:error, message}`.

  ## Examples

      {:ok, renamed} = ExArrow.Batch.rename(batch, %{"user_id" => "id"})

      {:ok, renamed} = ExArrow.Batch.rename(batch, %{"a" => "x", "b" => "y"})

      # Unknown source column is an error.
      {:error, _} = ExArrow.Batch.rename(batch, %{"missing" => "x"})
  """
  @spec rename(RecordBatch.t(), %{String.t() => String.t()} | keyword()) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def rename(batch, mapping) when is_map(mapping) do
    renames = for {k, v} <- mapping, do: {to_string(k), to_string(v)}
    rebuild_with_renames(batch, renames)
  end

  def rename(batch, mapping) when is_list(mapping) do
    renames = for {k, v} <- mapping, do: {to_string(k), to_string(v)}
    rebuild_with_renames(batch, renames)
  end

  @doc """
  Select a subset of rows.

  The second argument may be:

  - an integer `n` — keep the first `n` rows (`n >= 0`).  `n` larger than the
    batch row count returns the batch unchanged.
  - a list of zero-based row indices — keep the rows at the given positions.
    Rows are returned in their **original** row order (the boolean-mask filter
    kernel preserves row order and does not reorder by the index list).
    Out-of-range indices are an error.

  Implemented by building a boolean mask and filtering through
  `ExArrow.Compute.filter/2`, so it works for every Arrow type ExArrow
  supports.  Returns `{:ok, batch}` or `{:error, message}`.

  ## Examples

      {:ok, first10} = ExArrow.Batch.take(batch, 10)

      {:ok, picked} = ExArrow.Batch.take(batch, [0, 2, 4])
  """
  @spec take(RecordBatch.t(), non_neg_integer() | [non_neg_integer()]) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def take(_batch, n) when is_integer(n) and n < 0 do
    {:error, "n must be non-negative, got: #{n}"}
  end

  def take(batch, n) when is_integer(n) and n >= 0 do
    rows = RecordBatch.num_rows(batch)

    cond do
      n >= rows ->
        {:ok, batch}

      n == 0 ->
        filter_with_mask(batch, :binary.copy(<<0>>, rows))

      true ->
        mask = :binary.copy(<<1>>, n) <> :binary.copy(<<0>>, rows - n)
        filter_with_mask(batch, mask)
    end
  end

  def take(batch, indices) when is_list(indices) do
    rows = RecordBatch.num_rows(batch)

    case validate_indices(indices, rows) do
      :ok ->
        mask = build_index_mask(indices, rows)
        filter_with_mask(batch, mask)

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Filter rows of `batch` using a boolean mask batch or an `Expression`.

  Delegates directly to `ExArrow.Compute.filter/2`. Rows where the predicate
  is `true` are kept; rows where it is `false` or `null` are dropped.

  When `predicate` is a `RecordBatch`, its first column must be a boolean Arrow
  array with the same row count as `batch`. When it is an
  `ExArrow.Compute.Expression`, the expression is evaluated in native memory.

  Returns `{:ok, filtered_batch}` or `{:error, message}`.

  ## Examples

      {:ok, mask}     = ExArrow.Compute.project(batch, ["is_active"])
      {:ok, filtered} = ExArrow.Batch.filter(batch, mask)

      alias ExArrow.Compute.Expression, as: E
      {:ok, filtered} =
        ExArrow.Batch.filter(batch, E.gt(E.field("score"), E.scalar(0.9)))
  """
  @spec filter(RecordBatch.t(), RecordBatch.t() | Expression.t()) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def filter(batch, predicate) do
    Compute.filter(batch, predicate)
  end

  # Internals

  defp rebuild_with_renames(batch, renames) do
    fields = Schema.fields(RecordBatch.schema(batch))
    name_set = MapSet.new(Enum.map(fields, & &1.name))
    rename_map = Map.new(renames)

    unknown = Enum.reject(renames, fn {old, _} -> MapSet.member?(name_set, old) end)

    if unknown != [] do
      {:error, "unknown column(s) for rename: #{inspect(Enum.map(unknown, &elem(&1, 0)))}"}
    else
      rebuild_columns(batch, fields, rename_map)
    end
  end

  defp rebuild_columns(batch, fields, rename_map) do
    ref = RecordBatch.resource_ref(batch)
    rows = RecordBatch.num_rows(batch)

    reduce_result =
      Enum.reduce_while(fields, {:ok, {[], [], []}}, fn field, {:ok, {ns, bs, ds}} ->
        old_name = field.name
        new_name = Map.get(rename_map, old_name, old_name)

        case Native.record_batch_column_buffer(ref, old_name) do
          {:ok, {binary, dtype, _length}} ->
            {:cont, {:ok, {[new_name | ns], [binary | bs], [dtype | ds]}}}

          {:error, msg} ->
            {:halt, {:error, msg}}
        end
      end)

    case reduce_result do
      {:ok, {names_rev, binaries_rev, dtypes_rev}} ->
        result =
          Native.record_batch_from_column_binaries(
            Enum.reverse(names_rev),
            Enum.reverse(binaries_rev),
            Enum.reverse(dtypes_rev),
            rows
          )

        from_ref_ok(result)

      {:error, _} = err ->
        err
    end
  end

  defp filter_with_mask(batch, mask_bytes) do
    rows = RecordBatch.num_rows(batch)

    case Native.record_batch_from_column_binaries(["__take_mask"], [mask_bytes], ["bool"], rows) do
      {:ok, ref} ->
        predicate = RecordBatch.from_ref(ref)
        Compute.filter(batch, predicate)

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp validate_indices(indices, rows) do
    bad = Enum.find(indices, &(not is_integer(&1) or &1 < 0 or &1 >= rows))

    if bad == nil do
      :ok
    else
      {:error, "row index out of range or non-integer: #{inspect(bad)} (rows: #{rows})"}
    end
  end

  defp build_index_mask(indices, rows) do
    set = MapSet.new(indices)

    for i <- 0..(rows - 1), into: <<>> do
      if MapSet.member?(set, i), do: <<1>>, else: <<0>>
    end
  end

  defp from_ref_ok({:ok, ref}), do: {:ok, RecordBatch.from_ref(ref)}
  defp from_ref_ok({:error, _} = err), do: err
end
