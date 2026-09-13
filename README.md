# ExArrow

[![CI](https://github.com/thanos/ex_arrow/actions/workflows/ci.yml/badge.svg)](https://github.com/thanos/ex_arrow/actions/workflows/ci.yml)
[![Hex version](https://img.shields.io/hexpm/v/ex_arrow.svg)](https://hex.pm/packages/ex_arrow)
[![Hex docs](https://img.shields.io/badge/docs-hexdocs.pm-blue)](https://ex-arrow.hexdocs.pm)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/thanos/ex_arrow/badge.svg?branch=main)](https://coveralls.io/github/thanos/ex_arrow?branch=main)


Native Apache Arrow for the BEAM: IPC streaming, Arrow Flight, Arrow Flight SQL, ADBC database bindings, and Arrow-native pipelines. Column data lives in Rust buffers; Elixir holds lightweight opaque handles. Precompiled NIFs for Linux, macOS, and Windows — no Rust required to use.

> **v0.9.0 — Dataset and Scanner.** Discover Hive-partitioned Parquet/IPC trees,
> filter with `ExArrow.Compute.Expression`, and scan through partition prune →
> row-group pushdown → residual `Compute.filter/2`. See
> [Datasets and scanners](#datasets-and-scanners) and the
> [Datasets guide](https://ex-arrow.hexdocs.pm/guides/11_datasets.html).
>
> **v0.8.0 — Larger-than-memory Parquet.** Column/predicate/row-group pushdown,
> write compression options, footer metadata, and multi-file directory streams.
> See [Parquet: read and write](#parquet-read-and-write) and the
> [Parquet guide](https://ex-arrow.hexdocs.pm/parquet_guide.html).
>
> **Related package:** the pure-Elixir [`arrow`](https://hex.pm/packages/arrow)
> library is a format codec (IPC encode/decode on the BEAM heap, no NIFs).
> ExArrow is the native zero-copy platform (Parquet, Flight, Flight SQL, ADBC,
> pipelines). Both speak IPC binaries and can interoperate.

---

## Contents

- [Why ExArrow was built](#why-exarrow-was-built)
- [What it brings to the Elixir ecosystem](#what-it-brings-to-the-elixir-ecosystem)
- [How ExArrow differs from Explorer, Nx, ADBC, and ExZarr](#how-exarrow-differs-from-explorer-nx-adbc-and-exzarr)
- [Where ExArrow fits](#where-exarrow-fits)
- [What this enables](#what-this-enables)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [What's changed in v0.9.0](#whats-changed-in-v090)
- [What's changed in v0.8.0](#whats-changed-in-v080)
- [What's changed in v0.7.0](#whats-changed-in-v070)
- [Livebook tutorials](#livebook-tutorials)
- [IPC: stream and file](#ipc-stream-and-file)
- [Arrow Flight: client and server](#arrow-flight-client-and-server)
- [Arrow Flight SQL: remote query servers](#arrow-flight-sql-remote-query-servers)
- [ADBC: database to Arrow streams](#adbc-database-to-arrow-streams)
- [Parquet: read and write](#parquet-read-and-write)
- [Arrow compute kernels](#arrow-compute-kernels)
- [Batch operations](#batch-operations)
- [Streaming pipelines](#streaming-pipelines)
- [Using ExArrow with Explorer](#using-exarrow-with-explorer)
- [Using ExArrow with Nx](#using-exarrow-with-nx)
- [Use case examples](#use-case-examples)
- [Benchmarks](#benchmarks)
- [Documentation](#documentation)
- [Development](#development)
- [Roadmap](#roadmap)
  - [Shipped (v0.2.0)](#shipped-v020)
  - [Shipped (v0.3.0)](#shipped-v030)
  - [Shipped (v0.4.0)](#shipped-v040)
  - [Shipped (v0.5.0)](#shipped-v050)
  - [Shipped (v0.7.0)](#shipped-v070)
  - [Shipped (v0.8.0)](#shipped-v080)
  - [Shipped (v0.9.0)](#shipped-v090)
- [FAQ](#faq)
- [License](#license)

---

## Why ExArrow was built

The Arrow ecosystem has become the de-facto interchange standard for columnar
data. Python, R, Rust, Java, Go, and C++ all speak Arrow natively. Data
warehouses, query engines, stream processors, ML frameworks, and databases
expose Arrow Flight endpoints or ADBC interfaces. The BEAM had no first-class
way to participate in this ecosystem.

ExArrow was written to fill that gap. It gives Elixir and Erlang applications
the same low-level, zero-copy Arrow primitives that the rest of the ecosystem
already takes for granted — without requiring callers to understand NIF memory
management, dirty schedulers, or the Arrow C Data Interface.

The design goal is intentionally narrow: be the reliable Arrow transport and
interchange layer for the BEAM, and let other libraries (Explorer, Nx, etc.)
do the analysis on top of it.

---

## What it brings to the Elixir Ecosystem

Prior to ExArrow, an Elixir application that needed to exchange data with a
Flight server, query a database via ADBC, or read/write an Arrow IPC file had
three options: shell out to Python, implement the protocol manually in Elixir
(row-by-row, with all the copying that entails), or simply not do it.

ExArrow adds:

- **IPC reading and writing** — Arrow stream and file formats, from binary or
a file path, in both directions. Read a file produced by PyArrow, DuckDB, or
Pandas; write a file for the same consumers. No format conversion needed.
- **Arrow Flight client and server** — Connect to Dremio, InfluxDB IOx,
Snowflake Flight endpoints, or any custom Flight service. Run an in-process
echo server for testing. Transfer Arrow streams over gRPC with one API call.
- **Arrow Flight SQL client** — Execute SQL against remote Flight SQL servers
(DuckDB, DataFusion, Dremio, InfluxDB v3) and receive results as lazy Arrow
streams. Supports TLS, bearer-token auth, prepared statements with parameter
binding, and metadata discovery.
- **ADBC database connectivity** — Execute SQL against any ADBC-compatible
database (SQLite, PostgreSQL, DuckDB, BigQuery, Snowflake, and more) and
receive the results as a lazy Arrow stream — never materialising rows into
BEAM terms unless you ask for them.
- **Zero-copy streaming** — Column buffers are allocated once in Rust and held
there until consumed. The BEAM scheduler is never stalled on large copies.
Dirty NIF schedulers are used for blocking I/O.
- **A uniform stream abstraction** — `ExArrow.Stream` works identically for
  IPC, Flight, and ADBC results. Code that processes batches does not know or
  care where the data came from.
- **Arrow-native pipelines** — `ExArrow.Pipeline` provides a lazy,
  composable DSL for transforming and sinking streams of `RecordBatch` values.
  `ExArrow.Flow`, `ExArrow.GenStage`, and `ExArrow.Broadway` integrations
  cover parallel, demand-driven, and ingestion workloads.  Telemetry events
  fire at every stage. **Larger-than-memory Parquet** (pushdown, write options,
  multi-file streams) lands in v0.8.0.

---

## How ExArrow differs from Explorer, Nx, ADBC, and ExZarr

These libraries are complementary, not competing. Each has a distinct role.


| Library                 | Role                                                                                                    | Overlap with ExArrow                                                                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Explorer**            | In-memory dataframe analysis (filter, group, sort, plot). Backed by Polars/Arrow internally.            | Explorer can load/dump Arrow IPC streams. ExArrow is the transport; Explorer is the analysis layer.                                                              |
| **Nx**                  | Numerical computing and tensor operations (multi-dimensional arrays, GPU support, ML).                  | `ExArrow.Nx` (v0.3+) converts Arrow numeric columns to `Nx.Tensor` values by sharing the raw byte buffer — no list materialisation. Add `{:nx, "~> 0.9"}` to enable. |
| **adbc** (livebook-dev) | Elixir wrapper around the ADBC C library for driver management — downloading and configuring drivers.   | ExArrow uses `adbc` optionally for driver download; `adbc`'s core purpose is driver lifecycle, not Arrow streaming or Flight.                                    |
| **ExZarr**              | Read/write Zarr v2/v3 chunked array format (used in climate science, genomics, cloud-native ND arrays). | Zarr and Arrow are complementary storage formats. ExZarr addresses ND chunk storage; ExArrow addresses columnar interchange and network transport.               |


**In short:** ExArrow is a transport and interchange library. It moves Arrow
data between processes, databases, services, and files as efficiently as
possible. It does not analyse, transform, or visualise data — that is the job
of Explorer, Nx, or your own application logic.

---

## Where ExArrow fits

```mermaid
flowchart TB
    App("Your Elixir Application")

    App --> Explorer("Explorer\ndataframes & analysis")
    App --> Nx("Nx\ntensors & ML")
    App --> ExArrow("ExArrow\nIPC · Flight · ADBC · Pipelines")
    App --> ExZarr("ExZarr\nZarr chunked arrays")

    ExArrow --> IPC("Arrow IPC\nstream & file")
    ExArrow --> FlightSvr("Arrow Flight\ngRPC server")
    ExArrow --> FlightSQL("Arrow Flight SQL\nremote query server")
    ExArrow --> ADBCDrv("ADBC\ndriver")
    ExArrow --> Pipeline("Pipelines\nStream · Batch · Sink")
    ExArrow --> Flow("Flow · GenStage · Broadway")

    IPC -. "interop via IPC binary" .-> Explorer
    Pipeline -. "RecordBatch" .-> Explorer
    Pipeline -. "RecordBatch" .-> Nx

    FlightSvr --> FlightSvcs("Dremio · InfluxDB IOx\nCustom Flight services")
    FlightSQL --> SQLSvcs("DuckDB · DataFusion\nDremio · InfluxDB v3")
    ADBCDrv   --> Databases("PostgreSQL · SQLite\nDuckDB · BigQuery")

    classDef app      fill:#1a1a2e,stroke:#4a90d9,color:#e0e0e0,rx:6
    classDef lib      fill:#16213e,stroke:#4a90d9,color:#e0e0e0,rx:6
    classDef proto    fill:#0f3460,stroke:#4a90d9,color:#e0e0e0,rx:6
    classDef external fill:#1a1a2e,stroke:#888,color:#aaa,rx:6,stroke-dasharray:4 4

    class App app
    class Explorer,Nx,ExArrow,ExZarr lib
    class IPC,FlightSvr,FlightSQL,ADBCDrv,Pipeline,Flow proto
    class FlightSvcs,SQLSvcs,Databases external
```

ExArrow sits at the boundary between the BEAM and the Arrow ecosystem. It
speaks the protocols that data infrastructure uses — IPC, Flight, ADBC — and
surfaces them as idiomatic Elixir APIs. Explorer and Nx sit above it and
consume the data it delivers.

---

## What this enables

- **Elixir as a data pipeline node.** Read Arrow IPC from Kafka, HTTP, or a
socket; apply lightweight routing or filtering; forward via Flight or write
to file — without ever copying column data into BEAM terms.
- **Zero-copy query results.** Run SQL against PostgreSQL, DuckDB, SQLite, or
BigQuery via ADBC. The result stream is backed by native Arrow buffers. A
100-million-row result set uses minimal BEAM heap regardless of size.
- **Interop with the Python/R data world.** Read files produced by PyArrow,
Pandas, or Polars. Write files that DuckDB, R's arrow package, or any Arrow
consumer can read. No CSV conversion, no schema translation.
- **First-class Flight client.** Connect to Dremio, InfluxDB IOx, or any
service that exposes an Arrow Flight endpoint. List flights, fetch schemas,
stream data, or call custom actions — from a Phoenix controller, a GenServer,
or a Livebook cell.
- **Benchmarked, observable performance.** The included Benchee suite
quantifies the zero-copy advantage and publishes results per commit at
[thanos.github.io/ex_arrow/dev/bench](https://thanos.github.io/ex_arrow/dev/bench/).

---

## Requirements

- Elixir ~> 1.14. CI covers Elixir 1.18/OTP 27, 1.19/OTP 28, and
  1.20/OTP 29.

---

## Installation

Add the dependency:

```elixir
def deps do
  [{:ex_arrow, "~> 0.9"}]
end
```

**Using precompiled NIFs (default)**
After `mix deps.get` and `mix compile`, ExArrow downloads a prebuilt NIF for
your platform from the project's GitHub releases. No Rust or C toolchain is
required. Supported platforms: Linux x8664/aarch64, macOS x8664/arm64,
Windows x8664.

**Building from source**
If no precompiled NIF exists for your platform, or you are developing ExArrow
itself, have Rust installed.  In **dev/test**, `mix compile` builds the NIF from
source automatically.  For other environments, set `EX_ARROW_BUILD=1`:

```bash
mix deps.get
mix compile
```

The optional dependency `{:rustler, "~> 0.36 or ~> 0.38", optional: true}` is required
for source builds and is already listed in ExArrow's own `mix.exs`.

For **path dependencies** in Livebook (`Mix.install`), open notebooks from
`livebook/` in a clone (setup cells set `EX_ARROW_BUILD=1` when a local checkout
is detected) or use the Hex package:

```elixir
Mix.install([{:ex_arrow, "~> 0.9.0"}, {:rustler, "~> 0.36", optional: true}])
```

Alternatively, use the published Hex package so the precompiled NIF is used
and no Rust is needed: `Mix.install([{:ex_arrow, "~> 0.9.0"}])`.

---

## Quick start

**Read Parquet with pushdown** (v0.8.0 — one entry point for every source):

```elixir
{:ok, stream} = ExArrow.Stream.from_parquet("/data/events.parquet")
{:ok, schema} = ExArrow.Stream.schema(stream)
Enum.each(stream, fn batch ->
  IO.puts("rows: #{ExArrow.RecordBatch.num_rows(batch)}")
end)
```

**Build a pipeline** (lazy `map_batches` + sink):

```elixir
ExArrow.Stream.from_parquet("/data/events.parquet")
|> ExArrow.Pipeline.map_batches(fn batch ->
  {:ok, slim} = ExArrow.Batch.select(batch, ["id", "score"])
  slim
end)
|> ExArrow.Pipeline.write_parquet("/data/slim.parquet")
```

**Read an Arrow IPC stream:**

```elixir
{:ok, stream} = ExArrow.IPC.Reader.from_file("/path/to/data.arrow")
{:ok, schema} = ExArrow.Stream.schema(stream)
fields = ExArrow.Schema.fields(schema)

case ExArrow.Stream.next(stream) do
  %ExArrow.RecordBatch{} = batch -> IO.inspect(ExArrow.RecordBatch.num_rows(batch))
  nil -> :done
  {:error, msg} -> IO.puts("Error: #{msg}")
end
```

**Connect to an Arrow Flight server:**

```elixir
{:ok, client} = ExArrow.Flight.Client.connect("localhost", 9999, [])
{:ok, stream} = ExArrow.Flight.Client.do_get(client, "my_ticket")
{:ok, schema} = ExArrow.Stream.schema(stream)
batch = ExArrow.Stream.next(stream)
```

**Query a remote Flight SQL server (DuckDB, DataFusion, Dremio):**

```elixir
{:ok, client} = ExArrow.FlightSQL.Client.connect("localhost:32010")
{:ok, result} = ExArrow.FlightSQL.Client.query(client, "SELECT id, name FROM users")
result.num_rows  #=> 42

# Lazy streaming for large result sets
{:ok, stream} = ExArrow.FlightSQL.Client.stream_query(client, "SELECT * FROM events")
Enum.each(stream, fn batch -> process(batch) end)

# Parameterized query
{:ok, stmt} = ExArrow.FlightSQL.Client.prepare(client, "SELECT * FROM users WHERE id = ?")
{:ok, params} = ExArrow.RecordBatch.from_columns(["id"], [<<1::little-signed-64>>], ["s64"], 1)
:ok = ExArrow.FlightSQL.Statement.bind(stmt, params)
{:ok, stream} = ExArrow.FlightSQL.Statement.execute(stmt)
:ok = ExArrow.FlightSQL.Statement.close(stmt)
```

**Query a database with ADBC:**

```elixir
{:ok, db} = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: ":memory:")
{:ok, conn} = ExArrow.ADBC.Connection.open(db)
{:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
{:ok, schema} = ExArrow.Stream.schema(stream)
batch = ExArrow.Stream.next(stream)
```

---

## What's changed in v0.9.0

v0.9.0 adds a **Dataset / Scanner** layer on top of v0.8.0 Parquet pushdown:
discover partitioned trees, compile analyzable Expression filters, and scan
with a three-level pushdown ladder (Hive partition prune → Parquet row-group
pushdown → residual `Compute.filter/2`).

### Dataset, Scanner, Expression

| API | Purpose |
|-----|---------|
| `ExArrow.Dataset.open/2` | Open a directory, file, glob, or path list; Hive `partition_values` |
| `ExArrow.Dataset.Fragment` | One file fragment with path, format, size, partition map |
| `ExArrow.Dataset.scanner/2` | Lazy scan plan: `:columns`, `:filter`, `:batch_size` |
| `ExArrow.Scanner.to_stream/1` | Agent-backed `:dataset` stream; `Stream.close/1` for early abandon |
| `ExArrow.Scanner.stats/1` | Exact fragment / row-group prune counts (preview or live) |
| `ExArrow.Compute.Expression` | Builders, `validate/2`, `to_parquet_filters/1` (pushable vs residual) |
| `ExArrow.Compute.filter/2` | Residual evaluation of an Expression against a RecordBatch |
| `ExArrow.FileSystem` | `Local` and `Memory` discovery backends |
| `RecordBatch.from_lists/1`, `from_map/1` | Ergonomic batch construction |

Native stack: arrow-rs / parquet / arrow-flight **59.3.0** (from 56).

### Docs, Livebook, bench

- Datasets Livebook (`livebook/06_datasets.livemd`) and
  [Datasets guide](guides/11_datasets.md)
- Pushdown-ladder timing helper: `bench/dataset_scan_bench.exs`

See [CHANGELOG.md](CHANGELOG.md) for the full list.

---

## What's changed in v0.8.0

v0.8.0 focuses on **larger-than-memory Parquet**: read only the columns, row
groups, and rows you need, with peak memory scaling to the selected data rather
than the whole file. Pipeline modules from v0.7.0 remain the streaming layer on
top.

### Parquet power-read / write

| API | Purpose |
|-----|---------|
| `ExArrow.Stream.from_parquet/2` | Preferred entry: `:columns`, `:row_groups`, `:filters` pushdown |
| `ExArrow.Parquet.Reader` | Same opts on `from_file/2` / `from_binary/2`; `read_stats/1` for pruning |
| `ExArrow.Parquet.Writer` | `:compression` (`:snappy`, `:zstd`, `{:zstd, level}`, `:lz4`, `:gzip`, `:none`), `:row_group_size`, `:dictionary` |
| `ExArrow.Parquet.Metadata` | Footer-only metadata (row groups, column stats, encodings, kv) |
| `Stream.from_parquet_files/2`, `from_parquet_dir/2` | Lazy multi-file / directory streams; `Stream.close/1` for early abandon |
| `ExArrow.IPC.File.write/3`, `RecordBatch.concat/1` | Public wrappers for existing NIFs |

Filter AST examples: `{:gt, "score", 0.9}`,
`{:and, [{:gte, "id", 1}, {:lt, "id", 1000}]}`. Row-group min/max statistics
prune when safe; remaining rows use parquet-rs `RowFilter`.

### Docs, Livebook, CI

- Parquet Livebook (`livebook/05_parquet.livemd`) and rewritten
  [Parquet guide](https://ex-arrow.hexdocs.pm/parquet_guide.html)
- Pushdown timing helper: `bench/parquet_pushdown_bench.exs`
- Mix.install optional-dep smoke job; Livebook Hex-pin check; optional
  apache/arrow-testing suite (local / `workflow_dispatch`)

See [CHANGELOG.md](CHANGELOG.md) for the full list.

---

## What's changed in v0.7.0

v0.7.0 turned ExArrow from a transport and interchange library into the
foundation for **Arrow-native data pipelines on the BEAM**.  The central
architectural principle: **operate on Arrow `RecordBatch` values** — not
`list(map())`, not `Explorer.DataFrame`, not `Nx.Tensor`.  Explorer and Nx
remain downstream consumers; ExArrow is the Arrow layer.

### New modules

| Module                       | Purpose                                                          |
|------------------------------|------------------------------------------------------------------|
| `ExArrow.Stream`             | `from_parquet/1`, `from_ipc/1`, `from_flight/2`, `from_flight_sql/2`, `from_adbc/1,2` constructors with source tracking and telemetry |
| `ExArrow.Batch`              | Lightweight RecordBatch transforms: `schema/1`, `select/2`, `drop/2`, `rename/2`, `take/2`, `filter/2` |
| `ExArrow.Pipeline`           | Lazy pipeline DSL: `map_batches/2`, `each_batch/2`, `write_parquet/2`, `write_flight/3`, `write_dataframe/1` |
| `ExArrow.Flow`               | Arrow-native Flow execution: `from_batches/1`, `map_batches/2`, `each_batch/2` |
| `ExArrow.GenStage`           | Demand-driven producers: `ParquetProducer`, `FlightProducer`, `ADBCProducer` |
| `ExArrow.Broadway`           | Ingestion pipelines: `BatchBuilder`, `ParquetSink`, `FlightSink` |
| `ExArrow.Sink.Parquet`       | Write a stream to a Parquet file                                  |
| `ExArrow.Sink.Flight`        | Upload a stream to a Flight server                                |
| `ExArrow.Sink.DataFrame`     | Convert a stream to an Explorer DataFrame                         |
| `ExArrow.Sink.Nx`            | Convert a batch to an Nx tensor                                   |
| `ExArrow.Telemetry`          | Telemetry events for every transport and pipeline operation       |

### Optional dependencies added

```elixir
{:telemetry, "~> 1.0", optional: true},
{:flow, "~> 1.2", optional: true},
{:gen_stage, "~> 1.2", optional: true},
{:broadway, "~> 1.0", optional: true}
```

All degrade gracefully when absent — `ExArrow.Telemetry.execute/3` is a no-op
without `:telemetry`, the Flow/GenStage/Broadway modules return
`{:error, "..."}` without their respective deps.

### Telemetry events

`[:ex_arrow, :flight, :query]`, `[:ex_arrow, :flight_sql, :query]`,
`[:ex_arrow, :parquet, :read]`, `[:ex_arrow, :parquet, :write]`,
`[:ex_arrow, :stream, :batch]`, `[:ex_arrow, :pipeline, :batch]`.  See
`ExArrow.Telemetry` for measurements and metadata.

### New guides

- [05 Arrow pipelines overview](guides/05_arrow_pipelines_overview.md)
- [06 Arrow streams](guides/06_arrow_streams.md)
- [07 Arrow and Flow](guides/07_arrow_and_flow.md)
- [08 Arrow and GenStage](guides/08_arrow_and_genstage.md)
- [09 Arrow and Broadway](guides/09_arrow_and_broadway.md)
- [10 Arrow pipeline patterns](guides/10_arrow_pipeline_patterns.md)
- [11 Datasets and scanners](guides/11_datasets.md)

### New benchmarks

- `bench/v070_stream_flow_pipeline_bench.exs` — Parquet/IPC stream drains,
  Flow execution, Pipeline `map_batches` + `write_parquet` at 1K/100K/1M rows.
- `bench/v070_record_batch_vs_maps_bench.exs` — Arrow `RecordBatch` vs
  `list(map())` for build, transform, and drain.

---

## Livebook tutorials

Interactive notebooks (open in [Livebook](https://livebook.dev)):

- **[Quick start](livebook/00_quickstart.livemd)** — IPC, Flight, ADBC (`:adbc_package`), Explorer/Nx interchange.
- **[01 IPC](livebook/01_ipc.livemd)** — Stream vs file format, read/write, schema, Explorer interop.
- **[02 Flight](livebook/02_flight.livemd)** — Echo server, client, metadata APIs, Flight SQL prepared statements.
- **[03 ADBC](livebook/03_adbc.livemd)** — Database, Connection, Statement, Stream (`:adbc_package` in Livebook).
- **[04 ADBC integration](livebook/04_adbc_integration.livemd)** — Connection pooling with NimblePool.
- **[05 Parquet](livebook/05_parquet.livemd)** — Pushdown reads, compressed writes, multi-file directories, PyArrow side-by-side.
- **[06 Datasets](livebook/06_datasets.livemd)** — Hive Dataset open, Expression scanner, prune stats, PyArrow `dataset` side-by-side.

See [livebook/README.md](livebook/README.md) for run instructions. Notebooks use Hex `~> 0.9.0` by default; opening from `livebook/` in a clone builds from source.

---

## IPC: stream and file

**Stream (sequential)** — from binary or file path:

```elixir
{:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bytes)
{:ok, stream} = ExArrow.IPC.Reader.from_file("/data/events.arrow")

{:ok, schema} = ExArrow.Stream.schema(stream)

Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
|> Enum.take_while(&(&1 != nil and not match?({:error, _}, &1)))
```

**Write to binary or file:**

```elixir
{:ok, binary} = ExArrow.IPC.Writer.to_binary(schema, batches)
:ok = ExArrow.IPC.Writer.to_file("/out/result.arrow", schema, batches)
```

**File format (random access):**

```elixir
{:ok, file} = ExArrow.IPC.File.from_file("/data/large.arrow")
{:ok, schema} = ExArrow.IPC.File.schema(file)
n = ExArrow.IPC.File.batch_count(file)
{:ok, batch} = ExArrow.IPC.File.get_batch(file, 0)
```

---

## Arrow Flight: client and server

**Start the built-in echo server:**

```elixir
{:ok, server} = ExArrow.Flight.Server.start_link(9999)
{:ok, port} = ExArrow.Flight.Server.port(server)
:ok = ExArrow.Flight.Server.stop(server)
```

**Transfer data:**

```elixir
{:ok, client} = ExArrow.Flight.Client.connect("localhost", 9999, [])

# Put under a named ticket (multi-dataset routing, added in v0.2)
:ok = ExArrow.Flight.Client.do_put(client, schema, [batch1, batch2],
        descriptor: {:cmd, "sales_2024"})

# Default ticket "echo" when no descriptor is given
:ok = ExArrow.Flight.Client.do_put(client, schema, [batch1, batch2])

{:ok, stream} = ExArrow.Flight.Client.do_get(client, "sales_2024")
batch = ExArrow.Stream.next(stream)
```

**Metadata:**

```elixir
{:ok, flights} = ExArrow.Flight.Client.list_flights(client, <<>>)
{:ok, info}    = ExArrow.Flight.Client.get_flight_info(client, {:cmd, "echo"})
{:ok, schema}  = ExArrow.Flight.Client.get_schema(client, {:cmd, "echo"})
{:ok, actions} = ExArrow.Flight.Client.list_actions(client)
{:ok, ["pong"]} = ExArrow.Flight.Client.do_action(client, "ping", <<>>)
# List all stored datasets (v0.2+)
{:ok, tickets} = ExArrow.Flight.Client.do_action(client, "list_tickets", <<>>)
```

**TLS (v0.2+):**

```elixir
# One-way TLS — server presents a certificate
{:ok, server} = ExArrow.Flight.Server.start_link(9999,
  tls: [cert_pem: File.read!("server.crt"), key_pem: File.read!("server.key")])

# Mutual TLS — both sides present certificates
{:ok, server} = ExArrow.Flight.Server.start_link(9999,
  tls: [cert_pem: cert, key_pem: key, ca_cert_pem: File.read!("ca.crt")])

# Client with custom CA
{:ok, client} = ExArrow.Flight.Client.connect("host", 9999,
  tls: [ca_cert_pem: File.read!("ca.crt")])
```

Plaintext continues to work as before. Products that speak Arrow Flight
include Dremio, InfluxDB IOx, and custom analytics servers.

---

## Arrow Flight SQL: remote query servers

Arrow Flight SQL layers SQL semantics on top of Arrow Flight.  Use it to
connect to remote query servers — DuckDB over the network, DataFusion,
Dremio, or InfluxDB v3.  For in-process databases, use ADBC instead.

**Connect and query:**

```elixir
{:ok, client} = ExArrow.FlightSQL.Client.connect("localhost:32010")

# Materialised — all batches collected
{:ok, result} = ExArrow.FlightSQL.Client.query(client, "SELECT * FROM orders LIMIT 1000")
result.num_rows  #=> 1000
result.schema    #=> %ExArrow.Schema{...}
result.batches   #=> [%ExArrow.RecordBatch{...}, ...]

# Lazy — stream one batch at a time (Enumerable)
{:ok, stream} = ExArrow.FlightSQL.Client.stream_query(client, "SELECT * FROM big_table")
batches = Enum.to_list(stream)
first_two = Enum.take(stream, 2)

# DML
{:ok, 5}        = ExArrow.FlightSQL.Client.execute(client, "DELETE FROM logs WHERE old = true")
{:ok, :unknown} = ExArrow.FlightSQL.Client.execute(client, "CREATE TABLE t (id INT)")
```

**TLS and authentication:**

```elixir
# Remote host — TLS with OS trust store (automatic)
{:ok, client} = ExArrow.FlightSQL.Client.connect("dremio.example.com:32010")

# Custom CA certificate
pem = File.read!("priv/ca.pem")
{:ok, client} = ExArrow.FlightSQL.Client.connect("secure.server:32010",
  tls: [ca_cert_pem: pem])

# Bearer token
{:ok, client} = ExArrow.FlightSQL.Client.connect("dremio.example.com:32010",
  tls: true,
  headers: [{"authorization", "Bearer my-pat-token"}])
```

**Prepared statements with parameter binding:**

```elixir
# Prepare
{:ok, stmt} = ExArrow.FlightSQL.Client.prepare(client, "SELECT * FROM users WHERE id = ?")

# Inspect expected parameter schema
{:ok, schema} = ExArrow.FlightSQL.Statement.parameter_schema(stmt)

# Bind parameters as an Arrow RecordBatch
{:ok, params} = ExArrow.RecordBatch.from_columns(["id"], [<<42::little-signed-64>>], ["s64"], 1)
:ok = ExArrow.FlightSQL.Statement.bind(stmt, params)

# Execute
{:ok, stream} = ExArrow.FlightSQL.Statement.execute(stmt)
batches = Enum.to_list(stream)

# Re-bind and re-execute the same statement
{:ok, other} = ExArrow.RecordBatch.from_columns(["id"], [<<99::little-signed-64>>], ["s64"], 1)
:ok = ExArrow.FlightSQL.Statement.bind(stmt, other)
{:ok, stream2} = ExArrow.FlightSQL.Statement.execute(stmt)

# Close when done (idempotent)
:ok = ExArrow.FlightSQL.Statement.close(stmt)
```

**Metadata discovery:**

```elixir
{:ok, stream} = ExArrow.FlightSQL.Client.get_tables(client,
  db_schema_filter: "public", table_types: ["TABLE", "VIEW"])
{:ok, stream} = ExArrow.FlightSQL.Client.get_db_schemas(client)
{:ok, stream} = ExArrow.FlightSQL.Client.get_sql_info(client)
```

**Explorer and Nx integration:**

```elixir
{:ok, result} = ExArrow.FlightSQL.Client.query(client, "SELECT * FROM sales")
{:ok, df}     = ExArrow.FlightSQL.Result.to_dataframe(result)   # requires Explorer
{:ok, tensor} = ExArrow.FlightSQL.Result.to_tensor(result, "price")  # requires Nx
```

**Unit testing with Mox** (no server needed):

```elixir
Mox.defmock(MyApp.FlightSQLMock, for: ExArrow.FlightSQL.ClientBehaviour)
Application.put_env(:ex_arrow, :flight_sql_client_impl, MyApp.FlightSQLMock)
```

See [docs/flight_sql_guide.md](docs/flight_sql_guide.md) for the full guide.

---

## ADBC: database to Arrow streams

**SQLite in-memory:**

```elixir
{:ok, db}   = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: ":memory:")
{:ok, conn} = ExArrow.ADBC.Connection.open(db)
{:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n, 'hello' AS s")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
batch = ExArrow.Stream.next(stream)
```

**PostgreSQL:**

```elixir
{:ok, db} = ExArrow.ADBC.Database.open(
  driver_name: "adbc_driver_postgresql",
  uri: "postgresql://user:pass@localhost:5432/mydb"
)
{:ok, conn}   = ExArrow.ADBC.Connection.open(db)
{:ok, stmt}   = ExArrow.ADBC.Statement.new(conn, "SELECT id, name FROM users")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
```

**DuckDB:**

DuckDB's ADBC driver uses `path` (not `uri`) for the database location, and
requires an explicit `entrypoint`:

```elixir
{:ok, db} = ExArrow.ADBC.Database.open(
  driver_path: "/usr/local/lib/libduckdb.so",
  entrypoint: "duckdb_adbc_init",
  path: ":memory:"                             # or a file path
)
{:ok, conn}   = ExArrow.ADBC.Connection.open(db)
{:ok, stmt}   = ExArrow.ADBC.Statement.new(conn, "SELECT 42 AS answer")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
batches = ExArrow.Stream.to_list(stream)
```

**Connection pool (v0.2+):**

`ExArrow.ADBC.ConnectionPool` is a NimblePool-backed pool that reuses open
connections. Start it under a supervisor with a named `DatabaseServer`:

```elixir
children = [
  {ExArrow.ADBC.DatabaseServer,
    name: :mydb,
    driver_name: "adbc_driver_postgresql",
    uri: "postgresql://localhost/mydb"},
  {ExArrow.ADBC.ConnectionPool,
    name: :mypool, database: :mydb, pool_size: 4}
]
Supervisor.start_link(children, strategy: :one_for_one)

# Query from anywhere in the application:
{:ok, stream} = ExArrow.ADBC.ConnectionPool.query(:mypool,
                  "SELECT * FROM events WHERE day = today()")

# Multi-statement checkout:
ExArrow.ADBC.ConnectionPool.with_connection(:mypool, fn conn ->
  {:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT count(*) FROM users")
  ExArrow.ADBC.Statement.execute(stmt)
end)
```

Requires `{:nimble_pool, "~> 1.1"}` in your `mix.exs`.

**Metadata:**

```elixir
{:ok, types_stream} = ExArrow.ADBC.Connection.get_table_types(conn)
{:ok, schema}       = ExArrow.ADBC.Connection.get_table_schema(conn, nil, nil, "users")
{:ok, objs_stream}  = ExArrow.ADBC.Connection.get_objects(conn, depth: "tables")
```

**Optional driver download via the `adbc` package:**

```elixir
# Add {:adbc, "~> 0.9"} to deps, then:
Adbc.download_driver!(:sqlite)
{:ok, db} = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: ":memory:")
```

Or use the convenience helper which calls `Adbc.download_driver!/1` when the
package is available: `ExArrow.ADBC.DriverHelper.ensure_driver_and_open/2`.

---

## Parquet: read and write

**Read with pushdown (v0.8+):**

```elixir
{:ok, stream} =
  ExArrow.Stream.from_parquet("/data/events.parquet",
    columns: ["user_id", "score"],
    filters: {:gt, "score", 0.9}
  )

ExArrow.Parquet.Reader.read_stats(stream)
# %{row_groups_total: ..., row_groups_selected: ..., row_groups_skipped: ...}
```

**Multi-file / directory:**

```elixir
{:ok, stream} = ExArrow.Stream.from_parquet_dir("/data/events/")
```

**Write with compression:**

```elixir
:ok =
  ExArrow.Parquet.Writer.to_file("/out/result.parquet", schema, batches,
    compression: :zstd,
    row_group_size: 64_000
  )
```

**Footer metadata (no row decode):**

```elixir
{:ok, meta} = ExArrow.Parquet.Metadata.from_file("/data/events.parquet")
meta.num_row_groups
```

Full guide: [docs/parquet_guide.md](docs/parquet_guide.md). Livebook:
`livebook/05_parquet.livemd`.

---

## Datasets and scanners

Discover Hive-partitioned Parquet (or IPC) trees, then scan with projection
and Expression filters. Partition pruning, Parquet row-group pushdown, and
residual `Compute.filter/2` form a pushdown ladder.

```elixir
alias ExArrow.Compute.Expression, as: E

{:ok, dataset} =
  ExArrow.Dataset.open("/data/events",
    partitioning: {:hive, schema: [{"year", :int32}, {"month", :int32}]}
  )

filter =
  E.and_(
    E.gte(E.field("year"), E.scalar(2026)),
    E.gt(E.field("amount"), E.scalar(0.0))
  )

{:ok, scanner} =
  ExArrow.Dataset.scanner(dataset, columns: ["id", "amount"], filter: filter)

{:ok, stream} = ExArrow.Scanner.to_stream(scanner)
batches = Enum.to_list(stream)
ExArrow.Stream.close(stream)
ExArrow.Scanner.stats(stream)
```

Full guide: [guides/11_datasets.md](guides/11_datasets.md). Livebook:
`livebook/06_datasets.livemd`.

---

## Arrow compute kernels

All operations run entirely in native memory. Results are new
`ExArrow.RecordBatch` handles — no data is copied into BEAM terms.

**Filter rows** using a boolean column as a predicate:

```elixir
# Build a predicate batch where the first column is a boolean mask
{:ok, filtered} = ExArrow.Compute.filter(batch, predicate_batch)
```

**Project (select) columns:**

```elixir
{:ok, slim} = ExArrow.Compute.project(batch, ["id", "name", "score"])
```

**Sort by column:**

```elixir
{:ok, sorted_asc}  = ExArrow.Compute.sort(batch, "score")
{:ok, sorted_desc} = ExArrow.Compute.sort(batch, "score", ascending: false)
```

---

## Batch operations

`ExArrow.Batch` provides lightweight `RecordBatch` transforms that
stay in native Arrow memory.  It is not a dataframe — use Explorer for
analytics.  All functions return `{:ok, batch} | {:error, message}`.

```elixir
# Project a subset of columns (works for every Arrow type)
{:ok, slim} = ExArrow.Batch.select(batch, ["id", "score"])

# Drop columns
{:ok, rest} = ExArrow.Batch.drop(batch, ["internal_flag"])

# Rename columns (numeric/boolean columns; utf8 not supported by buffer extract)
{:ok, renamed} = ExArrow.Batch.rename(batch, %{"id" => "user_id"})

# Take rows: first N, or a list of zero-based indices
{:ok, first10} = ExArrow.Batch.take(batch, 10)
{:ok, picked}  = ExArrow.Batch.take(batch, [0, 2, 4])

# Filter rows with a boolean predicate batch
{:ok, mask}     = ExArrow.Compute.project(batch, ["is_active"])
{:ok, filtered} = ExArrow.Batch.filter(batch, mask)
```

---

## Streaming pipelines

`ExArrow.Pipeline` is a thin, lazy abstraction for transforming and
sinking Arrow streams.  Pipelines compose with `|>/2` and short-circuit on
error.

```elixir
ExArrow.Stream.from_flight_sql(client, "SELECT * FROM events")
|> ExArrow.Pipeline.map_batches(fn batch ->
  {:ok, slim} = ExArrow.Batch.select(batch, ["id", "ts", "amount"])
  slim
end)
|> ExArrow.Pipeline.each_batch(fn batch ->
  IO.puts("processed #{ExArrow.RecordBatch.num_rows(batch)} rows")
end)
|> ExArrow.Pipeline.write_parquet("/data/events_slim.parquet")
```

Sinks: `write_parquet/2`, `write_flight/3`, `write_dataframe/1`.

### Sinks

`ExArrow.Sink.*` modules provide the same destinations with a stream-or-batch
input shape, for use outside the Pipeline DSL:

```elixir
:ok = ExArrow.Sink.Parquet.write(stream, "/data/out.parquet")
:ok = ExArrow.Sink.Flight.write(stream, client, descriptor: {:cmd, "events"})
{:ok, df} = ExArrow.Sink.DataFrame.write(stream)
```

### Flow, GenStage, Broadway

For parallel or demand-driven workloads, drop down to the integration layers:

- **`ExArrow.Flow`** — parallel batch processing via the Flow library.
- **`ExArrow.GenStage.{Parquet,Flight,ADBC}Producer`** — demand-driven
  producers with backpressure for long-running pipelines.
- **`ExArrow.Broadway`** — ingestion pipelines with `BatchBuilder`,
  `ParquetSink`, and `FlightSink`.

See the [guides](#documentation) for full examples and tradeoffs.

---

## Using ExArrow with Explorer

[Explorer](https://hex.pm/packages/explorer) handles in-memory analysis.
ExArrow handles streaming and transport. Add `{:explorer, "~> 0.11"}` to your
`mix.exs` to enable the bridge.

**Top-level interchange (v0.6+):**

```elixir
df = Explorer.DataFrame.new(x: [1, 2, 3], y: ["a", "b", "c"])

# DataFrame → Arrow
{:ok, batch} = ExArrow.from_dataframe(df)

# Arrow → DataFrame
{:ok, df2} = ExArrow.to_dataframe(batch)

# DataFrame-oriented API
{:ok, batch} = ExArrow.DataFrame.to_arrow(df)
{:ok, df3}   = ExArrow.DataFrame.from_arrow(batch)
```

**ExArrow → Explorer** (one call, no boilerplate):

```elixir
{:ok, stream} = ExArrow.IPC.Reader.from_file("/data/source.arrow")
{:ok, df}     = ExArrow.Explorer.from_stream(stream)
Explorer.DataFrame.filter(df, score > 0.9)
```

**Single batch → DataFrame:**

```elixir
batch = ExArrow.Stream.next(stream)
{:ok, df} = ExArrow.Explorer.from_record_batch(batch)
```

**Explorer → ExArrow** (e.g. to write to Parquet or send via Flight):

```elixir
df = Explorer.DataFrame.new(x: [1, 2, 3], y: ["a", "b", "c"])
{:ok, stream} = ExArrow.Explorer.to_stream(df)
:ok = ExArrow.Parquet.Writer.to_file("/out/result.parquet",
        ExArrow.Stream.schema(stream) |> elem(1),
        ExArrow.Stream.to_list(stream))
```

**Manual path** (IPC round-trip, still works):

```elixir
binary = Explorer.DataFrame.dump_ipc_stream!(df)
{:ok, stream} = ExArrow.IPC.Reader.from_binary(binary)
batch = ExArrow.Stream.next(stream)
```

---

## Using ExArrow with Nx

[Nx](https://hex.pm/packages/nx) provides numerical computing and tensor
operations.  ExArrow bridges Arrow columns to Nx tensors by sharing raw byte
buffers — no list materialisation occurs.

Add `{:nx, "~> 0.9"}` to your `mix.exs` to enable this module.

**Top-level interchange (v0.6+):**

```elixir
# Tensor → Arrow
tensor = Nx.tensor([1, 2, 3], type: {:s, 64})
{:ok, batch} = ExArrow.from_nx(tensor)

# Arrow → Tensor
{:ok, recovered} = ExArrow.to_nx(batch)
Nx.to_list(recovered)  #=> [1, 2, 3]

# Rank-2 tensor → multi-column batch → rank-2 tensor
matrix = Nx.tensor([[1, 2, 3], [4, 5, 6]], type: {:s, 64})
{:ok, batch} = ExArrow.from_nx(matrix)
{:ok, back}  = ExArrow.to_nx(batch)
Nx.shape(back)  #=> {2, 3}

# Boolean tensor
flags = Nx.tensor([1, 0, 1], type: {:u, 8})
{:ok, batch} = ExArrow.from_nx(flags, as: :boolean)
```

**Column to tensor:**

```elixir
{:ok, tensor} = ExArrow.Nx.column_to_tensor(batch, "price")
mean = tensor |> Nx.mean() |> Nx.to_number()
```

**All numeric columns to a map of tensors:**

```elixir
{:ok, tensors} = ExArrow.Nx.to_tensors(batch)
sorted_scores = tensors["score"] |> Nx.sort()
```

**Tensor back to a single-column RecordBatch:**

```elixir
weights = Nx.tensor([0.1, 0.2, 0.7], type: {:f, 64})
{:ok, batch} = ExArrow.Nx.from_tensor(weights, "weights")
```

Non-numeric columns (strings, timestamps) are silently skipped by
`to_tensors/1`. Unsupported Nx dtypes (e.g. `:bf16`) return `{:error, ...}`.
Boolean columns are extracted as `{:u, 8}` tensors.

---

## Use case examples

### Ingest IPC from HTTP or Kafka and write to file

```elixir
ipc_bytes = get_arrow_stream_from_http_or_kafka()
{:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bytes)
{:ok, schema} = ExArrow.Stream.schema(stream)
batches =
  Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
  |> Enum.take_while(fn nil -> false; {:error, _} -> false; _ -> true end)
:ok = ExArrow.IPC.Writer.to_file("/data/ingested.arrow", schema, batches)
```

### Query a database and forward via Flight

```elixir
{:ok, db}     = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: "file:report.db")
{:ok, conn}   = ExArrow.ADBC.Connection.open(db)
{:ok, stmt}   = ExArrow.ADBC.Statement.new(conn, "SELECT * FROM sales WHERE year = 2024")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
{:ok, schema} = ExArrow.Stream.schema(stream)
batches =
  Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
  |> Enum.take_while(fn nil -> false; {:error, _} -> false; _ -> true end)

{:ok, client} = ExArrow.Flight.Client.connect("flight.example.com", 32010, [])
:ok = ExArrow.Flight.Client.do_put(client, schema, batches)
```

### Connect to Dremio, InfluxDB IOx, or a custom Flight service

```elixir
{:ok, client}  = ExArrow.Flight.Client.connect("dremio.example.com", 32010, connect_timeout_ms: 5_000)
{:ok, flights} = ExArrow.Flight.Client.list_flights(client, <<>>)
{:ok, stream}  = ExArrow.Flight.Client.do_get(client, ticket_from_service)
batch = ExArrow.Stream.next(stream)
```

### Interchange with Python or R

```elixir
# Read a file written by PyArrow or Pandas
{:ok, file}   = ExArrow.IPC.File.from_file("/data/from_python.arrow")
{:ok, schema} = ExArrow.IPC.File.schema(file)
n = ExArrow.IPC.File.batch_count(file)
for i <- 0..(n - 1) do
  {:ok, batch} = ExArrow.IPC.File.get_batch(file, i)
  # process batch
end

# Write for Python, R, or DuckDB
:ok = ExArrow.IPC.Writer.to_file("/data/for_python.arrow", schema, batches)
```

### End-to-end: ADBC to Flight

```elixir
{:ok, db}     = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_postgresql",
                  uri: "postgresql://localhost/mydb")
{:ok, conn}   = ExArrow.ADBC.Connection.open(db)
{:ok, stmt}   = ExArrow.ADBC.Statement.new(conn, "SELECT * FROM sensor_readings")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
{:ok, schema} = ExArrow.Stream.schema(stream)
batches =
  Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
  |> Enum.take_while(fn nil -> false; {:error, _} -> false; _ -> true end)

{:ok, client} = ExArrow.Flight.Client.connect("flight.internal", 32010, [])
:ok = ExArrow.Flight.Client.do_put(client, schema, batches)
```

---

## Benchmarks

ExArrow ships a Benchee-based benchmark suite in `bench/` that quantifies the
zero-copy streaming advantage over row-oriented alternatives.

### Running locally

Benchee is a `:dev`-only dependency; `MIX_ENV=dev` is required.

```bash
MIX_ENV=dev mix run bench/ipc_read_bench.exs   # single suite
MIX_ENV=dev mix run bench/run_all.exs           # all suites
MIX_ENV=dev mix bench                           # convenience alias
```

HTML reports are written to `bench/output/` (gitignored).

### Suites


| File                       | What it measures                                                               |
| -------------------------- | ------------------------------------------------------------------------------ |
| `ipc_read_bench.exs`       | Stream handle vs materialise — BEAM memory saved by keeping data native        |
| `ipc_write_bench.exs`      | IPC serialisation vs `:erlang.term_to_binary` — columnar vs row-oriented write |
| `flight_bench.exs`         | Flight doput / doget / roundtrip latency with in-process server                |
| `adbc_bench.exs`           | Stream handle vs schema peek vs full collect                                   |
| `pipeline_bench.exs`       | End-to-end: IPC file on disk to Flight doput without materialising in BEAM     |
| `explorer_arrow_bench.exs` | Explorer <-> Arrow interchange at 1K/100K/1M rows                             |
| `nx_arrow_bench.exs`       | Nx <-> Arrow interchange at 1K/100K/1M rows (rank-1 and rank-2)              |
| `v070_stream_flow_pipeline_bench.exs` | Parquet/IPC stream drains, Flow execution, Pipeline map_batches + write_parquet at 1K/100K/1M rows |
| `v070_record_batch_vs_maps_bench.exs` | Arrow `RecordBatch` vs `list(map())` for build, transform, and drain at 1K/100K/1M rows |
| `parquet_pushdown_bench.exs` | Pushdown filter vs full read + project (v0.8.0 rough timing helper) |
| `dataset_scan_bench.exs` | Dataset pushdown ladder: full / project / partition / row-group / residual (v0.9.0) |


### Published results

Results from every push to `main` are published at:
**[https://thanos.github.io/ex_arrow/dev/bench/](https://thanos.github.io/ex_arrow/dev/bench/)**

The CI workflow posts a PR alert comment when any scenario regresses more than
20% relative to the previous baseline.

---

## Documentation

- [Arrow for Elixir Developers](guides/01_arrow_for_elixir_developers.md) — hierarchy, types, memory model
- [Explorer Integration](guides/02_explorer_integration.md) — from_dataframe, to_dataframe, type mapping, limitations
- [Nx Integration](guides/03_nx_integration.md) — from_nx, to_nx, boolean tensors, rank-2
- [Arrow Ecosystem](guides/04_arrow_ecosystem.md) — how ExArrow complements Explorer, Nx, ADBC, Flight, Parquet, ExZarr
- [Arrow Pipelines Overview](guides/05_arrow_pipelines_overview.md) — orientation to the pipeline modules
- [Arrow Streams](guides/06_arrow_streams.md) — the streaming abstraction, constructors, consumption patterns
- [Arrow and Flow](guides/07_arrow_and_flow.md) — parallel batch processing with `ExArrow.Flow`
- [Arrow and GenStage](guides/08_arrow_and_genstage.md) — demand-driven producers with backpressure
- [Arrow and Broadway](guides/09_arrow_and_broadway.md) — ingestion pipelines with `BatchBuilder` and sinks
- [Arrow Pipeline Patterns](guides/10_arrow_pipeline_patterns.md) — composable `ExArrow.Pipeline` transforms and sinks
- [Datasets and Scanners](guides/11_datasets.md) — Dataset, Fragment, Hive partitioning, Scanner pushdown ladder
- [Memory model](docs/memory_model.md) — handles, copying rules, NIF scheduling
- [IPC guide](docs/ipc_guide.md) — stream vs file, types, limitations
- [Parquet guide](docs/parquet_guide.md) — read/write Parquet, streaming, comparison with IPC
- [Compute guide](docs/compute_guide.md) — filter, project, sort, chaining kernels
- [Flight guide](docs/flight_guide.md) — server, client, timeouts, security
- [Flight SQL guide](docs/flight_sql_guide.md) — connection, TLS, queries, DML, prepared statements, metadata, Explorer/Nx, Mox testing
- [ADBC guide](docs/adbc_guide.md) — driver loading, metadata, binding
- [Benchmarks guide](docs/benchmarks.md) — suites, CI publishing, interpreting results

API reference: `mix docs` or [ex-arrow.hexdocs.pm](https://ex-arrow.hexdocs.pm).

---

## Development

### How to build the project

Use this flow for a clean local build:

```bash
mix clean
mix deps.get
mix compile
```

ExArrow uses precompiled NIFs by default. To force a local Rust build of the
NIF (recommended when developing the native code), run:

```bash
mix clean
EX_ARROW_BUILD=1 mix compile
```

### How to test the project

Run the test suite:

```bash
mix test
```

If you see many failures with `:nif_not_loaded`, stale artifacts are usually the
cause. Rebuild from clean:

```bash
mix clean
EX_ARROW_BUILD=1 mix compile
mix test
```

Optional ADBC integration tests require installed drivers/environment setup.
If those are not available locally, skip ADBC-tagged tests:

```bash
mix test --exclude adbc --exclude adbc_package --exclude adbc_integration
```

Common contributor checks:

```bash
mix deps.get
EX_ARROW_BUILD=1 mix compile    # build NIF from source
mix test                         # exclude :adbc / :adbc_package tags if no drivers installed
mix docs                         # generate ExDoc
MIX_ENV=dev mix bench            # run benchmark suite
```

Local CI script (runs format, credo, dialyzer, tests, coverage, docs):

```bash
script/ci
```

---

## Roadmap

The items below represent the planned direction for ExArrow. Contributions are
welcome for any of them.

### Shipped (v0.2.0)

- **TLS for Arrow Flight** — one-way and mutual TLS on `Server.start_link/2`.
- **Multi-dataset Flight server** — datasets stored by ticket; `do_put` accepts a `:descriptor` option.
- **ADBC connection pool** — `ConnectionPool` and `DatabaseServer` backed by NimblePool.
- **Broader integration test matrix** — PostgreSQL 14/15/16 and DuckDB 1.1.3/1.2.0 tested in CI.

### Shipped (v0.3.0)

- **Arrow compute kernels** — `ExArrow.Compute.filter/2`, `project/2`, `sort/3`: filter, select columns, and sort record batches entirely in native Arrow buffers without materialising data into BEAM terms.
- **Parquet support** — `ExArrow.Parquet.Reader` and `ExArrow.Parquet.Writer`: read and write Parquet files and in-memory binaries via the Arrow Rust `parquet` crate; streaming API compatible with IPC and ADBC streams.
- **Explorer bridge module** — `ExArrow.Explorer`: direct conversion between `ExArrow.Stream` / `ExArrow.RecordBatch` and `Explorer.DataFrame` without writing manual IPC code. Add `{:explorer, "~> 0.11"}` to enable.
- **Nx bridge module** — `ExArrow.Nx`: convert Arrow columns to `Nx.Tensor` values and back by sharing raw byte buffers. No list materialisation. Add `{:nx, "~> 0.9"}` to enable.

### Shipped (v0.4.0)

- **`:adbc_package` supervised backend** — use the Elixir `adbc` packages
  (`Adbc.Database` / `Adbc.Connection`) under `ExArrow`’s supervision instead of
  loading a native ADBC driver via the NIF. Configure `config :ex_arrow, :adbc_package`,
  then `Database.open(:adbc_package)`; optional `NimblePool` when
  `adbc_package_pool_size > 1`. Requires `{:adbc, "~> 0.9"}` and
  `{:explorer, "~> 0.11"}` for result conversion.
- **Arrow C Data Interface** — `ExArrow.CDI`: export a RecordBatch to
  `FFI_ArrowArray` + `FFI_ArrowSchema` C structs and import them back.
  Pointer addresses are exposed for interop with any CDI-compatible runtime
  (Polars, DuckDB, etc.) running in the same process.  Provides the foundation
  for a future zero-copy Explorer bridge that bypasses IPC entirely.
- **Nx bridge — multi-column batch from tensors** — `ExArrow.Nx.from_tensors/1`
  builds a multi-column RecordBatch from a `%{col_name => Nx.Tensor}` map in a
  single NIF call, complementing the existing per-column `from_tensor/2`.
- **Parquet row-group streaming** — `ExArrow.Parquet.Reader.from_file/1` and
  `from_binary/1` now decode row groups **lazily** via `Stream.next/1` instead
  of eagerly loading the entire file, dramatically reducing peak memory for
  large Parquet files.

### Shipped (v0.5.0)

- **Arrow Flight SQL client** — `ExArrow.FlightSQL.Client`: connect to DuckDB,
  DataFusion, Dremio, InfluxDB v3, and any Arrow Flight SQL server.  Full query
  API: materialised (`query/2`), lazy streaming (`stream_query/2`), DML
  (`execute/2`), prepared statements (`prepare/2`), and metadata discovery
  (`get_tables/2`, `get_db_schemas/2`, `get_sql_info/1`).
- **`ExArrow.Stream` implements `Enumerable`** — all `Enum.*` / `Stream.*`
  functions work directly on any stream handle.  Early termination is safe.
- **Structured errors** — `ExArrow.FlightSQL.Error` with `:code` atom and
  `:grpc_status` integer, covering 11 error categories.
- **Mox-compatible `ClientBehaviour`** — full test isolation without a live server.
- **Explorer and Nx integration** — `Result.to_dataframe/1`, `Result.to_tensor/2`.

### Shipped (v0.6.0)

- **Top-level Explorer interchange** — `ExArrow.from_dataframe/1`,
  `to_dataframe/1`, and `ExArrow.DataFrame.from_arrow/1`, `to_arrow/1`.
- **Top-level Nx interchange** — `ExArrow.from_nx/1`, `to_nx/1` with rank-1
  and rank-2 support for u8, s64, f32, f64, and boolean.
- **`ExArrow.Schema.Mapper`** — single authority for Arrow <-> Explorer/Nx type
  mapping, extensible for future ExZarr and Dataset support.
- **Field nullability** — `ExArrow.Field` includes `nullable`; NIF returns the
  flag; Arrow-native schema round-trips preserve nullability. Explorer-based
  round-trips may report columns as nullable regardless of source data.
- **Boolean tensor support** — `from_nx/1` with `as: :boolean`; `column_to_tensor/2`
  and `to_tensors/1` handle Boolean columns.
- **RecordBatch and Table improvements** — `num_columns/1`, `column_names/1`,
  `Table.from_batches/1` replaces stub.
- **Benchee benchmarks** — Explorer <-> Arrow and Nx <-> Arrow at 1K/100K/1M.
- **Educational guides** — `guides/01..04` covering Arrow concepts, Explorer,
  Nx, and the ecosystem.
- **Property tests** — StreamData-based round-trip fidelity tests.

### Shipped (v0.6.1)

- **Prepared statement parameter binding** — `Statement.bind/2` binds an
  `ExArrow.RecordBatch` of parameters to a prepared statement.  `Statement.close/1`
  releases server-side resources (idempotent).  `Statement.parameter_schema/1`
  inspects expected column names and Arrow types before binding.
- **`RecordBatch.from_columns/4`** — creates a batch from column-oriented binary
  data (names, binaries, dtype strings, row count).  21 dtypes including
  timestamps, durations, utf8, and binary columns.

### Shipped (v0.7.0)

- **First-class streaming** — `ExArrow.Stream.from_parquet/1`,
  `from_ipc/1`, `from_flight/2`, `from_flight_sql/2`, `from_adbc/1,2`
  constructors with source tracking and telemetry.  The unit of streaming is
  the Arrow `RecordBatch`.
- **Batch operations** — `ExArrow.Batch`: `schema/1`, `select/2`, `drop/2`,
  `rename/2`, `take/2`, `filter/2`.  Lightweight, Arrow-native transforms.
- **Pipeline DSL** — `ExArrow.Pipeline`: `map_batches/2`, `each_batch/2`,
  `write_parquet/2`, `write_flight/3`, `write_dataframe/1`.  Lazy; composes
  with `|>/2`; errors short-circuit.
- **Flow integration** — `ExArrow.Flow.from_batches/1`, `map_batches/2`,
  `each_batch/2` for parallel batch processing.
- **GenStage integration** — `ExArrow.GenStage.ParquetProducer`,
  `FlightProducer`, `ADBCProducer` with demand-driven backpressure.
- **Broadway integration** — `ExArrow.Broadway.BatchBuilder`,
  `ParquetSink`, `FlightSink` for ingestion pipelines.
- **Pipeline sinks** — `ExArrow.Sink.Parquet`, `Flight`, `DataFrame`, `Nx`.
- **Telemetry** — `ExArrow.Telemetry` with events for every transport and
  pipeline operation.  Optional `:telemetry` dep.
- **Benchmarks** — stream/Flow/pipeline and RecordBatch vs `list(map())` at
  1K/100K/1M rows.
- **Educational guides** — `guides/06..10` covering streams, Flow, GenStage,
  Broadway, and pipeline patterns.

### Shipped (v0.8.0)

- **Parquet read pushdown** — `:columns`, `:row_groups`, `:filters` on
  `Stream.from_parquet/2` and `Parquet.Reader`; statistics pruning +
  `read_stats/1`.
- **Parquet write options** — `:compression`, `:row_group_size`, `:dictionary`.
- **`ExArrow.Parquet.Metadata`** — footer-only metadata (including encodings).
- **Multi-file streams** — `from_parquet_files/2`, `from_parquet_dir/2`,
  `Stream.close/1`.
- **Public IPC/RecordBatch helpers** — `IPC.File.write/3`, `RecordBatch.concat/1`.
- **Docs / CI** — Parquet Livebook, Mix.install smoke, Livebook pin checks;
  optional arrow-testing corpus (local / workflow_dispatch).

### Shipped (v0.9.0)

- **Dataset / Fragment / Hive discovery** — `Dataset.open/2` over Local or
  Memory filesystems; typed Hive partition values; schema from footer.
- **Scanner** — partition prune, Parquet pushdown, residual Expression filter;
  `:dataset` stream backend; exact `Scanner.stats/1`.
- **`ExArrow.Compute.Expression`** — builders, schema validate, pushable vs
  residual compile; `Compute.filter/2` residual NIF.
- **`RecordBatch.from_lists/1` / `from_map/1`** — list/map batch construction.
- **arrow-rs 59.3.0** — coordinated parquet / Flight / ADBC companion bumps.
- **Docs** — Datasets guide, Livebook 06, dataset scan bench.

### Longer-term

- **Streaming writes to Delta Lake** — sink for data pipeline nodes.
- **Windows aarch64 precompiled NIF** — once GitHub-hosted Windows arm64
  runners are generally available.

---

## FAQ

**When should I use ExArrow?**
Use ExArrow when you need to read or write Arrow IPC (stream or file), connect
to an Arrow Flight server (Dremio, InfluxDB IOx, custom), or run SQL via ADBC
and receive Arrow result streams. Good fit for data pipelines, ETL, and
interchange with systems that already speak Arrow.

**When should I not use ExArrow?**
Do not use it as a dataframe or query engine. For in-memory analysis, filtering,
grouping, and plotting, use Explorer. Do not use it as a replacement for Ecto
when you only need normal SQL results. For Parquet-only workflows with no
Flight/ADBC, consider Explorer's Parquet support first.

**Can I use ExArrow and Explorer together?**
Yes. Add `{:explorer, "~> 0.11"}` to your `mix.exs` and use `ExArrow.Explorer`
(v0.3+) for one-call conversion: `ExArrow.Explorer.from_stream/1`,
`from_record_batch/1`, `to_stream/1`. The bridge uses Arrow IPC internally;
you can also do the round-trip manually with `ExArrow.IPC.Writer.to_binary/2`
and `Explorer.DataFrame.load_ipc_stream!/1`.

**Why do I get a 404 or "couldn't fetch NIF" on compile?**
Precompiled NIFs are hosted on GitHub releases. If you are on an unsupported
platform or an unreleased version, the download fails. Set `EX_ARROW_BUILD=1`,
install Rust, and run `mix compile` to build from source.

**Is Arrow Flight over TLS supported?**
Yes, as of v0.2. Pass `tls: [cert_pem: ..., key_pem: ...]` to
`Server.start_link/2` for one-way TLS, or add `ca_cert_pem:` for mutual TLS.
The client automatically selects TLS for non-loopback hosts; use
`tls: [ca_cert_pem: pem]` for a custom CA.

**Which ADBC drivers are supported?**
Any ADBC driver that provides a shared library — for example
`adbc_driver_sqlite`, `adbc_driver_postgresql`, or the DuckDB ADBC driver. You
must install the driver and pass its path (`:driver_path`), or ensure the driver
manager can find it by name (`:driver_name`). Some drivers require extra options:
DuckDB expects `entrypoint: "duckdb_adbc_init"` and uses `path:` rather than
`uri:` for the database location. Metadata and binding support depend on the
individual driver.

---

## License

MIT. See [LICENSE](LICENSE) for details. Copyright (c) 2025 Thanos Vassilakis.
