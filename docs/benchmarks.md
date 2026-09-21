# Benchmarks

ExArrow ships a Benchee-based benchmark suite in `bench/` that highlights its
zero-copy streaming advantage over row-oriented alternatives.

## Running locally

Benchee and its formatters are declared as `:dev`-only dependencies, so
`MIX_ENV=dev` is required.  Set `EX_ARROW_BUILD=1` the first time to ensure
the NIF is compiled from source.

```bash
# Single suite
MIX_ENV=dev mix run bench/ipc_read_bench.exs

# All suites in sequence (HTML reports written to bench/output/)
MIX_ENV=dev mix run bench/run_all.exs

# Convenience alias defined in mix.exs
MIX_ENV=dev mix bench
```

After each run the console prints a full statistics table.  Three files are
also written per suite inside `bench/output/`:

| File pattern | Contents |
|---|---|
| `*.html` | Interactive Benchee chart — open in any browser |
| `*.json` | Raw numbers for scripting or CI upload |

## Benchmark suites

### IPC read (`bench/ipc_read_bench.exs`)

Compares two access patterns for reading Arrow IPC data:

- **stream\_handle** — open the stream and keep the opaque NIF reference.
  Column data stays in Rust memory; the BEAM holds one word.
- **materialise** — pull every record batch into BEAM as
  `ExArrow.RecordBatch` structs.  Shows the full cost when callers need
  random access to all batches.
- **from\_file** — same patterns but starting from a memory-mapped file
  rather than a pre-loaded binary.

The stream-handle path is the recommended pattern for forwarding pipelines
because downstream consumers (Flight `do_put`, ADBC `bind`) accept the
native reference directly.

### IPC write (`bench/ipc_write_bench.exs`)

Measures serialisation throughput for Arrow IPC output:

- **to\_binary** — write batches to an in-memory binary using the Arrow
  stream format.
- **to\_file** — write the same batches to a temp file (IPC file format).
- **term\_to\_binary** — baseline: Erlang's built-in serialiser on an
  equivalent row-oriented list of maps.

### Flight (`bench/flight_bench.exs`)

Measures Arrow Flight round-trip latency using a built-in in-process server
(no external process needed).  Scenarios:

- `do_put` — upload 10 record batches via the client.
- `do_get` — download a previously uploaded stream and collect all batches.
- `do_get` stream handle only — receive the stream reference without
  pulling batches into BEAM.
- Full `roundtrip` — `do_put` followed immediately by `do_get`.
- `list_flights` — metadata-only request; no data transfer.

Key insight: ExArrow Flight transfers Arrow buffers end-to-end without
converting to or from any BEAM binary term.  The BEAM process is never on
the hot path for column data.

### ADBC stream (`bench/adbc_bench.exs`)

Isolates the cost of the ExArrow ADBC streaming layer (independent of
database round-trip time):

- **open ipc stream** — create the native stream handle only.
- **schema peek** — read schema metadata without consuming any batches.
- **collect all batches** — pull every batch into BEAM; equivalent to what
  `Ecto.Repo.stream` does row-by-row but at the batch level.
- **Enum.map baseline** — pure-BEAM list construction for reference.

ADBC drivers (SQLite, PostgreSQL, etc.) are optional dependencies and are
not guaranteed to be present.  The IPC stand-in measures identical streaming
overhead; only the database round-trip is excluded.

### End-to-end pipeline (`bench/pipeline_bench.exs`)

Benchmarks the full zero-copy pipeline:

```
IPC file on disk  →  ExArrow stream handle  →  Flight do_put
```

Scenarios:

- **file → Flight** — read from a file and upload via Flight without
  materialising column data in the BEAM heap.
- **binary → Flight** — same starting from a pre-loaded binary.
- **materialise → Flight** — read the file, collect every batch into BEAM
  first, then upload.  Shows the overhead of materialisation.

### v0.7.0 stream / Flow / pipeline (`bench/v070_stream_flow_pipeline_bench.exs`)

Measures Parquet and IPC stream drains, Flow execution, and Pipeline
`map_batches` + `write_parquet` at 1K / 100K / 1M rows.  Compares the cost
of draining a stream through `ExArrow.Stream.to_list/1` versus flowing the
same stream through `ExArrow.Flow.from_batches/1` and writing through
`ExArrow.Pipeline.write_parquet/2`.

### v0.7.0 RecordBatch vs list(map()) (`bench/v070_record_batch_vs_maps_bench.exs`)

Compares Arrow `RecordBatch` against `list(map())` for build, transform
(column select), and drain (sum a column) at 1K / 100K / 1M rows.  Quantifies
the cost of going through row maps versus staying in native Arrow memory.

### v0.8.0 Parquet pushdown (`bench/parquet_pushdown_bench.exs`)

A standalone rough-timing helper (uses `:timer.tc/1`, not Benchee) that
compares reading a 100K-row Parquet file with a pushdown filter against a
full read plus post-read projection (no scalar-predicate kernel exists yet
for an equivalent post-filter).  Run it directly:

```bash
MIX_ENV=dev mix run bench/parquet_pushdown_bench.exs
```

It prints elapsed milliseconds and the row-group selection stats after open.
Not part of `bench/run_all.exs` (no HTML/JSON output).

### v0.9.0 Dataset scan ladder (`bench/dataset_scan_bench.exs`)

Standalone `:timer.tc/1` helper over a synthetic Hive layout (8 partitions,
1.2M rows). Labels state exactly what each branch measures: full scan,
projection-only, partition-pruned, row-group-pruned, and expression-residual.
Not part of `bench/run_all.exs` (writes under `/tmp`, longer runtime).

```bash
MIX_ENV=dev mix run bench/dataset_scan_bench.exs
```

## Published results

Benchmark results from every push to `main` are stored in the `gh-pages`
branch and displayed as a trend chart at:

**https://animalogica.github.io/ex_arrow/dev/bench/**

The GitHub Actions workflow (`.github/workflows/benchmarks.yml`) also:

- Posts a PR comment when any scenario regresses more than 20% relative to
  the previous baseline.
- Uploads the HTML reports as a workflow artifact (7-day retention).

## GitHub Actions workflow

The workflow is defined in `.github/workflows/benchmarks.yml`.  It:

1. Checks out the repository and installs Elixir, OTP, and Rust.
2. Restores the Cargo and Mix build caches.
3. Runs each benchmark suite with `MIX_ENV=dev mix run bench/<suite>.exs`.
4. Merges the individual JSON outputs into `bench/output/merged.json`.
5. Calls `benchmark-action/github-action-benchmark` to push the results to
   the `gh-pages` branch and, optionally, post an alert comment on the PR.

To trigger it manually use the **Run workflow** button in the GitHub Actions
tab (`workflow_dispatch`).
