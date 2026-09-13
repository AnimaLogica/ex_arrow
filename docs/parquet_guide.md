# Parquet guide

ExArrow supports reading and writing Apache Parquet files via the Arrow Rust
`parquet` crate.  The API is intentionally symmetric with `ExArrow.IPC` — you
get the same `ExArrow.Stream` interface on the read side and the same
schema + batches pattern on the write side.

> **v0.8.0**: read pushdown (`:columns`, `:row_groups`, `:filters`), write
> options (`:compression`, `:row_group_size`, `:dictionary`), footer
> `ExArrow.Parquet.Metadata`, and multi-file streams
> (`from_parquet_files/2`, `from_parquet_dir/2`). Preferred entry point:
> `ExArrow.Stream.from_parquet/2`.
>
> **v0.9.0**: for Hive-partitioned trees and Expression filters that need a
> residual, prefer `ExArrow.Dataset` / `ExArrow.Scanner` (see the
> [Datasets guide](../guides/11_datasets.md)).

---

## Reading with pushdown

```elixir
{:ok, stream} =
  ExArrow.Stream.from_parquet("/data/events.parquet",
    columns: ["user_id", "score"],
    filters: {:and, [{:gt, "score", 0.9}, {:gte, "user_id", 1}]},
    row_groups: [0, 2]
  )

stats = ExArrow.Parquet.Reader.read_stats(stream)
# %{row_groups_total: 12, row_groups_selected: 2, row_groups_skipped: 10}

{:ok, schema} = ExArrow.Stream.schema(stream)
ExArrow.Schema.field_names(schema)
# ["user_id", "score"]
```

### Filter AST

| Form | Meaning |
|------|---------|
| `{:eq \| :ne \| :gt \| :gte \| :lt \| :lte, col, value}` | Compare column to a scalar |
| `{:and, [filter, ...]}` | All must match |
| `{:or, [filter, ...]}` | Any may match |

Values may be integers, floats, UTF-8 strings, or booleans. Row-group
min/max statistics prune whole groups when possible for Int32/Int64,
Float32/Float64, Utf8, and Boolean equality; `:ne` is never pruned from
min/max alone (keeping the group is always safe). Remaining rows are
filtered during decode via parquet-rs `RowFilter`.

### Multi-file / directory

```elixir
{:ok, stream} = ExArrow.Stream.from_parquet_dir("/data/events/")
# or
{:ok, stream} = ExArrow.Stream.from_parquet_files(["a.parquet", "b.parquet"],
  columns: ["id"]
)

# Early stop does not open later files:
Enum.take(stream, 1)
```

Schema field names of each subsequent file must match the first file.

### From an in-memory binary

```elixir
parquet_bytes = File.read!("/data/events.parquet")
{:ok, stream} = ExArrow.Stream.from_parquet_binary(parquet_bytes, columns: ["id"])
```

---

## Metadata (footer only)

```elixir
{:ok, meta} = ExArrow.Parquet.Metadata.from_file("/data/events.parquet")
meta.num_rows
meta.num_row_groups
Enum.map(meta.row_groups, & &1.num_rows)
# Per-column chunk stats include path, compression, encodings, min/max
```

No row data is decoded — useful for interop debugging and planning scans.

---

## Writing with options

```elixir
:ok =
  ExArrow.Parquet.Writer.to_file("/out/result.parquet", schema, batches,
    compression: :zstd,
    row_group_size: 64_000,
    dictionary: true
  )

{:ok, bytes} =
  ExArrow.Parquet.Writer.to_binary(schema, batches, compression: {:zstd, 3})
```

Supported `:compression` values: `:none` (alias `:uncompressed`), `:snappy`,
`:zstd`, `{:zstd, level}` with `level` in `1..22`, `:lz4`, `:gzip`.

---

## Post-read compute (still available)

When pushdown is not enough, use in-memory kernels after reading:

```elixir
batch = ExArrow.Stream.next(stream)
{:ok, mask} = ExArrow.Compute.project(batch, ["is_active"])
{:ok, active} = ExArrow.Compute.filter(batch, mask)
```

---

## Object storage

ExArrow does not embed an S3 client. Download bytes with your cloud library,
then:

```elixir
{:ok, stream} = ExArrow.Stream.from_parquet_binary(bytes, columns: ["id"])
```

---

## See also

- Livebook: `livebook/05_parquet.livemd`

