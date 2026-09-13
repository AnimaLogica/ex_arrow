defmodule ExArrow.DatasetTest do
  use ExUnit.Case, async: true

  alias ExArrow.Dataset
  alias ExArrow.Dataset.Fragment
  alias ExArrow.FileSystem.Memory
  alias ExArrow.IPC
  alias ExArrow.Parquet
  alias ExArrow.RecordBatch
  alias ExArrow.Schema

  defp sample_schema_and_batch do
    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, [1, 2]},
               {"score", :f64, [0.1, 0.9]}
             ])

    {RecordBatch.schema(batch), batch}
  end

  defp write_parquet!(dir, relative, batch, schema) do
    path = Path.join(dir, relative)
    File.mkdir_p!(Path.dirname(path))
    assert :ok = Parquet.Writer.to_file(path, schema, [batch])
    path
  end

  describe "open/2 validation" do
    test "rejects unknown options and bad format before IO" do
      assert {:error, msg} = Dataset.open("/tmp", bogus: true)
      assert msg =~ "unknown option"

      assert {:error, msg} = Dataset.open("/tmp", format: :csv)
      assert msg =~ "format"
    end

    test "rejects empty hive schema" do
      assert {:error, msg} = Dataset.open("/tmp", partitioning: {:hive, schema: []})
      assert msg =~ "empty"
    end
  end

  describe "Memory filesystem discovery" do
    test "lists hive fragments with exact partition values and sizes" do
      assert {:ok, fs} =
               Memory.new(%{
                 "/data/year=2026/month=1/part-0.parquet" => 128,
                 "/data/year=2025/month=12/part-0.parquet" => 64,
                 "/data/.staging/skip.parquet" => 1,
                 "/data/_tmp/skip.parquet" => 1
               })

      {schema, _batch} = sample_schema_and_batch()

      assert {:ok, dataset} =
               Dataset.open("/data",
                 filesystem: fs,
                 schema: schema,
                 partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
               )

      fragments = Dataset.fragments(dataset)
      assert length(fragments) == 2

      assert Enum.map(fragments, & &1.path) == [
               "/data/year=2025/month=12/part-0.parquet",
               "/data/year=2026/month=1/part-0.parquet"
             ]

      assert Enum.map(fragments, & &1.partition_values) == [
               %{"year" => 2025, "month" => 12},
               %{"year" => 2026, "month" => 1}
             ]

      assert Enum.map(fragments, & &1.size) == [64, 128]
      assert Dataset.schema(dataset) == schema
    end

    test "glob and explicit file list" do
      assert {:ok, fs} =
               Memory.new(%{
                 "/data/a.parquet" => 10,
                 "/data/b.parquet" => 20,
                 "/data/c.txt" => 1
               })

      {schema, _} = sample_schema_and_batch()

      assert {:ok, by_glob} =
               Dataset.open("/data/*.parquet", filesystem: fs, schema: schema)

      assert Enum.map(Dataset.fragments(by_glob), & &1.path) == [
               "/data/a.parquet",
               "/data/b.parquet"
             ]

      assert {:ok, by_list} =
               Dataset.open(["/data/b.parquet", "/data/a.parquet"],
                 filesystem: fs,
                 schema: schema,
                 root: "/data"
               )

      assert Enum.map(Dataset.fragments(by_list), & &1.path) == [
               "/data/a.parquet",
               "/data/b.parquet"
             ]
    end
  end

  describe "Local filesystem" do
    @tag :tmp_dir
    test "opens hive directory, resolves schema from footer, Fragment.metadata/1", %{
      tmp_dir: dir
    } do
      {schema, batch} = sample_schema_and_batch()
      root = Path.join(dir, "events")

      p1 = write_parquet!(root, "year=2026/month=01/part-0.parquet", batch, schema)
      _p2 = write_parquet!(root, "year=2025/month=12/part-0.parquet", batch, schema)
      File.mkdir_p!(Path.join(root, ".hidden"))
      _ = write_parquet!(root, ".hidden/x.parquet", batch, schema)

      assert {:ok, dataset} =
               Dataset.open(root,
                 format: :parquet,
                 partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
               )

      fragments = Dataset.fragments(dataset)
      assert length(fragments) == 2

      assert Enum.map(fragments, & &1.partition_values) == [
               %{"year" => 2025, "month" => 12},
               %{"year" => 2026, "month" => 1}
             ]

      resolved = Dataset.schema(dataset)
      assert Schema.field_names(resolved) == ["id", "score"]

      # Footer metadata without decoding row groups via Stream.next.
      frag = Enum.find(fragments, &(&1.path == Path.expand(p1)))
      assert {:ok, meta} = Fragment.metadata(frag)
      assert meta.num_rows == 2
      assert meta.num_row_groups >= 1
    end

    @tag :tmp_dir
    test "single file and ignore_hidden: false", %{tmp_dir: dir} do
      {schema, batch} = sample_schema_and_batch()
      path = write_parquet!(dir, "only.parquet", batch, schema)
      hidden = write_parquet!(dir, ".secret/x.parquet", batch, schema)

      assert {:ok, dataset} = Dataset.open(path)
      assert [frag] = Dataset.fragments(dataset)
      assert frag.path == Path.expand(path)
      assert frag.partition_values == %{}

      assert {:ok, with_hidden} = Dataset.open(dir, ignore_hidden: false)
      paths = Enum.map(Dataset.fragments(with_hidden), & &1.path)
      assert Path.expand(path) in paths
      assert Path.expand(hidden) in paths
    end

    @tag :tmp_dir
    test "opens IPC files when format: :ipc", %{tmp_dir: dir} do
      {schema, batch} = sample_schema_and_batch()
      path = Path.join(dir, "batch.arrow")
      assert :ok = IPC.File.write(path, schema, [batch])

      assert {:ok, dataset} = Dataset.open(dir, format: :ipc)
      assert [frag] = Dataset.fragments(dataset)
      assert frag.format == :ipc
      assert Schema.field_names(Dataset.schema(dataset)) == ["id", "score"]
    end

    @tag :tmp_dir
    test "errors on malformed hive segment values", %{tmp_dir: dir} do
      {schema, batch} = sample_schema_and_batch()
      root = Path.join(dir, "bad")
      _ = write_parquet!(root, "year=not-a-number/part.parquet", batch, schema)

      assert {:error, msg} =
               Dataset.open(root,
                 partitioning: {:hive, schema: [{"year", :int32}]}
               )

      assert msg =~ "cannot parse"
    end

    @tag :tmp_dir
    test "covers open error paths and Fragment.metadata/1 for ipc", %{tmp_dir: dir} do
      {schema, batch} = sample_schema_and_batch()

      assert {:error, msg} = Dataset.open(:not_a_path)
      assert msg =~ "source"

      assert {:error, msg} = Dataset.open(dir, filesystem: :local)
      assert msg =~ "filesystem"

      assert {:error, msg} = Dataset.open(dir, ignore_hidden: "yes")
      assert msg =~ "ignore_hidden"

      assert {:error, msg} = Dataset.open(dir, root: 123)
      assert msg =~ "root"

      assert {:error, msg} = Dataset.open([], schema: schema)
      assert msg =~ "empty"

      assert {:error, msg} = Dataset.open(["/no/a.parquet"], schema: schema)
      assert msg =~ ~r/does not exist|no parquet/

      assert {:error, msg} =
               Dataset.open(["/a.parquet", "/b/c.parquet"], schema: schema, root: :bad)

      assert msg =~ "root"

      assert {:error, msg} = Dataset.open(dir, partitioning: {:hive, []})
      assert msg =~ ~r/schema|partitioning/

      empty = Path.join(dir, "empty-hive")
      File.mkdir_p!(empty)

      assert {:error, msg} =
               Dataset.open(empty, partitioning: {:hive, schema: [{"year", :int32}]})

      assert msg =~ ~r/no parquet|does not exist/

      path = Path.join(dir, "batch.arrow")
      assert :ok = IPC.File.write(path, schema, [batch])
      assert {:ok, dataset} = Dataset.open(path, format: :ipc)
      [frag] = Dataset.fragments(dataset)
      assert {:error, msg} = Fragment.metadata(frag)
      assert msg =~ "parquet"

      hive_root = Path.join(dir, "hive2")
      _ = write_parquet!(hive_root, "year=2026/part.parquet", batch, schema)

      assert {:ok, ds} =
               Dataset.open(hive_root,
                 partitioning: {:hive, [schema: [{"year", :int32}]]}
               )

      assert [%{partition_values: %{"year" => 2026}}] = Dataset.fragments(ds)

      assert {:error, msg} = Dataset.open(Path.join(dir, "missing-dir-xyz"))
      assert msg =~ "does not exist"
    end
  end
end
