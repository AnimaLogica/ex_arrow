defmodule ExArrow.RecordBatch do
  @moduledoc """
  Arrow record batch handle (opaque reference to native record batch).

  A batch is a collection of column arrays with a shared schema and row count.
  It sits between `ExArrow.Array` (one column) and `ExArrow.Table` or
  `ExArrow.Stream` (multiple batches).  Data stays in native memory; accessors
  return handles or small metadata.

  ## Position in the hierarchy

      Schema ── Field (metadata)
                  │
      RecordBatch ── Array (one per column)
                        │
      Table / Stream ── RecordBatch (one or more)

  ## Supported dtype strings (`from_columns/4`)

  The `from_columns/4` constructor accepts a per-column dtype string.  The
  full set of supported strings, the corresponding Arrow logical type, and
  the wire format expected for each column binary are listed below.

  ### Fixed-width primitives

  Each column binary is exactly `length × element_size` bytes, in
  little-endian byte order for multi-byte types.

  | dtype  | Arrow type         | element size |
  |--------|--------------------|--------------|
  | `"s8"`  | `Int8`             | 1 byte       |
  | `"s16"` | `Int16`            | 2 bytes      |
  | `"s32"` | `Int32`            | 4 bytes      |
  | `"s64"` | `Int64`            | 8 bytes      |
  | `"u8"`  | `UInt8`            | 1 byte       |
  | `"u16"` | `UInt16`           | 2 bytes      |
  | `"u32"` | `UInt32`           | 4 bytes      |
  | `"u64"` | `UInt64`           | 8 bytes      |
  | `"f32"` | `Float32`          | 4 bytes      |
  | `"f64"` | `Float64`          | 8 bytes      |

  ### Boolean

  `"bool"`: exactly `length` bytes, one byte per element (0 = false,
  non-zero = true).

  ### Date and time

  Dates are days or milliseconds since 1970-01-01.  Timestamps are ticks
  since the Unix epoch in UTC.  Durations are tick counts.  All temporal
  types are little-endian.

  | dtype  | Arrow type | Rust scalar | element size |
  |--------|------------|-------------|--------------|
  | `"date32"`              | `Date32`                            | i32 days   | 4 bytes |
  | `"date64"`              | `Date64`                            | i64 millis | 8 bytes |
  | `"timestamp_seconds"`   | `Timestamp(Second, None)`           | i64 sec    | 8 bytes |
  | `"timestamp_millis"`    | `Timestamp(Millisecond, None)`      | i64 ms     | 8 bytes |
  | `"timestamp_micros"`    | `Timestamp(Microsecond, None)`      | i64 µs     | 8 bytes |
  | `"timestamp_nanos"`     | `Timestamp(Nanosecond, None)`       | i64 ns     | 8 bytes |
  | `"duration_seconds"`    | `Duration(Second)`                  | i64 sec    | 8 bytes |
  | `"duration_millis"`     | `Duration(Millisecond)`             | i64 ms     | 8 bytes |
  | `"duration_micros"`     | `Duration(Microsecond)`             | i64 µs     | 8 bytes |
  | `"duration_nanos"`      | `Duration(Nanosecond)`              | i64 ns     | 8 bytes |

  Timestamps are emitted with no timezone (`None`).  The caller is
  responsible for ensuring the i64 ticks are in UTC if the consuming
  server treats the column as zoned.

  ### Variable-length string and binary

  Variable-length columns use a length-prefixed wire format.  The column
  binary is the concatenation of `length` records, each of the form:

      <<elem_len::unsigned-little-32, elem_bytes::binary-size(elem_len)>>

  | dtype           | Arrow type     |
  |-----------------|----------------|
  | `"utf8"`        | `Utf8`         |
  | `"large_utf8"`  | `LargeUtf8`    |
  | `"binary"`      | `Binary`       |
  | `"large_binary"`| `LargeBinary`  |

  `"utf8"` and `"large_utf8"` validate UTF-8 on the entire payload and
  return `{:error, msg}` if any element is invalid.  `"binary"` and
  `"large_binary"` accept arbitrary bytes.

  ## Nullability

  `from_columns/4`, `from_lists/1`, and `from_map/1` produce non-nullable
  columns (`Field.nullable = false`). `from_lists/1` and `from_map/1` reject
  `nil` cells in 0.9; null-bitmap support arrives with the core-model release.
  """
  alias ExArrow.Native
  alias ExArrow.Schema

  @opaque t :: %__MODULE__{resource: reference()}
  defstruct [:resource]

  @doc false
  @spec record_batch?(term()) :: boolean()
  def record_batch?(%__MODULE__{}), do: true
  def record_batch?(_), do: false

  @doc false
  @spec from_ref(reference()) :: t()
  def from_ref(ref), do: %__MODULE__{resource: ref}

  @doc false
  @spec resource_ref(t()) :: reference()
  def resource_ref(%__MODULE__{resource: ref}), do: ref

  @doc """
  Returns the schema of this record batch.
  """
  @spec schema(t()) :: Schema.t()
  def schema(%__MODULE__{resource: ref}) do
    ref |> Native.record_batch_schema() |> Schema.from_ref()
  end

  @doc """
  Returns the number of rows in this batch.
  """
  @spec num_rows(t()) :: non_neg_integer()
  def num_rows(%__MODULE__{resource: ref}) do
    Native.record_batch_num_rows(ref)
  end

  @doc """
  Returns the number of columns in this batch.

  Derived from the batch's schema; no separate NIF call is needed.

  ## Examples

      {:ok, ipc_bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream}  = ExArrow.IPC.Reader.from_binary(ipc_bin)
      batch = ExArrow.Stream.next(stream)
      ExArrow.RecordBatch.num_columns(batch)  #=> 2
  """
  @spec num_columns(t()) :: non_neg_integer()
  def num_columns(%__MODULE__{} = batch) do
    batch |> schema() |> Schema.fields() |> length()
  end

  @doc """
  Returns the column names of this batch.

  Derived from the batch's schema.  Equivalent to
  `ExArrow.Schema.field_names(ExArrow.RecordBatch.schema(batch))`.

  ## Examples

      {:ok, ipc_bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream}  = ExArrow.IPC.Reader.from_binary(ipc_bin)
      batch = ExArrow.Stream.next(stream)
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{} = batch) do
    batch |> schema() |> Schema.field_names()
  end

  @doc """
  Create a `RecordBatch` from named columns of Elixir lists.

  Each column is a `{name, dtype, values}` triple. `name` may be a string or
  atom. `dtype` may be a `from_columns/4` dtype string (`"s64"`, `"utf8"`, …)
  or the matching atom (`:s64`, `:utf8`, …). `values` is a list of scalar
  cells; all columns must have the same length.

  Supports every dtype accepted by `from_columns/4`. Temporal and integer
  dtypes expect integer cells (days/ticks as in the wire format). Float
  dtypes accept integers or floats. Boolean expects `true`/`false`. Utf8
  expects valid UTF-8 binaries; `binary` / `large_binary` accept any binary.

  `nil` cells are rejected in 0.9 (no null-bitmap encoding yet). Nested
  lists, maps, and tuples as cells are rejected.

  Packs into the `from_columns/4` wire format and reuses that NIF path.

  ## Examples

      {:ok, batch} =
        ExArrow.RecordBatch.from_lists([
          {"id", :s64, [1, 2, 3]},
          {"name", :utf8, ["a", "b", "c"]}
        ])

      {:error, _} =
        ExArrow.RecordBatch.from_lists([{"x", :s64, [1, nil]}])
  """
  @spec from_lists([{String.t() | atom(), atom() | String.t(), list()}]) ::
          {:ok, t()} | {:error, String.t()}
  def from_lists(columns) when is_list(columns) do
    with :ok <- validate_from_lists_shape(columns),
         {:ok, names, dtypes, binaries, length} <- pack_from_lists(columns) do
      from_columns(names, binaries, dtypes, length)
    end
  end

  def from_lists(_), do: {:error, "from_lists/1 expects a list of {name, dtype, values} triples"}

  @doc """
  Create a `RecordBatch` from a map of column name => value list.

  Keys are sorted lexicographically (after converting atom keys to strings)
  so the resulting schema order is stable. Value lists must all have the
  same length.

  Dtypes are inferred from the cells of each column:

  | Cells                         | Dtype  |
  |-------------------------------|--------|
  | integers                      | `s64`  |
  | floats (or mix with integers) | `f64`  |
  | booleans                      | `bool` |
  | binaries (valid UTF-8)        | `utf8` |

  Empty columns and mixed incompatible cell types return `{:error, message}`.
  For explicit dtypes use `from_lists/1`.

  ## Examples

      {:ok, batch} =
        ExArrow.RecordBatch.from_map(%{"id" => [1, 2], "name" => ["a", "b"]})
  """
  @spec from_map(%{optional(String.t() | atom()) => list()}) ::
          {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) and map_size(map) > 0 do
    with {:ok, columns} <- map_to_list_columns(map) do
      from_lists(columns)
    end
  end

  def from_map(%{}), do: {:error, "from_map/1 requires at least one column"}
  def from_map(_), do: {:error, "from_map/1 expects a map of name => list"}

  @doc """
  Create a `RecordBatch` from column-oriented binary data.

  Each column is provided as a raw binary paired with an Arrow dtype
  string and a shared row count.  This constructor builds parameter batches for Flight SQL prepared statement binding.

  ## Parameters

  - `names`: list of column name strings
  - `binaries`: list of column data binaries (one per column).  See the
    [supported dtypes](#module-supported-dtype-strings-from_columns-4)
    table in the moduledoc for the wire format of each dtype.
  - `dtypes`: list of Arrow dtype strings, one per column
  - `length`: number of rows (must be the same for every column)

  All four lists must have the same length and at least one entry.

  ## Returns

  - `{:ok, %ExArrow.RecordBatch{}}` on success
  - `{:error, message}` if the inputs are inconsistent (mismatched
    list lengths, malformed binary, unknown dtype, invalid UTF-8 in a
    `"utf8"`/`"large_utf8"` column, etc.)

  ## Examples

      # Single int64 column with one row
      {:ok, batch} = ExArrow.RecordBatch.from_columns(
        ["id"],
        [<<42::little-signed-64>>],
        ["s64"],
        1
      )

      # Mixed primitives
      {:ok, batch} = ExArrow.RecordBatch.from_columns(
        ["id", "score"],
        [<<1::little-signed-64>>, <<3.14::little-float-64>>],
        ["s64", "f64"],
        1
      )

      # utf8 column with two rows ("hello", "world") using length-prefixed
      # records: <<len::little-32, bytes::binary-size(len)>>
      utf8 = <<5::little-32, "hello", 5::little-32, "world">>
      {:ok, batch} = ExArrow.RecordBatch.from_columns(["s"], [utf8], ["utf8"], 2)

      # timestamp_micros column
      ts = <<1_700_000_000_000_000::little-signed-64>>
      {:ok, batch} =
        ExArrow.RecordBatch.from_columns(["t"], [ts], ["timestamp_micros"], 1)
  """
  @spec from_columns([String.t()], [binary()], [String.t()], non_neg_integer()) ::
          {:ok, t()} | {:error, String.t()}
  def from_columns(names, binaries, dtypes, length)
      when is_list(names) and is_list(binaries) and is_list(dtypes) and
             is_integer(length) and length >= 0 do
    case Native.record_batch_from_column_binaries(names, binaries, dtypes, length) do
      {:ok, ref} -> {:ok, %__MODULE__{resource: ref}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Concatenate a list of record batches that share the same schema into one batch.

  Returns `{:ok, batch}` or `{:error, message}` (e.g. empty list or schema mismatch).
  """
  @spec concat([t()]) :: {:ok, t()} | {:error, String.t()}
  def concat([]), do: {:error, "concat requires at least one record batch"}

  def concat(batches) when is_list(batches) do
    refs = Enum.map(batches, &resource_ref/1)

    case Native.record_batch_concat(refs) do
      {:ok, ref} -> {:ok, from_ref(ref)}
      {:error, _} = err -> err
    end
  end

  # --- from_lists/1 / from_map/1 --------------------------------------------

  defp validate_from_lists_shape([]), do: {:error, "from_lists/1 requires at least one column"}

  defp validate_from_lists_shape(columns) do
    bad_shape? =
      Enum.any?(columns, fn
        {_n, _d, values} when is_list(values) -> false
        _ -> true
      end)

    if bad_shape? do
      {:error, "from_lists/1 expects {name, dtype, values} triples with list values"}
    else
      lengths = Enum.map(columns, fn {_n, _d, values} -> length(values) end)

      case Enum.uniq(lengths) do
        [_] -> :ok
        _ -> {:error, "from_lists/1 column lengths must match, got: #{inspect(lengths)}"}
      end
    end
  end

  defp pack_from_lists(columns) do
    {_n, _d, first_values} = hd(columns)
    length = length(first_values)

    reduced =
      Enum.reduce_while(columns, {:ok, {[], [], []}}, fn {name, dtype, values},
                                                         {:ok, {ns, ds, bs}} ->
        with {:ok, name_str} <- normalize_field_name(name),
             {:ok, dtype_str} <- normalize_list_dtype(dtype),
             {:ok, binary} <- pack_column(dtype_str, values) do
          {:cont, {:ok, {[name_str | ns], [dtype_str | ds], [binary | bs]}}}
        else
          {:error, _} = err -> {:halt, err}
        end
      end)

    case reduced do
      {:ok, {names_rev, dtypes_rev, binaries_rev}} ->
        {:ok, Enum.reverse(names_rev), Enum.reverse(dtypes_rev), Enum.reverse(binaries_rev),
         length}

      {:error, _} = err ->
        err
    end
  end

  defp map_to_list_columns(map) do
    pairs = Enum.map(map, fn {name, values} -> {name, values} end)

    reduced =
      Enum.reduce_while(pairs, {:ok, []}, fn {name, values}, {:ok, acc} ->
        append_inferred_column(name, values, acc)
      end)

    case reduced do
      {:ok, columns_rev} ->
        columns =
          columns_rev
          |> Enum.reverse()
          |> Enum.sort_by(fn {name, _dtype, _values} -> name end)

        {:ok, columns}

      {:error, _} = err ->
        err
    end
  end

  defp append_inferred_column(_name, values, _acc) when not is_list(values) do
    {:halt, {:error, "from_map/1 values must be lists, got: #{inspect(values)}"}}
  end

  defp append_inferred_column(_name, [], _acc) do
    {:halt, {:error, "from_map/1 cannot infer dtype for an empty column"}}
  end

  defp append_inferred_column(name, values, acc) do
    with {:ok, dtype} <- infer_list_dtype(values),
         {:ok, name_str} <- normalize_field_name(name) do
      {:cont, {:ok, [{name_str, dtype, values} | acc]}}
    else
      {:error, _} = err -> {:halt, err}
    end
  end

  defp infer_list_dtype(values) do
    reduced =
      Enum.reduce_while(values, {:ok, :unknown}, fn value, {:ok, acc} ->
        merge_inferred_class(acc, value)
      end)

    case reduced do
      {:ok, class} -> dtype_class_to_string(class)
      {:error, _} = err -> err
    end
  end

  defp merge_inferred_class(_acc, nil) do
    {:halt, {:error, "from_lists/1 does not support nil cells (null bitmaps not encoded in 0.9)"}}
  end

  defp merge_inferred_class(_acc, v) when is_list(v) or is_map(v) or is_tuple(v) do
    {:halt, {:error, "from_lists/1 cell must be a scalar, got: #{inspect(v)}"}}
  end

  defp merge_inferred_class(acc, v) do
    case {acc, classify_cell(v)} do
      {:unknown, class} -> {:cont, {:ok, class}}
      {class, class} -> {:cont, {:ok, class}}
      {:integer, :float} -> {:cont, {:ok, :float}}
      {:float, :integer} -> {:cont, {:ok, :float}}
      {a, b} -> {:halt, {:error, "from_map/1 mixed cell types in column (#{a} vs #{b})"}}
    end
  end

  defp dtype_class_to_string(:integer), do: {:ok, "s64"}
  defp dtype_class_to_string(:float), do: {:ok, "f64"}
  defp dtype_class_to_string(:boolean), do: {:ok, "bool"}
  defp dtype_class_to_string(:utf8), do: {:ok, "utf8"}

  defp dtype_class_to_string(:invalid_utf8),
    do: {:error, "from_map/1 binary cells must be valid UTF-8 (use from_lists/1 with :binary)"}

  defp dtype_class_to_string(:other),
    do: {:error, "from_map/1 cannot infer dtype from cell values"}

  defp dtype_class_to_string(:unknown),
    do: {:error, "from_map/1 cannot infer dtype for an empty column"}

  defp classify_cell(v) when is_integer(v), do: :integer
  defp classify_cell(v) when is_float(v), do: :float
  defp classify_cell(v) when is_boolean(v), do: :boolean

  defp classify_cell(v) when is_binary(v) do
    if String.valid?(v), do: :utf8, else: :invalid_utf8
  end

  defp classify_cell(_), do: :other

  defp normalize_field_name(name) when is_binary(name), do: {:ok, name}
  defp normalize_field_name(name) when is_atom(name), do: {:ok, Atom.to_string(name)}

  defp normalize_field_name(other),
    do: {:error, "field name must be a string or atom, got: #{inspect(other)}"}

  defp normalize_list_dtype(dtype) when is_atom(dtype),
    do: normalize_list_dtype(Atom.to_string(dtype))

  defp normalize_list_dtype(dtype) when is_binary(dtype) do
    known = ~w(
      s8 s16 s32 s64 u8 u16 u32 u64 f32 f64 bool
      date32 date64
      timestamp_seconds timestamp_millis timestamp_micros timestamp_nanos
      duration_seconds duration_millis duration_micros duration_nanos
      utf8 large_utf8 binary large_binary
    )

    if dtype in known do
      {:ok, dtype}
    else
      {:error, "unsupported from_lists/1 dtype: #{inspect(dtype)}"}
    end
  end

  defp normalize_list_dtype(other),
    do: {:error, "unsupported from_lists/1 dtype: #{inspect(other)}"}

  defp pack_column(dtype, values) do
    reduced =
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case pack_cell(dtype, value) do
          {:ok, chunk} -> {:cont, {:ok, [chunk | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case reduced do
      {:ok, chunks_rev} ->
        binary = chunks_rev |> Enum.reverse() |> IO.iodata_to_binary()
        {:ok, binary}

      {:error, _} = err ->
        err
    end
  end

  defp pack_cell(_dtype, nil),
    do: {:error, "from_lists/1 does not support nil cells (null bitmaps not encoded in 0.9)"}

  defp pack_cell(_dtype, value) when is_list(value) or is_map(value) or is_tuple(value),
    do: {:error, "from_lists/1 cell must be a scalar, got: #{inspect(value)}"}

  defp pack_cell("s8", v) when is_integer(v), do: pack_int(v, -128, 127, 8, "int8")
  defp pack_cell("s16", v) when is_integer(v), do: pack_int(v, -32_768, 32_767, 16, "int16")

  defp pack_cell("s32", v) when is_integer(v),
    do: pack_int(v, -2_147_483_648, 2_147_483_647, 32, "int32")

  defp pack_cell("s64", v) when is_integer(v),
    do: pack_int(v, -9_223_372_036_854_775_808, 9_223_372_036_854_775_807, 64, "int64")

  defp pack_cell("u8", v) when is_integer(v), do: pack_uint(v, 255, 8, "uint8")
  defp pack_cell("u16", v) when is_integer(v), do: pack_uint(v, 65_535, 16, "uint16")
  defp pack_cell("u32", v) when is_integer(v), do: pack_uint(v, 4_294_967_295, 32, "uint32")

  defp pack_cell("u64", v) when is_integer(v) do
    if v >= 0 and v <= 18_446_744_073_709_551_615 do
      {:ok, <<v::little-unsigned-64>>}
    else
      {:error, "uint64 value out of range: #{v}"}
    end
  end

  defp pack_cell("f32", v) when is_integer(v), do: pack_cell("f32", v * 1.0)
  defp pack_cell("f32", v) when is_float(v), do: {:ok, <<v::little-float-32>>}
  defp pack_cell("f64", v) when is_integer(v), do: pack_cell("f64", v * 1.0)
  defp pack_cell("f64", v) when is_float(v), do: {:ok, <<v::little-float-64>>}

  defp pack_cell("bool", true), do: {:ok, <<1>>}
  defp pack_cell("bool", false), do: {:ok, <<0>>}

  defp pack_cell("date32", v) when is_integer(v),
    do: pack_int(v, -2_147_483_648, 2_147_483_647, 32, "date32")

  defp pack_cell("date64", v) when is_integer(v),
    do: pack_int(v, -9_223_372_036_854_775_808, 9_223_372_036_854_775_807, 64, "date64")

  defp pack_cell(dtype, v)
       when dtype in [
              "timestamp_seconds",
              "timestamp_millis",
              "timestamp_micros",
              "timestamp_nanos",
              "duration_seconds",
              "duration_millis",
              "duration_micros",
              "duration_nanos"
            ] and is_integer(v) do
    pack_int(v, -9_223_372_036_854_775_808, 9_223_372_036_854_775_807, 64, dtype)
  end

  defp pack_cell(dtype, v) when dtype in ["utf8", "large_utf8"] and is_binary(v) do
    if String.valid?(v) do
      {:ok, <<byte_size(v)::little-unsigned-32, v::binary>>}
    else
      {:error, "#{dtype} cell is not valid UTF-8"}
    end
  end

  defp pack_cell(dtype, v) when dtype in ["binary", "large_binary"] and is_binary(v) do
    {:ok, <<byte_size(v)::little-unsigned-32, v::binary>>}
  end

  defp pack_cell(dtype, value),
    do: {:error, "cannot pack #{inspect(value)} as #{dtype}"}

  defp pack_int(v, min, max, 8, label) do
    if v >= min and v <= max, do: {:ok, <<v::little-signed-8>>}, else: out_of_range(label, v)
  end

  defp pack_int(v, min, max, 16, label) do
    if v >= min and v <= max, do: {:ok, <<v::little-signed-16>>}, else: out_of_range(label, v)
  end

  defp pack_int(v, min, max, 32, label) do
    if v >= min and v <= max, do: {:ok, <<v::little-signed-32>>}, else: out_of_range(label, v)
  end

  defp pack_int(v, min, max, 64, label) do
    if v >= min and v <= max, do: {:ok, <<v::little-signed-64>>}, else: out_of_range(label, v)
  end

  defp pack_uint(v, max, 8, label) do
    if v >= 0 and v <= max, do: {:ok, <<v::little-unsigned-8>>}, else: out_of_range(label, v)
  end

  defp pack_uint(v, max, 16, label) do
    if v >= 0 and v <= max, do: {:ok, <<v::little-unsigned-16>>}, else: out_of_range(label, v)
  end

  defp pack_uint(v, max, 32, label) do
    if v >= 0 and v <= max, do: {:ok, <<v::little-unsigned-32>>}, else: out_of_range(label, v)
  end

  defp out_of_range(label, v), do: {:error, "#{label} value out of range: #{v}"}
end
