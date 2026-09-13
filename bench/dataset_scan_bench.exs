# Dataset scan pushdown ladder — timing helper for announcements.
# Usage: mix run bench/dataset_scan_bench.exs
#
# Each label states exactly what the branch measures (F-013).
# Synthetic layout: >= 8 Hive partitions, 1M+ rows total.

alias ExArrow.Compute.Expression, as: E
alias ExArrow.Dataset
alias ExArrow.Parquet
alias ExArrow.RecordBatch
alias ExArrow.Scanner
alias ExArrow.Stream

partitions = 8
rows_per_part = 150_000
total_rows = partitions * rows_per_part

root = Path.join(System.tmp_dir!(), "ex_arrow_dataset_scan_bench")
File.rm_rf!(root)

IO.puts("Writing #{total_rows} rows across #{partitions} hive partitions under #{root}...")

Enum.each(0..(partitions - 1), fn p ->
  year = 2020 + rem(p, 4)
  month = rem(p, 12) + 1
  n = rows_per_part

  ids = for i <- 1..n, into: <<>>, do: <<i + p * n::little-signed-64>>
  amounts = for i <- 1..n, into: <<>>, do: <<i * 1.0::little-float-64>>

  {:ok, batch} =
    RecordBatch.from_columns(["id", "amount"], [ids, amounts], ["s64", "f64"], n)

  schema = RecordBatch.schema(batch)
  path = Path.join(root, "year=#{year}/month=#{month}/part-0.parquet")
  File.mkdir_p!(Path.dirname(path))
  :ok = Parquet.Writer.to_file(path, schema, [batch], row_group_size: 50_000)
end)

{:ok, dataset} =
  Dataset.open(root, partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]})

measure = fn label, fun ->
  {us, result} = :timer.tc(fun)
  IO.puts("#{label}: #{Float.round(us / 1000, 1)} ms -> #{inspect(result)}")
end

measure.("full scan (all fragments, no filter, all columns)", fn ->
  {:ok, scanner} = Dataset.scanner(dataset)
  {:ok, stream} = Scanner.to_stream(scanner)
  rows = Enum.sum(Enum.map(Enum.to_list(stream), &RecordBatch.num_rows/1))
  Stream.close(stream)
  rows
end)

measure.("projection only (columns: id — no filter)", fn ->
  {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"])
  {:ok, stream} = Scanner.to_stream(scanner)
  rows = Enum.sum(Enum.map(Enum.to_list(stream), &RecordBatch.num_rows/1))
  Stream.close(stream)
  rows
end)

year_filter = E.gte(E.field("year"), E.scalar(2022))

measure.("partition-pruned (year >= 2022; opens fewer fragments)", fn ->
  {:ok, scanner} = Dataset.scanner(dataset, filter: year_filter)
  {:ok, stream} = Scanner.to_stream(scanner)
  rows = Enum.sum(Enum.map(Enum.to_list(stream), &RecordBatch.num_rows/1))
  stats = Scanner.stats(stream)
  Stream.close(stream)
  {rows, stats.fragments_pruned_partition, stats.fragments_scanned}
end)

rg_filter =
  E.and_(
    E.gte(E.field("year"), E.scalar(2022)),
    E.gt(E.field("amount"), E.scalar(140_000.0))
  )

measure.("row-group-pruned (partition + amount > 140000 Parquet filters)", fn ->
  {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"], filter: rg_filter)
  {:ok, stream} = Scanner.to_stream(scanner)
  rows = Enum.sum(Enum.map(Enum.to_list(stream), &RecordBatch.num_rows/1))
  stats = Scanner.stats(stream)
  Stream.close(stream)
  {rows, stats.row_groups_skipped, stats.row_groups_selected}
end)

residual_filter =
  E.and_(
    E.gte(E.field("year"), E.scalar(2022)),
    E.not_(E.eq(E.field("id"), E.scalar(1)))
  )

measure.("expression-residual (partition prune + not_ residual after decode)", fn ->
  {:ok, scanner} = Dataset.scanner(dataset, columns: ["id"], filter: residual_filter)
  {:ok, stream} = Scanner.to_stream(scanner)
  rows = Enum.sum(Enum.map(Enum.to_list(stream), &RecordBatch.num_rows/1))
  stats = Scanner.stats(stream)
  Stream.close(stream)
  {rows, stats.rows_emitted, stats.fragments_scanned}
end)

IO.puts("done.")
