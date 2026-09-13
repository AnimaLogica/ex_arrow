# Datasets and Scanners

ExArrow's Dataset layer is an **IO, discovery, pruning, and streaming-execution**
API, not a DataFrame API. You discover files (fragments), optionally interpret
Hive partition paths, then scan with projection and filters that push down as
far as possible before decoding row groups.

If you need column reshaping, joins, or group-by, use Explorer (or another
DataFrame tool) **after** ExArrow has streamed the batches you care about.

## Concepts

| Term | Meaning in ExArrow |
|------|--------------------|
| **Dataset** | Result of discovering files under a root (or an explicit path list). Holds fragments + schema. Does not decode data pages. |
| **Fragment** | One readable unit, usually a Parquet (or IPC file) path plus optional Hive `partition_values`. |
| **Partitioning** | How path segments map to columns. 0.9 supports `:none` and `{:hive, schema: [{name, type}, ...]}`. |
| **Scanner** | Lazy plan over a Dataset: columns, filter, batch options. No IO until `to_stream/1`. |
| **Expression** | Analyzable filter AST (`ExArrow.Compute.Expression`). Not an Elixir closure. |

## Open a Dataset

```elixir
{:ok, dataset} =
  ExArrow.Dataset.open("/data/events",
    format: :parquet,
    partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]},
    ignore_hidden: true
  )

ExArrow.Dataset.fragments(dataset)
ExArrow.Dataset.schema(dataset)
```

`open/2` accepts a directory, a single file, a glob (`*` / `**`), or a list of
paths. Pass `:filesystem` (`ExArrow.FileSystem.Local` or `Memory`) for tests
without touching the OS. Pass `:schema` to skip footer resolution (required
for Memory-only discovery when files are not OS-readable).

Schema is resolved from the first fragment's Parquet footer / IPC file
metadata without consuming batches.

## Scan

```elixir
alias ExArrow.Compute.Expression, as: E

filter =
  E.and_(
    E.gte(E.field("year"), E.scalar(2026)),
    E.gt(E.field("amount"), E.scalar(0.0))
  )

{:ok, scanner} =
  ExArrow.Dataset.scanner(dataset,
    columns: ["id", "amount"],
    filter: filter
  )

{:ok, stream} = ExArrow.Scanner.to_stream(scanner)
batches = Enum.to_list(stream)
ExArrow.Stream.close(stream)

ExArrow.Scanner.stats(stream)
```

Fragments are scanned in **path-sorted** order, one at a time. Early
`Enum.take/2` does not open later fragments. Call `ExArrow.Stream.close/1` when
abandoning a partially consumed scan from a long-lived process.

`:batch_size` is accepted for API stability but reserved in 0.9 (batches
follow Parquet row-group sizing).

## Pushdown ladder

Strongest first:

1. **Partition pruning (Elixir)** — predicates on Hive keys are evaluated
   against each fragment's `partition_values`. Non-matching fragments are
   never opened.
2. **Parquet filters (Rust / parquet-rs)** — pushable field-vs-scalar
   predicates on **data** columns become `Parquet.Reader` `:filters`
   (row-group statistics). Hive keys are stripped from this AST because they
   are not columns in the file.
3. **Residual (Rust compute)** — anything left (`not_/1`, temporal scalars
   the Parquet reader cannot bind yet, field-vs-field, OR mixes with
   partition keys) runs through `Compute.filter/2` after decode. Partition
   fields in a residual expression are bound to scalars for the current
   fragment.

`Scanner.stats/1` reports exact fragment prune/scan counts and aggregated
row-group selected/skipped counts (no `>= 1` hedges).

## Expression vs callback

Spec §13.3: Dataset filters must be **data** (Expression ASTs), not closures.
Closures cannot be analyzed for pushdown. Build with `field/1`, `scalar/1`,
and `eq/2` … `not_/1`. Validate with `Expression.validate/2` against a schema
or a field-name map (useful when merging Hive partition types).

Legacy Parquet filter tuples (`{:gt, "col", value}`, `{:and, [...]}`) remain
accepted on the scanner and on `Parquet.Reader`.

## Ordering

0.9 scans fragments sequentially in lexicographic path order. Parallel
readahead and `:ordered` options are out of scope (stretch). Do not assume
global sorted-by-column order across fragments unless your layout guarantees
it.

## PyArrow `pa.dataset` migration

| PyArrow | ExArrow 0.9 |
|---------|-------------|
| `ds.dataset(path, format="parquet", partitioning="hive")` | `Dataset.open(path, partitioning: {:hive, schema: [...]})` |
| `dataset.to_table(filter=..., columns=...)` | `Dataset.scanner` + `Scanner.to_stream` + `Enum.to_list` |
| `pc.field("x") > 0` expressions | `E.gt(E.field("x"), E.scalar(0))` |
| Fragment metadata / files | `Dataset.fragments/1`, `Fragment.metadata/1` (Parquet) |
| Dataset write | Out of scope (later release) |
| S3 / fsspec | Out of scope (planned filesystem work) |

## Related

- Guide: this file (`guides/11_datasets.md`)
- Livebook: `livebook/06_datasets.livemd`
- Parquet pushdown background: `docs/parquet_guide.md`, `livebook/05_parquet.livemd`
- Modules: `ExArrow.Dataset`, `ExArrow.Dataset.Fragment`, `ExArrow.Scanner`,
  `ExArrow.Compute.Expression`, `ExArrow.FileSystem`
