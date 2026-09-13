defmodule ExArrow.ScannerTest do
  use ExUnit.Case, async: false

  alias ExArrow.Compute.Expression, as: E
  alias ExArrow.Dataset
  alias ExArrow.Native
  alias ExArrow.Parquet
  alias ExArrow.RecordBatch
  alias ExArrow.Scanner
  alias ExArrow.Stream

  defp s64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "s64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-signed-64 <- binary>>, do: v
  end

  defp write_parquet!(path, schema, batches, opts \\ []) do
    File.mkdir_p!(Path.dirname(path))
    assert :ok = Parquet.Writer.to_file(path, schema, batches, opts)
    path
  end

  defp hive_dataset!(root) do
    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, [1, 2, 100, 101]},
               {"score", :f64, [0.0, 0.5, 0.9, 1.0]}
             ])

    schema = RecordBatch.schema(batch)

    _ =
      write_parquet!(
        Path.join(root, "year=2025/month=12/part-0.parquet"),
        schema,
        [batch],
        row_group_size: 2
      )

    _ =
      write_parquet!(
        Path.join(root, "year=2026/month=01/part-0.parquet"),
        schema,
        [batch],
        row_group_size: 2
      )

    assert {:ok, dataset} =
             Dataset.open(root,
               format: :parquet,
               partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
             )

    {dataset, schema}
  end

  describe "scanner/2 and stats preview" do
    @tag :tmp_dir
    test "builds without IO and previews partition prune counts", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _schema} = hive_dataset!(root)

      filter =
        E.and_(
          E.gte(E.field("year"), E.scalar(2026)),
          E.gt(E.field("id"), E.scalar(50))
        )

      assert {:ok, scanner} =
               Dataset.scanner(dataset, columns: ["id"], filter: filter)

      preview = Scanner.stats(scanner)
      assert preview.fragments_discovered == 2
      assert preview.fragments_pruned_partition == 1
      assert preview.fragments_selected == 1
      assert preview.fragments_scanned == 0
      assert preview.row_groups_skipped == 0
      assert preview.rows_emitted == 0
    end

    test "rejects bad options" do
      assert {:error, msg} = Scanner.new(:not_a_dataset, [])
      assert msg =~ "Dataset"
    end
  end

  describe "partition prune + parquet pushdown + exact rows" do
    @tag :tmp_dir
    @tag :nif
    test "prunes fragments and row groups with exact stats", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _schema} = hive_dataset!(root)

      filter =
        E.and_(
          E.gte(E.field("year"), E.scalar(2026)),
          E.gt(E.field("id"), E.scalar(50))
        )

      assert {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"], filter: filter)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      batches = Enum.to_list(stream)
      ids = Enum.flat_map(batches, &s64_column(&1, "id"))
      assert ids == [100, 101]

      stats = Scanner.stats(stream)
      assert stats.fragments_discovered == 2
      assert stats.fragments_pruned_partition == 1
      assert stats.fragments_selected == 1
      assert stats.fragments_scanned == 1
      assert stats.row_groups_skipped == 1
      assert stats.row_groups_selected == 1
      assert stats.rows_emitted == 2

      assert Stream.next(stream) == nil
      assert Stream.next(stream) == nil

      agent = stream.resource
      assert Process.alive?(agent)
      assert :ok = Stream.close(stream)
      refute Process.alive?(agent)
    end

    @tag :tmp_dir
    @tag :nif
    test "residual not_ filter binds after decode", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _schema} = hive_dataset!(root)

      filter =
        E.and_(
          E.eq(E.field("year"), E.scalar(2026)),
          E.not_(E.eq(E.field("id"), E.scalar(100)))
        )

      assert {:ok, scanner} = Dataset.scanner(dataset, filter: filter)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      ids =
        stream
        |> Enum.to_list()
        |> Enum.flat_map(&s64_column(&1, "id"))

      assert ids == [1, 2, 101]

      stats = Scanner.stats(stream)
      assert stats.fragments_pruned_partition == 1
      assert stats.fragments_scanned == 1
      assert stats.rows_emitted == 3

      Stream.close(stream)
    end

    @tag :tmp_dir
    @tag :nif
    test "early Enum.take does not open later fragments", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _schema} = hive_dataset!(root)

      assert {:ok, scanner} = Dataset.scanner(dataset)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      assert [%RecordBatch{}] = Enum.take(stream, 1)
      opened = Scanner.dataset_opened_paths(stream)
      assert length(opened) == 1

      Stream.close(stream)
    end
  end

  describe "telemetry" do
    @tag :tmp_dir
    @tag :nif
    test "emits dataset scan span and batch source", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _schema} = hive_dataset!(root)

      parent = self()
      handler_id = "scanner-telem-#{System.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [
          [:ex_arrow, :dataset, :scan, :start],
          [:ex_arrow, :dataset, :scan, :stop],
          [:ex_arrow, :stream, :batch]
        ],
        fn event, measurements, metadata, _ ->
          send(parent, {:telem, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"])
      assert {:ok, stream} = Scanner.to_stream(scanner)
      _ = Enum.to_list(stream)
      Stream.close(stream)

      assert_receive {:telem, [:ex_arrow, :dataset, :scan, :start], _, meta}
      assert meta.fragments_discovered == 2

      assert_receive {:telem, [:ex_arrow, :stream, :batch], %{rows: rows},
                      %{source: {:dataset, path}}}

      assert rows > 0
      assert is_binary(path)

      assert_receive {:telem, [:ex_arrow, :dataset, :scan, :stop], _, _}
    end
  end

  describe "errors include fragment path" do
    @tag :tmp_dir
    @tag :nif
    test "schema mismatch names the path", %{tmp_dir: dir} do
      assert {:ok, a} = RecordBatch.from_lists([{"id", :s64, [1]}])
      assert {:ok, b} = RecordBatch.from_lists([{"x", :s64, [1]}])
      sa = RecordBatch.schema(a)
      sb = RecordBatch.schema(b)

      p1 = write_parquet!(Path.join(dir, "a.parquet"), sa, [a])
      _p2 = write_parquet!(Path.join(dir, "b.parquet"), sb, [b])

      assert {:ok, dataset} = Dataset.open(dir)
      assert {:ok, scanner} = Dataset.scanner(dataset)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      assert %RecordBatch{} = Stream.next(stream)
      assert {:error, msg} = Stream.next(stream)
      assert msg =~ "schema mismatch"
      assert msg =~ "b.parquet" or msg =~ Path.expand(Path.join(dir, "b.parquet"))

      Stream.close(stream)
      _ = p1
    end

    @tag :tmp_dir
    @tag :nif
    test "type mismatch across fragments with same column names is rejected", %{tmp_dir: dir} do
      assert {:ok, a} =
               RecordBatch.from_lists([{"id", :s64, [1, 2]}, {"amount", :f64, [1.0, 2.0]}])

      assert {:ok, b} =
               RecordBatch.from_lists([{"id", :s64, [3, 4]}, {"amount", :utf8, ["x", "y"]}])

      :ok = Parquet.Writer.to_file(Path.join(dir, "a.parquet"), RecordBatch.schema(a), [a])
      :ok = Parquet.Writer.to_file(Path.join(dir, "b.parquet"), RecordBatch.schema(b), [b])

      assert {:ok, dataset} = Dataset.open(dir)
      assert {:ok, scanner} = Dataset.scanner(dataset)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      assert %RecordBatch{} = Stream.next(stream)
      assert {:error, msg} = Stream.next(stream)
      assert msg =~ "schema mismatch"
      assert msg =~ "amount"
      Stream.close(stream)
    end

    @tag :tmp_dir
    @tag :nif
    test "stats/1 after close returns an error instead of crashing", %{tmp_dir: dir} do
      {dataset, _} = hive_dataset!(Path.join(dir, "events"))
      assert {:ok, scanner} = Dataset.scanner(dataset)
      assert {:ok, stream} = Scanner.to_stream(scanner)
      _ = Enum.to_list(stream)
      assert %{rows_emitted: _} = Scanner.stats(stream)
      assert :ok = Stream.close(stream)
      assert {:error, "stream is closed"} = Scanner.stats(stream)
    end

    @tag :tmp_dir
    @tag :nif
    test "IPC type mismatch across fragments is rejected", %{tmp_dir: dir} do
      assert {:ok, a} =
               RecordBatch.from_lists([{"id", :s64, [1]}, {"v", :f64, [1.0]}])

      assert {:ok, b} =
               RecordBatch.from_lists([{"id", :s64, [2]}, {"v", :utf8, ["x"]}])

      assert :ok = ExArrow.IPC.File.write(Path.join(dir, "a.arrow"), RecordBatch.schema(a), [a])
      assert :ok = ExArrow.IPC.File.write(Path.join(dir, "b.arrow"), RecordBatch.schema(b), [b])

      assert {:ok, dataset} = Dataset.open(dir, format: :ipc)
      assert {:ok, scanner} = Dataset.scanner(dataset)
      assert {:ok, stream} = Scanner.to_stream(scanner)

      assert %RecordBatch{} = Stream.next(stream)
      assert {:error, msg} = Stream.next(stream)
      assert msg =~ "schema mismatch"
      Stream.close(stream)
    end
  end

  describe "Compile / Partition helpers" do
    test "partition may_match? three-valued AND/OR" do
      alias ExArrow.Scanner.Partition

      expr = E.and_(E.eq(E.field("year"), E.scalar(2026)), E.gt(E.field("id"), E.scalar(0)))
      assert Partition.may_match?(expr, %{"year" => 2026})
      refute Partition.may_match?(expr, %{"year" => 2025})

      or_expr = E.or_(E.eq(E.field("year"), E.scalar(2026)), E.gt(E.field("id"), E.scalar(0)))
      assert Partition.may_match?(or_expr, %{"year" => 2025})

      assert Partition.may_match?({:gte, "year", 2026}, %{"year" => 2026})
      refute Partition.may_match?({:gte, "year", 2026}, %{"year" => 2025})
    end

    test "not_/1 and legacy and/or lists for partition prune" do
      alias ExArrow.Scanner.Partition

      expr = E.not_(E.eq(E.field("year"), E.scalar(2025)))
      assert Partition.may_match?(expr, %{"year" => 2026})
      refute Partition.may_match?(expr, %{"year" => 2025})

      assert Partition.may_match?(
               {:or, [{:eq, "year", 2026}, {:eq, "year", 2025}]},
               %{"year" => 2025}
             )

      refute Partition.may_match?(
               {:and, [{:eq, "year", 2026}, {:eq, "month", 1}]},
               %{"year" => 2026, "month" => 2}
             )
    end

    test "compile strips partition keys from pushed filters" do
      alias ExArrow.Scanner.Compile

      expr =
        E.and_(
          E.gte(E.field("year"), E.scalar(2026)),
          E.gt(E.field("id"), E.scalar(50))
        )

      assert {:ok, {pushed, residual}} = Compile.compile(expr, ["year", "month"])
      assert pushed == {:gt, "id", 50}
      assert residual == nil

      or_expr =
        E.or_(
          E.eq(E.field("year"), E.scalar(2026)),
          E.gt(E.field("id"), E.scalar(50))
        )

      assert {:ok, {nil, %E{} = residual}} = Compile.compile(or_expr, ["year"])
      assert E.to_string(residual) =~ "or_"
    end

    test "bind_partitions replaces hive fields with scalars" do
      alias ExArrow.Scanner.Compile

      expr = E.and_(E.eq(E.field("year"), E.scalar(2026)), E.gt(E.field("id"), E.scalar(0)))
      bound = Compile.bind_partitions(expr, %{"year" => 2026})
      assert to_string(bound) =~ "scalar(2026)"
      assert to_string(bound) =~ "field(\"id\")"
      assert Compile.bind_partitions(nil, %{}) == nil
    end

    test "compile partition-only expression drops residual and pushed" do
      alias ExArrow.Scanner.Compile

      expr = E.eq(E.field("year"), E.scalar(2026))
      assert {:ok, {nil, nil}} = Compile.compile(expr, ["year", "month"])

      and_only =
        E.and_(
          E.eq(E.field("year"), E.scalar(2026)),
          E.eq(E.field("month"), E.scalar(1))
        )

      assert {:ok, {nil, nil}} = Compile.compile(and_only, ["year", "month"])

      assert {:ok, {nil, nil}} =
               Compile.compile({:and, [{:eq, "year", 2026}, {:eq, "month", 1}]}, [
                 "year",
                 "month"
               ])
    end
  end

  describe "validation" do
    @tag :tmp_dir
    test "unknown filter field errors before scan", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _} = hive_dataset!(root)

      assert {:error, msg} =
               Dataset.scanner(dataset, filter: E.eq(E.field("nope"), E.scalar(1)))

      assert msg =~ "unknown field"
    end

    @tag :tmp_dir
    test "batch_size must be positive", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _} = hive_dataset!(root)

      assert {:error, msg} = Dataset.scanner(dataset, batch_size: 0)
      assert msg =~ "batch_size"

      assert {:ok, _} = Dataset.scanner(dataset, batch_size: 1024)
    end
  end

  describe "legacy filters and prune-all" do
    @tag :tmp_dir
    @tag :nif
    test "accepts legacy filter tuples and can prune every fragment", %{tmp_dir: dir} do
      root = Path.join(dir, "events")
      {dataset, _} = hive_dataset!(root)

      assert {:ok, scanner} =
               Dataset.scanner(dataset, filter: {:and, [{:eq, "year", 1999}, {:gt, "id", 0}]})

      preview = Scanner.stats(scanner)
      assert preview.fragments_pruned_partition == 2
      assert preview.fragments_selected == 0

      assert {:ok, stream} = Scanner.to_stream(scanner)
      assert Enum.to_list(stream) == []
      assert Scanner.stats(stream).fragments_scanned == 0
      Stream.close(stream)
    end
  end

  describe "IPC dataset scan" do
    @tag :tmp_dir
    @tag :nif
    test "projects columns from IPC fragments", %{tmp_dir: dir} do
      assert {:ok, batch} =
               RecordBatch.from_lists([
                 {"id", :s64, [1, 2]},
                 {"score", :f64, [0.1, 0.2]}
               ])

      schema = RecordBatch.schema(batch)
      path = Path.join(dir, "batch.arrow")
      assert :ok = ExArrow.IPC.File.write(path, schema, [batch])

      assert {:ok, dataset} = Dataset.open(dir, format: :ipc)
      assert {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"])
      assert {:ok, stream} = Scanner.to_stream(scanner)

      [out] = Enum.to_list(stream)
      assert RecordBatch.column_names(out) == ["id"]
      assert s64_column(out, "id") == [1, 2]
      Stream.close(stream)
    end
  end
end
