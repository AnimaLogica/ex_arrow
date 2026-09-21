# Overview

The main overview, installation, quick start, and usage examples live in the
[README on GitHub](https://github.com/AnimaLogica/ex_arrow/blob/main/README.md).

## What's changed in v0.9.0

v0.9.0 adds a Dataset / Scanner layer for discovering Hive-partitioned
Parquet (and IPC) trees and scanning them with analyzable Expression filters.
Partition pruning, Parquet row-group pushdown, and residual
`Compute.filter/2` form a pushdown ladder. See the
[Datasets guide](../guides/11_datasets.md) and `livebook/06_datasets.livemd`.

New / changed:

- **`ExArrow.Dataset`** — open a directory, file, glob, or path list;
  Hive `partition_values`; schema from footer without decoding pages.
- **`ExArrow.Scanner`** — lazy `scanner/2` / `to_stream/1` with `:columns`
  and `:filter` (`Expression` or legacy tuple); `stats/1` with exact prune
  counts.
- **`ExArrow.Compute.Expression`** — builders, `validate/2`,
  `to_parquet_filters/1` (pushable vs residual).
- **`ExArrow.FileSystem`** — Local and Memory backends for discovery.
- **`RecordBatch.from_lists/1` / `from_map/1`** — ergonomic batch construction.

## What's changed in v0.8.0

v0.8.0 makes Parquet a first-class citizen for larger-than-memory workloads.
Read pushdown, write options, footer metadata, and multi-file directory
streams let you scan only the data you need.

New / changed:

- **Read pushdown** — `ExArrow.Stream.from_parquet/2` and
  `Parquet.Reader.from_file/2` / `from_binary/2` accept `:columns`
  (projection), `:row_groups` (selection), and `:filters` (a predicate AST
  with row-group statistics pruning). `Parquet.Reader.read_stats/1` reports
  selected vs skipped row groups.
- **Write options** — `:compression` (`:snappy`, `:zstd`, `{:zstd, level}`,
  `:lz4`, `:gzip`, `:none`, alias `:uncompressed`), `:row_group_size`, and `:dictionary` on
  `Writer.to_file/4` and `to_binary/3`.
- **`ExArrow.Parquet.Metadata`** — footer-only metadata (`from_file/1`,
  `from_binary/1`): row groups, per-column statistics, key-value metadata.
- **Multi-file streams** — `ExArrow.Stream.from_parquet_files/2` and
  `from_parquet_dir/2` lazily open one file at a time with schema checking;
  early `Enum.take/2` does not open later files.
- **`ExArrow.IPC.File.write/3`** and **`ExArrow.RecordBatch.concat/1`** —
  public wrappers over existing NIFs.
- Optional `arrow_testing` IPC conformance suite and a Mix.install
  optional-dep smoke CI job.

See the [Parquet guide](parquet_guide.md) and `livebook/05_parquet.livemd`.

## v0.7.2 stability update

v0.7.2 fixes optional `:gen_stage` compilation in `Mix.install` and cached-build
paths where `ex_arrow` could be compiled without `{:gen_stage, ...}` and fail at
compile time. `ExArrow.GenStage.*Producer` modules are now gated at file scope,
so `ex_arrow` compiles cleanly when `:gen_stage` is absent.

## What's changed in v0.7.0

v0.7.0 adds Arrow-native streaming and pipeline infrastructure.  The unit of
execution is the Arrow `RecordBatch` — not `list(map())`, not
`Explorer.DataFrame`, not `Nx.Tensor`.  Explorer and Nx remain downstream
consumers; ExArrow is the Arrow layer.

New modules: `ExArrow.Stream` (constructors), `ExArrow.Batch` (transforms),
`ExArrow.Pipeline` (DSL), `ExArrow.Flow`, `ExArrow.GenStage.*Producer`,
`ExArrow.Broadway` (`BatchBuilder`, `ParquetSink`, `FlightSink`),
`ExArrow.Sink.*`, and `ExArrow.Telemetry`.  Optional deps added:
`:telemetry`, `:flow`, `:gen_stage`, `:broadway`.

New guides: [05 Arrow pipelines overview](05_arrow_pipelines_overview.md),
[06 Arrow streams](06_arrow_streams.md),
[07 Arrow and Flow](07_arrow_and_flow.md),
[08 Arrow and GenStage](08_arrow_and_genstage.md),
[09 Arrow and Broadway](09_arrow_and_broadway.md),
[10 Arrow pipeline patterns](10_arrow_pipeline_patterns.md).

## Doc set

| Topic | Guide |
|-------|--------|
| Handles, copying, NIF scheduling | [Memory model](memory_model.md) |
| IPC stream and file read/write | [IPC guide](ipc_guide.md) |
| Arrow Flight client and server | [Flight guide](flight_guide.md) |
| Arrow Flight SQL remote query client | [Flight SQL guide](flight_sql_guide.md) |
| ADBC database connectivity | [ADBC guide](adbc_guide.md) |
| Parquet read and write | [Parquet guide](parquet_guide.md) |
| Datasets and scanners | [Datasets guide](../guides/11_datasets.md) |
| Compute kernels (filter, project, sort) | [Compute guide](compute_guide.md) |
| C Data Interface (CDI) | [CDI guide](cdi_guide.md) |
| Nx tensor bridge | [Nx guide](nx_guide.md) |
| Benchmarks and CI publishing | [Benchmarks guide](benchmarks.md) |

## Optional integrations

| Module | Requires | What it does |
|--------|----------|--------------|
| `ExArrow.FlightSQL.Client` | (none — built-in) | Connect to Arrow Flight SQL servers; query, stream, DML, prepared statements, metadata |
| `ExArrow.FlightSQL.Result` | (none — built-in) | Materialised Flight SQL result with `to_dataframe/1` and `to_tensor/2` |
| `ExArrow.Explorer` | `{:explorer, "~> 0.11"}` | Convert between `ExArrow.Stream`/`RecordBatch` and `Explorer.DataFrame` |
| `ExArrow.Nx` | `{:nx, "~> 0.9"}` | Convert numeric Arrow columns to/from `Nx.Tensor`; build multi-column batches from a tensor map |
| `ExArrow.CDI` | (none — built-in) | Zero-copy Arrow C Data Interface: export/import record batches as raw C struct pointers |
| `ExArrow.ADBC.ConnectionPool` | `{:nimble_pool, "~> 1.1"}` | NimblePool-backed connection pool for ADBC databases |
| `:adbc_package` backend | `{:adbc, "~> 0.9"}` + `{:explorer, "~> 0.11"}` | Supervised pure-Elixir ADBC backend; `Database.open(:adbc_package)` |
| ADBC driver download | `{:adbc, "~> 0.9"}` | `ExArrow.ADBC.DriverHelper.ensure_driver_and_open/2` |
| `ExArrow.Telemetry` | `{:telemetry, "~> 1.0"}` | Emit and observe telemetry events for every transport and pipeline operation |
| `ExArrow.Flow` | `{:flow, "~> 1.2"}` | Arrow-native Flow execution: `from_batches/1`, `map_batches/2`, `each_batch/2` |
| `ExArrow.GenStage.*Producer` | `{:gen_stage, "~> 1.2"}` | Demand-driven producers: `ParquetProducer`, `FlightProducer`, `ADBCProducer` |
| `ExArrow.Broadway` | `{:broadway, "~> 1.0"}` | Ingestion pipelines: `BatchBuilder`, `ParquetSink`, `FlightSink` |

API reference: `mix docs` or [ex-arrow.hexdocs.pm](https://ex-arrow.hexdocs.pm).
