defmodule ExArrow.Fixtures.HiveEventsTest do
  use ExUnit.Case, async: true

  alias ExArrow.Compute.Expression, as: E
  alias ExArrow.Dataset
  alias ExArrow.Native
  alias ExArrow.RecordBatch
  alias ExArrow.Scanner
  alias ExArrow.Stream

  @fixture Path.expand("../fixtures/hive_events", __DIR__)

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

  @tag :nif
  test "opens PyArrow hive fixture with exact partition values and schema" do
    assert File.dir?(@fixture)

    assert {:ok, dataset} =
             Dataset.open(@fixture,
               partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
             )

    frags = Dataset.fragments(dataset)
    assert length(frags) == 3

    assert Enum.map(frags, & &1.partition_values) == [
             %{"year" => 2025, "month" => 12},
             %{"year" => 2026, "month" => 1},
             %{"year" => 2026, "month" => 2}
           ]

    assert ExArrow.Schema.field_names(Dataset.schema(dataset)) == [
             "id",
             "amount",
             "account_id"
           ]
  end

  @tag :nif
  test "scan with partition prune + projection yields exact ids" do
    assert {:ok, dataset} =
             Dataset.open(@fixture,
               partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
             )

    filter =
      E.and_(
        E.gte(E.field("year"), E.scalar(2026)),
        E.gt(E.field("amount"), E.scalar(50.0))
      )

    assert {:ok, scanner} = Dataset.scanner(dataset, columns: ["id", "amount"], filter: filter)
    assert {:ok, stream} = Scanner.to_stream(scanner)

    batches = Enum.to_list(stream)
    ids = Enum.flat_map(batches, &s64_column(&1, "id"))
    amounts = Enum.flat_map(batches, &f64_column(&1, "amount"))

    # Only id=5 (amount 100) survives year>=2026 and amount>50.
    assert ids == [5]
    assert amounts == [100.0]

    stats = Scanner.stats(stream)
    assert stats.fragments_discovered == 3
    assert stats.fragments_pruned_partition == 1
    assert stats.fragments_selected == 2
    assert stats.fragments_scanned == 2
    # 2026/01 has 2 row groups; amount>50 skips the first (max 25.5).
    # 2026/02 has 1 row group (max 50.0) skipped entirely.
    assert stats.row_groups_skipped == 2
    assert stats.row_groups_selected == 1
    assert stats.rows_emitted == 1

    Stream.close(stream)
  end
end
