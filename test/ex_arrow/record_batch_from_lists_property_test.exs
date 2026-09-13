defmodule ExArrow.RecordBatchFromListsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExArrow.IPC
  alias ExArrow.Native
  alias ExArrow.RecordBatch

  defp s64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "s64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-signed-64 <- binary>>, do: v
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

  property "from_lists s64 round-trips through IPC with exact values" do
    check all(values <- list_of(integer(-1_000_000..1_000_000), min_length: 0, max_length: 40)) do
      assert {:ok, batch} = RecordBatch.from_lists([{"v", :s64, values}])
      schema = RecordBatch.schema(batch)
      assert {:ok, ipc} = IPC.Writer.to_binary(schema, [batch])
      assert {:ok, stream} = IPC.Reader.from_binary(ipc)
      assert %RecordBatch{} = restored = ExArrow.Stream.next(stream)
      assert s64_column(restored, "v") == values
    end
  end

  property "from_lists utf8 matches from_columns wire packing exactly" do
    check all(
            values <-
              list_of(string(:alphanumeric, max_length: 20), min_length: 0, max_length: 20)
          ) do
      assert {:ok, batch} = RecordBatch.from_lists([{"s", :utf8, values}])

      assert {:ok, expected} =
               RecordBatch.from_columns(["s"], [pack_utf8(values)], ["utf8"], length(values))

      assert ipc_bytes(batch) == ipc_bytes(expected)
    end
  end
end
