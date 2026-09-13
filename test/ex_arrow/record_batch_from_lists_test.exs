defmodule ExArrow.RecordBatchFromListsTest do
  use ExUnit.Case, async: true

  alias ExArrow.IPC
  alias ExArrow.Native
  alias ExArrow.RecordBatch
  alias ExArrow.Schema

  defp s64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "s64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-signed-64 <- binary>>, do: v
  end

  defp f64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "f64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-float-64 <- binary>>, do: v
  end

  defp bool_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "bool", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<b <- binary>>, do: b != 0
  end

  defp pack_utf8(values) do
    values
    |> Enum.map(fn s -> <<byte_size(s)::little-unsigned-32, s::binary>> end)
    |> IO.iodata_to_binary()
  end

  defp ipc_bytes(batch) do
    schema = RecordBatch.schema(batch)
    assert {:ok, bin} = IPC.Writer.to_binary(schema, [batch])
    bin
  end

  @tag :nif
  test "from_lists builds mixed columns with exact values" do
    names = ["a", "b"]

    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, [10, 20]},
               {"score", :f64, [1.5, 2.5]},
               {"ok", :bool, [true, false]},
               {"name", :utf8, names}
             ])

    assert RecordBatch.num_rows(batch) == 2
    assert RecordBatch.column_names(batch) == ["id", "score", "ok", "name"]
    assert s64_column(batch, "id") == [10, 20]
    assert f64_column(batch, "score") == [1.5, 2.5]
    assert bool_column(batch, "ok") == [true, false]

    # Utf8 is not extractable via column_buffer; prove exact bytes vs from_columns.
    assert {:ok, expected} =
             RecordBatch.from_columns(
               ["id", "score", "ok", "name"],
               [
                 <<10::little-signed-64, 20::little-signed-64>>,
                 <<1.5::little-float-64, 2.5::little-float-64>>,
                 <<1, 0>>,
                 pack_utf8(names)
               ],
               ["s64", "f64", "bool", "utf8"],
               2
             )

    assert ipc_bytes(batch) == ipc_bytes(expected)
  end

  @tag :nif
  test "from_lists accepts string dtypes and atom names" do
    assert {:ok, batch} = RecordBatch.from_lists([{:id, "s32", [1, 2]}])
    assert Schema.field_names(RecordBatch.schema(batch)) == ["id"]

    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "s32", _n}} = Native.record_batch_column_buffer(ref, "id")
    assert for(<<v::little-signed-32 <- binary>>, do: v) == [1, 2]
  end

  @tag :nif
  test "from_lists zero-row column is allowed" do
    assert {:ok, batch} = RecordBatch.from_lists([{"id", :s64, []}])
    assert RecordBatch.num_rows(batch) == 0
    assert s64_column(batch, "id") == []
  end

  @tag :nif
  test "from_lists round-trips through IPC with exact values" do
    values = [1, 2, 3]
    names = ["x", "y", "z"]

    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, values},
               {"name", :utf8, names}
             ])

    schema = RecordBatch.schema(batch)
    assert {:ok, ipc} = IPC.Writer.to_binary(schema, [batch])
    assert {:ok, stream} = IPC.Reader.from_binary(ipc)
    assert %RecordBatch{} = restored = ExArrow.Stream.next(stream)
    assert s64_column(restored, "id") == values
    assert ipc_bytes(restored) == ipc
  end

  @tag :nif
  test "from_map sorts keys and infers dtypes" do
    assert {:ok, batch} =
             RecordBatch.from_map(%{
               "name" => ["a", "b"],
               "id" => [1, 2],
               ok: [true, false]
             })

    assert RecordBatch.column_names(batch) == ["id", "name", "ok"]
    assert s64_column(batch, "id") == [1, 2]
    assert bool_column(batch, "ok") == [true, false]

    assert {:ok, expected} =
             RecordBatch.from_lists([
               {"id", :s64, [1, 2]},
               {"name", :utf8, ["a", "b"]},
               {"ok", :bool, [true, false]}
             ])

    assert ipc_bytes(batch) == ipc_bytes(expected)
  end

  @tag :nif
  test "from_map promotes integers mixed with floats to f64" do
    assert {:ok, batch} = RecordBatch.from_map(%{"x" => [1, 2.5]})
    assert f64_column(batch, "x") == [1.0, 2.5]
  end

  test "from_lists rejects empty columns list" do
    assert {:error, msg} = RecordBatch.from_lists([])
    assert msg =~ "at least one column"
  end

  test "from_lists rejects unequal lengths" do
    assert {:error, msg} =
             RecordBatch.from_lists([{"a", :s64, [1, 2]}, {"b", :s64, [3]}])

    assert msg =~ "column lengths must match"
  end

  test "from_lists rejects nil cells" do
    assert {:error, msg} = RecordBatch.from_lists([{"a", :s64, [1, nil]}])
    assert msg =~ "nil"
  end

  test "from_lists rejects nested cells" do
    assert {:error, msg} = RecordBatch.from_lists([{"a", :s64, [[1]]}])
    assert msg =~ "scalar"
  end

  test "from_lists rejects int32 out of range" do
    assert {:error, msg} = RecordBatch.from_lists([{"a", :s32, [2_147_483_648]}])
    assert msg =~ "out of range"
  end

  test "from_lists rejects unsupported dtype" do
    assert {:error, msg} = RecordBatch.from_lists([{"a", :timestamp, [1]}])
    assert msg =~ "unsupported"
  end

  test "from_map rejects empty map" do
    assert {:error, msg} = RecordBatch.from_map(%{})
    assert msg =~ "at least one column"
  end

  test "from_map rejects empty column list" do
    assert {:error, msg} = RecordBatch.from_map(%{"a" => []})
    assert msg =~ "empty"
  end
end
