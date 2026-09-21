# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-09-13

### Added

- **`ExArrow.Dataset` / `ExArrow.Dataset.Fragment`**: discover Parquet or IPC
  trees from a directory, single file, glob, or explicit path list via
  `Dataset.open/2`. Hive partitioning parses typed keys from path segments;
  each fragment carries `path`, `format`, `size`, and `partition_values`.
  Schema is resolved from the first fragment footer without decoding pages.
- **`ExArrow.FileSystem`**: behaviour with `Local` (OS) and `Memory`
  (in-process tree) backends for list/glob/exists used by Dataset discovery.
- **`ExArrow.Scanner`**: lazy scan plan from `Dataset.scanner/2` with
  `:columns`, `:filter`, and `:batch_size`. `Scanner.to_stream/1` yields an
  Agent-backed `:dataset` stream; `Scanner.stats/1` reports exact fragment
  and row-group prune counts (preview before IO, or live after scan). Closed
  streams return `{:error, "stream is closed"}` instead of exiting.
- **`ExArrow.Compute.Expression`**: analyzable filter AST with `field/1`,
  `scalar/1`, comparisons, `and_/2`, `or_/2`, `not_/1`, plus `validate/2`,
  `to_string/1`, and `to_parquet_filters/1` (pushable subset vs residual).
  Temporal scalars (`Date`, `NaiveDateTime`, `DateTime`) are supported for
  residual evaluation.
- **Residual `Compute.filter/2`**: new NIF evaluates an Expression to a
  boolean mask and filters a `RecordBatch` (also via `Batch.filter/2`).
  Integer→float casts reject values that are not exactly representable.
- **`RecordBatch.from_lists/1` and `from_map/1`**: ergonomic constructors
  for non-nullable columnar batches from Elixir lists/maps.
- **Docs / fixtures**: Datasets guide (`guides/11_datasets.md`), Livebook
  `06_datasets.livemd`, PyArrow Hive fixture with exact Scanner prune
  stats, and `bench/dataset_scan_bench.exs` (labeled pushdown ladder).

### Changed

- **Native stack**: arrow-rs / parquet / arrow-flight **59.3.0** (from 56);
  tonic **0.14**; adbc_core / adbc_driver_manager **0.24**.
- **Parquet `:filters`**: continues to accept the v0.8.0 tuple AST; an
  `Expression` is accepted only when fully Parquet-pushable (use Scanner
  when a residual remains).
- Cross-fragment Scanner schema checks compare **name and type** (not names
  alone). Dataset fragment list building uses linear prepend/reverse
  accumulation.

## [0.8.0] - 2026-08-21

### Added

- **Parquet read pushdown**: `ExArrow.Stream.from_parquet/2` and
  `Parquet.Reader.from_file/2` / `from_binary/2` accept `:columns`,
  `:row_groups`, and `:filters` (predicate AST with statistics pruning).
  `Parquet.Reader.read_stats/1` reports selected vs skipped row groups.
- **Parquet write options**: `:compression` (`:snappy`, `:zstd`,
  `{:zstd, level}`, `:lz4`, `:gzip`, `:none`, alias `:uncompressed`),
  `:row_group_size`, and `:dictionary` on `Writer.to_file/4` and
  `to_binary/3`.
- **`ExArrow.Parquet.Metadata`**: footer-only metadata via `from_file/1` and
  `from_binary/1` (row groups, column stats, key-value metadata).
- **Multi-file Parquet streams**: `Stream.from_parquet_files/2` and
  `from_parquet_dir/2` — lazy per-file open with schema checking;
  `Stream.close/1` releases the backing Agent when abandoning early.
- **`ExArrow.IPC.File.write/3`**: public IPC file-format writer (wraps existing NIF).
- **`ExArrow.RecordBatch.concat/1`**: public batch concatenation (wraps existing NIF).
- **CI Mix.install optional-dep matrix** and a Parquet Livebook with
  PyArrow-equivalent examples. Optional apache/arrow-testing fixtures are
  local-only by default (`script/fetch_arrow_testing.sh` +
  `mix test --include arrow_testing`); an optional `workflow_dispatch`
  CI job can run the same suite without gating PRs.

### Changed

- Enabled Parquet compression codecs (`snap`, `zstd`, `lz4`, `gzip`) in the
  native crate so write options work end-to-end. Includes a DuckDB-generated
  ZSTD fixture and regression test for third-party compressed reads
  (thanks [@mindreframer](https://github.com/mindreframer) —
  [#243](https://github.com/AnimaLogica/ex_arrow/pull/243)).

## [0.7.2] - 2026-07-08

### Fixed

- **`ExArrow.GenStage.*Producer` without `:gen_stage`**: the 0.7.1 module-attribute
  guard still expanded `use GenStage` in some compile contexts (e.g. `Mix.install`
  without `{:gen_stage, ...}` in deps, or stale cached builds). Producers are now
  wrapped in a file-level `if Code.ensure_loaded?(GenStage)` block (same pattern
  as `AdbcPackagePool`), so `ex_arrow` compiles when GenStage is absent.

## [0.7.1] - 2026-06-29

### Fixed

- **`ExArrow.Telemetry.span/3` compile error without `:telemetry`**: the
  fallback branch (when `:telemetry` is not installed) used `fun()` instead of
  `fun.()` — a compile error that prevented `ex_arrow` from compiling at all
  without the optional `:telemetry` dependency.
- **`ExArrow.GenStage.*Producer` compile error without `:gen_stage`**: `use
  GenStage` (a macro) was inside `if Code.ensure_loaded?(GenStage) do`, but
  bare `if` evaluates both branches at compile time, so the macro expanded
  even when GenStage was absent. Fixed by using a module attribute
  (`@gen_stage_available`) so the branch is skipped at compile time.
- **`ExArrow.Telemetry.span/3` `@spec`**: removed `when result: term()` from
  inside `if/else` blocks where it could be misparsed; replaced with
  `term()` directly.

### Changed

- **Livebook setup cells**: all notebooks (`00`–`04`) now clear
  `_build/dev/lib/ex_arrow/ebin/` before `Mix.install` when using a local
  path source, forcing a fresh compile that detects optional deps. The
  quickstart notebooks also include the full set of v0.7.0 optional deps
  (`:nx`, `:telemetry`, `:flow`, `:gen_stage`, `:broadway`) so all
  features are available out of the box.

## [0.7.0] - 2026-06-29

### Added — Arrow-native streaming and pipeline infrastructure

ExArrow v0.7.0 transforms the library from a transport and interoperability
layer into the foundation for Arrow-native data pipelines on the BEAM.  The
central architectural principle is: **operate on Arrow RecordBatch values** —
not `list(map())`, not `Explorer.DataFrame`, not `Nx.Tensor`.  Explorer and Nx
remain downstream consumers; ExArrow is the Arrow layer.

#### Milestone 1 — First-class streaming (`ExArrow.Stream`)

- `ExArrow.Stream.from_parquet/1`, `from_parquet_binary/1`
- `ExArrow.Stream.from_ipc/1`, `from_ipc_file/1`
- `ExArrow.Stream.from_flight/2`
- `ExArrow.Stream.from_flight_sql/2`
- `ExArrow.Stream.from_adbc/1` and `from_adbc/2`
- `ExArrow.Stream.source/1` returns the origin metadata attached by the
  constructor (forwarded to telemetry as `:source`).
- All constructors return `{:ok, stream} | {:error, reason}` and compose with
  `|>/2` into `ExArrow.Pipeline` and `ExArrow.Flow`.

#### Milestone 2 — Batch operations (`ExArrow.Batch`)

- `ExArrow.Batch.schema/1`, `select/2`, `drop/2`, `rename/2`, `take/2`,
  `filter/2`.
- `select/2`, `drop/2`, `take/2`, and `filter/2` work for all Arrow types
  ExArrow supports (delegate to the native compute kernels).
- `rename/2` rebuilds a batch from raw column buffers and supports the
  fixed-width numeric and boolean types.
- `take/2` accepts an integer (first N rows) or a list of zero-based indices.

#### Milestone 3 — Flow integration (`ExArrow.Flow`)

- `ExArrow.Flow.from_batches/1` wraps an `ExArrow.Stream` in a `Flow` of
  `ExArrow.RecordBatch` values.
- `ExArrow.Flow.map_batches/2` and `each_batch/2` emit
  `[:ex_arrow, :pipeline, :batch]` telemetry per batch.
- All standard `Flow` combinators (`map`, `flat_map`, `partition`, `reduce`)
  work on the result.

#### Milestone 4 — GenStage integration (`ExArrow.GenStage`)

- `ExArrow.GenStage.ParquetProducer`, `FlightProducer`, `ADBCProducer`.
- Demand-driven streaming with proper backpressure and clean shutdown.
- Shared `ExArrow.GenStage.dispatch/2` and `terminate/1` helpers.
- Works with producer, consumer, and producer-consumer wiring patterns.

#### Milestone 5 — Broadway integration (`ExArrow.Broadway`)

- `ExArrow.Broadway.BatchBuilder.from_messages/1` assembles
  `ExArrow.RecordBatch` values from Broadway messages.
- `ExArrow.Broadway.ParquetSink.write/3` and `FlightSink.write/4` sink
  assembled batches to Parquet files and Flight servers.
- Configurable batch sizing and flush intervals via the Broadway batcher
  configuration.

#### Milestone 6 — Telemetry (`ExArrow.Telemetry`)

- Events: `[:ex_arrow, :flight, :query]`, `[:ex_arrow, :flight_sql, :query]`,
  `[:ex_arrow, :parquet, :read]`, `[:ex_arrow, :parquet, :write]`,
  `[:ex_arrow, :stream, :batch]`, `[:ex_arrow, :pipeline, :batch]`.
- Measurements: `rows`, `columns`, `bytes`, `duration`, `batch_count`.
- Metadata: `source`, `destination`, `schema`, `driver`.
- `ExArrow.Telemetry.execute/3` and `span/3` degrade to no-ops when the
  `:telemetry` dependency is absent.

#### Milestone 7 — Pipeline sinks

- `ExArrow.Sink.Parquet.write/2`
- `ExArrow.Sink.Flight.write/3`
- `ExArrow.Sink.DataFrame.write/1`
- `ExArrow.Sink.Nx.write/1`

#### Milestone 8 — Pipeline DSL (`ExArrow.Pipeline`)

- `ExArrow.Pipeline.map_batches/2`, `each_batch/2`, `write_parquet/2`,
  `write_flight/3`, `write_dataframe/1`.
- Thin, lazy abstraction over `ExArrow.Stream` with `{:ok, pipeline} |
  {:error, reason}` threading; errors short-circuit through every stage.

#### Milestone 9 — Benchmarks

- `bench/v070_stream_flow_pipeline_bench.exs` measures Parquet/IPC stream
  drains, Flow execution, and Pipeline `map_batches` + `write_parquet` at
  1K / 100K / 1M rows.
- `bench/v070_record_batch_vs_maps_bench.exs` compares Arrow `RecordBatch`
  against `list(map())` for build, transform (select), and drain (sum) at
  the same row counts.

#### Milestone 10 — Educational material

- `guides/06_arrow_streams.md`
- `guides/07_arrow_and_flow.md`
- `guides/08_arrow_and_genstage.md`
- `guides/09_arrow_and_broadway.md`
- `guides/10_arrow_pipeline_patterns.md`

### Changed

- `mix.exs`: version bumped to `0.7.0`; added optional dependencies on
  `:telemetry`, `:flow`, `:gen_stage`, and `:broadway`; `docs/0` extras and
  `groups_for_modules` updated to include the new modules.
- `ExArrow.Stream` now carries a `source` field and emits telemetry from
  `next/1`; the struct is backward-compatible (the new field defaults to
  `nil`).

### Testing

- 825 tests, 16 properties, 0 failures (45 excluded integration tests).
- 89.9% coverage (target: >= 85%).
- `mix format`, `mix credo --strict`, `mix dialyzer`, `mix sobelow`,
  `mix docs --warnings-as-errors` all pass.

## [0.6.3] - 2026-06-16

### Fixed

- **`mix compile` in dev/test**: `ExArrow.Native` no longer passes `force_build: false`
  to RustlerPrecompiled when `EX_ARROW_BUILD` is unset, which blocked the
  `config :rustler_precompiled, :force_build, ex_arrow: true` setting in
  `config/config.exs` and caused checksum download failures for local checkouts.
- **`Mix.install` path dependencies**: when not in dev/test, omit explicit
  `force_build` so `config :rustler_precompiled, :force_build, ex_arrow: true`
  in the install config can take effect (`Mix.install` compiles path deps as
  `:prod`).
- **Compile warning** when `nimble_pool` is absent: `AdbcPackageManager` resolves
  `AdbcPackagePool` at runtime via `apply/3` instead of a compile-time call.

### Changed

- **Livebooks** (`00`–`04`): unified setup cell (Hex release by default; auto-detect
  local checkout when opened from `livebook/` in the repo).  ADBC notebooks use
  the `:adbc_package` backend so SQLite works without a native `.dylib`.
  Flight tutorial fixes `Server.port/1` to match `{:ok, port}`.  ADBC setup cells
  call `Adbc.download_driver!/1` before opening databases.

## [0.6.2] - 2026-06-11

### Changed

- **Documentation**: updated Flight SQL guide, README, and module docs for
  prepared statement parameter binding, `close/1`, `parameter_schema/1`,
  and `RecordBatch.from_columns/4`.  Removed stale "not supported in v0.5.0"
  references.
- **Documentation**: replaced em-dashes with simpler punctuation across Elixir
  and Rust source, removed marketing language, varied repetitive return-value
  patterns, replaced decorative section dividers with plain comments, reordered
  prepared-statement NIFs in lifecycle order (prepare, bind, parameter_schema,
  execute, execute_update, close).
- **CI**: fixed `dtolnay/rust-toolchain@v1` in publish workflow (requires
  `toolchain` input); switched to `@stable`.  Added `script/check_version` to
  git (was missing from tracked files).
- **Minimum Rust `arrow-flight` crate version: 56**: Flight SQL prepared
  statement support uses `PreparedStatement::set_parameters`, `close`, and
  `parameter_schema` APIs available from `arrow-flight` v56.  Earlier crate
  versions are missing these methods.  `Cargo.toml` pins `arrow-flight = "56"`.
- **`Statement` struct is opaque**: the `closed` field from earlier
  development builds has been removed.  Closed-state is now tracked inside
  the NIF resource (`Mutex<Option<PreparedStatement>>`).  Code that pattern-
  matched on `%Statement{closed: _}` must be updated to treat `Statement` as
  an opaque handle and use `close/1` / `bind/2` / `execute/1` for lifecycle
  queries.

## [0.6.1] - 2026-06-11

### Added

- **Flight SQL prepared statement parameter binding**:
  `ExArrow.FlightSQL.Statement.bind/2` binds an `ExArrow.RecordBatch` of
  parameters to a prepared statement before execution.  Returns `:ok` or
  `{:error, %Error{}}`.
- **`ExArrow.FlightSQL.Statement.close/1`**: closes a prepared
  statement and releases server-side resources via
  `ActionClosePreparedStatement`.  Idempotent: calling `close/1` on an
  already-closed statement returns `:ok`.  Closed-state is tracked inside
  the underlying NIF resource; subsequent calls to `bind/2`, `execute/1`,
  `execute_update/1`, or `parameter_schema/1` return
  `{:error, %Error{code: :protocol_error}}`.
- **`ExArrow.FlightSQL.Statement.parameter_schema/1`**: returns the parameter
  schema of a prepared statement, enabling callers to inspect expected column
  names and Arrow types before binding.
- **`ExArrow.RecordBatch.from_columns/4`**: creates a `RecordBatch` from
  column-oriented binary data (names, binaries, dtype strings, row count).
  Returns `{:ok, t()} | {:error, String.t()}`.  Constructor for
  building parameter batches.  Supported dtypes:
  - Signed integers: `"s8"`, `"s16"`, `"s32"`, `"s64"`
  - Unsigned integers: `"u8"`, `"u16"`, `"u32"`, `"u64"`
  - Floats: `"f32"`, `"f64"`
  - Boolean: `"bool"`
  - Date/time: `"date32"`, `"date64"`, `"timestamp_seconds"`,
    `"timestamp_millis"`, `"timestamp_micros"`, `"timestamp_nanos"`,
    `"duration_seconds"`, `"duration_millis"`, `"duration_micros"`,
    `"duration_nanos"`
  - Variable-length: `"utf8"`, `"large_utf8"`, `"binary"`, `"large_binary"`
    (length-prefixed records, see `ExArrow.RecordBatch` moduledoc for the
    wire format)
- **Rust NIF: `flight_sql_prepared_bind`**: binds a `RecordBatch` to a
  prepared statement via `PreparedStatement::set_parameters`.
- **Rust NIF: `flight_sql_prepared_close`**: closes a prepared statement via
  `PreparedStatement::close`, consuming the statement handle.  The
  `FlightSqlPreparedStatementResource` stores `Mutex<Option<PreparedStatement>>`
  to support clean ownership transfer and idempotent close.
- **Rust NIF: `flight_sql_prepared_parameter_schema`**: returns the parameter
  schema from a prepared statement.

### Changed

- **`FlightSqlPreparedStatementResource.stmt`** changed from
  `Mutex<PreparedStatement<Channel>>` to
  `Mutex<Option<PreparedStatement<Channel>>>` to support `close/1` that
  consumes the statement handle.  Closed-state is detected by checking the
  inner `Option`; all prepared-statement NIFs return
  `{:error, {:protocol_error, 0, "statement is closed"}}` when called on a
  closed handle.
- **`Client.prepare/2` documentation** updated to reflect parameter binding
  support and `close/1` lifecycle.
- **Minimum Rust `arrow-flight` crate version: 56**: Flight SQL prepared
  statement support uses `PreparedStatement::set_parameters`, `close`, and
  `parameter_schema` APIs available from `arrow-flight` v56.  Earlier crate
  versions are missing these methods.  `Cargo.toml` pins `arrow-flight = "56"`.
- **`Statement` struct is opaque**: the `closed` field from earlier
  development builds has been removed.  Closed-state is now tracked inside
  the NIF resource (`Mutex<Option<PreparedStatement>>`).  Code that pattern-
  matched on `%Statement{closed: _}` must be updated to treat `Statement` as
  an opaque handle and use `close/1` / `bind/2` / `execute/1` for lifecycle
  queries.

### Fixed

- CI: Removed broken Dialyzer PLT cache that produced "Old PLT file" errors
  when the cached PLT was incompatible with the current OTP/Elixir version.
  The PLT now lives in `_build/dev/` (dialyxir's default location) and is
  covered by the existing `_build` cache.
- `script/ci`: Fixed `--warninsg-as-errors` typo in `mix docs` invocation.

## [0.6.0] - 2026-06-08

### Added

- **Top-level Explorer interchange API** — `ExArrow.from_dataframe/1` and
  `ExArrow.to_dataframe/1` convert between Explorer DataFrames and Arrow
  RecordBatches with preserved column names, row count, and values. Arrow value
  types are preserved; nullability metadata is not guaranteed through Explorer.
- **`ExArrow.DataFrame`** — `from_arrow/1` and `to_arrow/1` provide a
  DataFrame-oriented naming convention.  `from_arrow/1` accepts both
  `ExArrow.RecordBatch` and `ExArrow.Stream`.
- **Top-level Nx interchange API** — `ExArrow.from_nx/1` and `ExArrow.to_nx/1`
  convert between Nx tensors and Arrow RecordBatches.  Supports rank-1 and
  rank-2 tensors over u8, s64, f32, f64, and boolean dtypes.  Rank-2 tensors
  map to N-column batches (`c0..c{N-1}`) and round-trip with shape, dtype, and
  value fidelity.
- **`ExArrow.Schema.Mapper`** — single authority for bidirectional type mapping
  between Arrow dtype strings and Explorer/Nx type systems.  Extensible for
  future ExZarr and Dataset support.
- **Field nullability** — `ExArrow.Field` now includes a `nullable` field.  The
  `schema_fields` NIF returns `{name, type_atom, nullable}` tuples.  Schema
  round-trips preserve nullability information for Arrow-native data. Explorer
  IPC round-trips may relax nullable flags.
- **Boolean tensor support** — `ExArrow.Nx.from_tensor/3` accepts `as:
  :boolean` to create Arrow Boolean columns.  `column_to_tensor/2` and
  `to_tensors/1` now extract Boolean columns as `{:u, 8}` Nx tensors.
- **`ExArrow.RecordBatch.num_columns/1`** and **`column_names/1`** — convenient
  schema-derived accessors.
- **`ExArrow.Table.from_batches/1`** — create a Table from a list of
  RecordBatches.  Replaces the previous stub implementation with a real
  Elixir-side aggregation providing `schema/1`, `num_rows/1`, and `batches/1`.
- **Benchee benchmarks** — `bench/explorer_arrow_bench.exs` and
  `bench/nx_arrow_bench.exs` measure Explorer and Nx interchange throughput at
  1K, 100K, and 1M rows.
- **Educational guides** — `guides/01_arrow_for_elixir_developers.md`,
  `guides/02_explorer_integration.md`, `guides/03_nx_integration.md`,
  `guides/04_arrow_ecosystem.md`.
- **Property tests** — StreamData-based property tests for Explorer and Nx
  round-trip fidelity.
- **Arrow type coverage** — the `data_type_to_atom` NIF function now covers the
  full integer/float range (Int8, Int16, Int32, UInt8, UInt16, UInt32, UInt64,
  Float16, Float32) and additional types (Date32, Date64, Time32, Time64,
  Duration).

### Changed

- **`ExArrow.Nx` delegates to `ExArrow.Schema.Mapper`** — dtype mapping logic
  that was inlined in the Nx module now calls the Mapper, eliminating a
  duplicated source of truth.  Public API unchanged.
- **`ExArrow.Nx.from_tensor/3`** — now accepts an optional `opts` keyword list
  (was arity 2).  The `as: :boolean` option creates Arrow Boolean columns.
  Calling `from_tensor/2` (no opts) still works.
- **`ExArrow.Table`** — replaced stub implementation (returning `nil`/`0`) with
  a real Elixir-side aggregation struct holding `schema` and `batches`.
- **`ExArrow` moduledoc** — expanded with Arrow hierarchy explanation, data
  interchange API outline, and Schema.Mapper reference.
- **`ExArrow.Array`, `ExArrow.RecordBatch`, `ExArrow.Table` moduledocs** —
  improved with hierarchy context and usage guidance.
- **Version** — bumped from 0.5.0 to 0.6.0.

### Fixed

- **`ExArrow.from_dataframe/1` dropped rows for large dataframes** (#200) — when
  Explorer split a dataframe into multiple Arrow IPC batches, only the first
  batch was returned, silently discarding the rest.  Batches are now
  concatenated into a single `RecordBatch` via the new `record_batch_concat`
  NIF, preserving the full row count and all values.
- **Rank-2 `ExArrow.from_nx/1` corrupted column order for more than 10 columns**
  (#200) — columns were named `c0..cN` and reordered lexicographically
  (`"c10"` before `"c2"`).  Column names are now zero-padded and
  `ExArrow.to_nx/1` reconstructs columns in a deterministic sorted order, so
  round-trips are correct for any column count.
- **Rank-2 `ExArrow.from_nx/1` silently ignored `as: :boolean`** (#200) — the
  option was dropped for rank-2 tensors, producing UInt8 columns.  The
  combination now returns a clear error.
- **Boolean buffer extraction ignored null bitmap** (#201) — `value(i)` on a
  `BooleanArray` returns an unspecified bit for null slots.  The NIF now checks
  `is_null(i)` and writes 0 for null positions, matching the documented
  contract that "null positions are treated as zero bytes."
- **Nullability documentation contradiction** (#201) — the Explorer integration
  guide claimed "null positions in columns survive the round-trip" while the
  top-level docs correctly noted that nullability metadata is not preserved
  through Explorer.  The guide now explicitly distinguishes data preservation
  (nil values survive) from schema nullability (which Explorer may relax).
- **`nx_dtype` typespec was `term()`** (#201) — replaced the overly permissive
  `@type nx_dtype :: term()` in `ExArrow.Schema.Mapper` with the precise union
  `{:s | :u | :f, 8 | 16 | 32 | 64}`, restoring meaningful Dialyzer coverage.
- **O(n²) accumulation in `extract_numeric_fields`** (#200) — already fixed in
  v0.6.0 (uses `[field | acc]` + `Enum.reverse/1`).
- **`Nx.tensor(Nx.to_list(...))` materialization in `from_nx_rank2`** (#200) —
  already fixed in v0.6.0 (uses `Nx.as_type/2`).
- **Whole-file `dialyzer_ignore.exs` suppression** (#202) — `from_arrow/1` no
  longer pattern-matches on opaque `%Stream{}`/`%RecordBatch{}` structs.
  Instead it delegates to `RecordBatch.record_batch?/1` and `Stream.stream?/1`
  predicate functions.  The ignore file is now empty (`[]`), so future
  Dialyzer warnings in `data_frame.ex` will surface.
- **Test gaps** (#203) — added dedicated `data_frame_test.exs` with empty-batch
  error, dispatch, and type-rejection tests; extended rank-2 property tests to
  cover ≥11 columns; added Nx boolean null extraction tests; fixed property test
  column-name generation to use `uniq_list_of/2`.
- **Documentation: `from_tensor` arity inconsistency** (#204) — the API table
  and `from_tensors` doc referenced `from_tensor/2`; both now say
  `from_tensor/3` to match the actual arity with the optional `opts` default.
- **Documentation: overstated round-trip guarantees** (#204) —
  `from_dataframe/1` doc said "Schema and values are preserved" (schema
  includes nullable, which is not guaranteed); changed to "Schema field names
  and value types are preserved."  `to_dataframe/1` doc said "Schema, row
  count, and values are preserved"; changed to "Column names, row count, and
  values are preserved."
- **Documentation: stale first-batch rationalization** (#204) — the
  `data_frame.ex` docstring no longer mentions "the first batch is returned"
  (was already removed in the C1 fix).
- **Documentation: trailing space in `record_batch.ex`** (#204) — removed
  trailing space after `ExArrow.Table` / and clarified as "or".
- **Documentation: `Schema` moduledoc** (#204) — updated from "field names and
  types" to "field names, types, and nullability".

## [0.5.0] - 2026-04-16

### Added

- **Arrow Flight SQL client** — `ExArrow.FlightSQL.Client` connects to any
  Arrow Flight SQL server (DuckDB, DataFusion, Dremio, InfluxDB v3) and
  exposes a full query API:
  - `connect/1`, `connect/2` — plaintext or TLS (OS trust store or custom CA PEM);
    bearer-token and arbitrary gRPC header injection via `:headers`.
  - `query/2`, `query!/2` — materialise all result batches into an
    `ExArrow.FlightSQL.Result` struct.
  - `stream_query/2` — return a lazy `ExArrow.Stream` that implements
    `Enumerable`; batches are fetched one at a time and the gRPC connection
    is released when the stream is garbage-collected.
  - `execute/2` — DML/DDL with affected-row count; returns `{:ok, n}` or
    `{:ok, :unknown}`.
  - `prepare/2` — server-side prepared statements returning
    `ExArrow.FlightSQL.Statement`.
  - `get_tables/2`, `get_db_schemas/2`, `get_sql_info/1` — metadata discovery
    via the Flight SQL wire protocol.
- **`ExArrow.FlightSQL.Statement`** — executes a prepared statement as a lazy
  stream (`execute/1`) or as a DML update (`execute_update/1`).
- **`ExArrow.FlightSQL.Result`** — materialised result struct (`schema`,
  `batches`, `num_rows`); `to_dataframe/1` (requires Explorer) and
  `to_tensor/2` (requires Nx) for ecosystem integration.
- **`ExArrow.FlightSQL.Error`** — structured error type with `:code` atom,
  `:grpc_status` integer, and `:message` string.
- **`ExArrow.FlightSQL.ClientBehaviour`** — Mox-compatible behaviour for all
  client functions; inject a mock via
  `Application.put_env(:ex_arrow, :flight_sql_client_impl, MyMock)`.
- **`ExArrow.Stream` implements `Enumerable`** — all `Enum.*` and `Stream.*`
  functions now work directly on any `ExArrow.Stream` handle (IPC, Parquet,
  ADBC, Flight SQL).  Early termination (e.g. `Enum.take/2`) is safe — the
  resource is released when the stream variable goes out of scope.
- **`docs/flight_sql_guide.md`** — comprehensive guide covering connection
  options, TLS, authentication, query patterns, DML, prepared statements,
  metadata discovery, Explorer/Nx integration, Mox-based unit testing, and
  integration test setup.

### Changed

- **`ExArrow.FlightSQL` module doc** — v0.5.0 scope section updated to reflect
  all new capabilities; stale "not yet supported" items removed.
- **`docs/overview.md`** — Flight SQL guide added to the guide table and
  optional-integration table.

### Fixed

- **`deps/adbc/lib/adbc/result.ex` Elixir 1.17+ typing warning** — the
  `{:ok, stream_ref, capsule}` clause in `Adbc.Result.from_py/1` was
  unreachable when `Pythonx` is not loaded (only the `{:error, ...}` branch
  is reachable without Pythonx).  Both `from_py/1` and `from_py!/1` are now
  wrapped with `if Code.ensure_loaded?(Pythonx)` guards matching the
  pattern already used in `Adbc.Helper`.

---

## [0.4.0] - 2026-03-17

### Added

- **`:adbc_package` supervised backend** — a pure-Elixir ADBC backend that
  uses the Elixir `Adbc.*` packages rather than a native driver loaded by the
  ex_arrow NIF.  Configure it with:
  ```elixir
  config :ex_arrow, :adbc_package, driver: :sqlite, uri: ":memory:"
  ```
  `ExArrow.Application` automatically starts
  `ExArrow.ADBC.AdbcPackageManager` when the key is present.
  `Database.open(:adbc_package)` returns a sentinel `%Database{}` that routes
  all subsequent `Connection`, `Statement`, and `execute` calls through the
  manager.  Query results are converted to `ExArrow.Stream` via the Explorer
  IPC bridge (requires `{:explorer, "~> 0.11"}` in your deps).
  Set `config :ex_arrow, :adbc_package_pool_size, N` (N > 1) to activate a
  `NimblePool`-backed connection pool when `{:nimble_pool, "~> 1.1"}` is
  present.
- **`ExArrow.ADBC.AdbcPackageManager`** (internal) — `GenServer` that owns the
  supervised `Adbc.Database` + `Adbc.Connection` (or `AdbcPackagePool`)
  lifecycle for the `:adbc_package` backend.  Exposes `get_pids/0`,
  `create_statement/1`, `set_statement_sql/2`, and `execute_statement/1` as
  internal APIs consumed by `Database`, `Connection`, and `Statement`.
- **`ExArrow.ADBC.AdbcPackagePool`** (internal) — `NimblePool` worker module
  wrapping a pool of `Adbc.Connection` processes.  Activated automatically when
  `adbc_package_pool_size > 1` and `NimblePool` is available.
- **Arrow C Data Interface (`ExArrow.CDI`)** — zero-copy record batch transfer
  using the standardised Arrow CDI ABI.  `export/1` serialises a
  `RecordBatch` into heap-allocated `FFI_ArrowSchema` + `FFI_ArrowArray` C
  structs wrapped in a BEAM-managed resource handle.  `import/1` reconstructs a
  `RecordBatch` from the handle without any intermediate IPC bytes.
  `pointers/1` exposes the raw C struct addresses as
  `{schema_ptr, array_ptr}` integers for interop with any CDI-compatible
  runtime (Polars, DuckDB, etc.) in the same OS process.  `mark_consumed/1`
  safely nulls the handle so the BEAM GC skips the Arrow release callback
  after an external consumer has taken ownership.
- **`ExArrow.Nx.from_tensors/1`** — builds a multi-column `RecordBatch` from a
  `%{col_name => Nx.Tensor}` map in a single NIF call (new
  `record_batch_from_column_binaries` NIF).  Column order follows
  `Map.to_list/1` (sorted by key).  All tensors must have the same number of
  elements; mismatched sizes return `{:error, "all tensors must have the same
  size…"}`.
- **Parquet lazy row-group streaming** — `ExArrow.Parquet.Reader.from_file/1`
  and `from_binary/1` now decode row groups lazily on demand via
  `ExArrow.Stream.next/1` instead of eagerly collecting all batches on open.
  Peak memory scales with the largest single row group rather than the full
  file.  The Elixir API is unchanged.
- **`docs/cdi_guide.md`** — new guide covering CDI concepts, round-trip usage,
  interop with external consumers, memory safety guarantees, and the roadmap
  for the zero-copy Explorer bridge.
- **`docs/adbc_guide.md`** — new "Using the adbc_package backend" section with
  supervision tree setup, pool sizing, Explorer dependency note, and error
  handling.
- **`{:stream_data, "~> 1.3.0", only: :test}`** — added for property-based
  test helpers (test dependency only; no impact on library users).

### Changed

- **`ExArrow.Stream` native dispatch** — all six NIF calls in `schema/1` and
  `next/1` now go through a private `native/0` helper that reads
  `Application.get_env(:ex_arrow, :stream_native, ExArrow.Native)`, making
  the module fully testable in isolation without a loaded NIF.  The public API
  is unchanged.
- **`ExArrow.Explorer` module documentation** updated to describe the current
  IPC path and the planned CDI zero-copy path for a future Explorer release.
- **`ExArrow.Nx` module documentation** updated with `from_tensors/1` examples.
- **Cargo.toml** — `arrow` crate updated to include the `ffi` feature;
  `ex_arrow_native` version bumped to `0.4.0`.
- **`nx` optional dependency** constraint updated from `~> 0.7` to `~> 0.9`.
- **`adbc` optional dependency** constraint updated from `~> 0.7` to `~> 0.9` to
  match current Hex releases (`mix.lock` resolves e.g. 0.9.0; `~> 0.7` only
  allowed `< 0.8.0`).  Documentation and Livebook examples updated accordingly.
- **Parquet `parquet_stream_next` NIF** — scheduled as **dirty CPU** (`schedule =
  "DirtyCpu"` in Rust) so lazy row-group decode does not block normal BEAM
  scheduler threads.

### Fixed

- **`AdbcPackageManager.handle_call({:set_statement_sql, ...})`** — crashed with
  `BadMapError` when the manager state was a cached `{:error, reason}` tuple
  (i.e. after a failed driver start).  A `when not is_map(state)` guard clause
  now returns `{:error, :not_configured}` cleanly.
- **`AdbcPackageManager` startup failure** — when pool or connection startup failed
  after spawning a `Database` process linked to the manager, `Process.exit(db_pid,
  :kill)` could kill the manager via the link.  The manager now **unlinks** the
  database pid before terminating it.
- **`ExArrow.Parquet` stream lock** now propagates `ArrowError` from the lazy
  iterator (previously impossible with eager loading; now correctly returned as
  `{:error, msg}`).

---

## [0.3.0] - 2026-03-10

### Added

- **Arrow compute kernels** — `ExArrow.Compute` with three operations:
  `filter/2` (mask rows using the first column of a boolean-typed record
  batch), `project/2` (select and reorder columns by name), and `sort/3`
  (sort a batch by a named column, ascending or descending).  All operations
  run entirely in native Arrow memory via the `arrow-select` and `arrow-ord`
  Rust crates; results are new `ExArrow.RecordBatch` handles that can be
  piped directly into IPC writers, Flight `do_put`, or further compute calls.
- **Parquet support** — `ExArrow.Parquet.Reader` and
  `ExArrow.Parquet.Writer` for reading and writing the Parquet columnar
  storage format, backed by the `parquet` Rust crate.  Both file paths and
  in-memory binaries are supported.  Parquet streams share the same
  `ExArrow.Stream` interface as IPC and ADBC streams — `schema/1`, `next/1`,
  and `to_list/1` all work identically.
- **Explorer bridge module** — `ExArrow.Explorer` for direct conversion
  between `ExArrow.Stream` / `ExArrow.RecordBatch` and
  `Explorer.DataFrame` without writing manual IPC boilerplate.  Functions:
  `from_stream/1`, `from_record_batch/1`, `to_stream/1`,
  `to_record_batches/1`.  Requires `{:explorer, "~> 0.8"}` in your
  `mix.exs`; when Explorer is absent every function returns an informative
  `{:error, ...}` tuple.
- **Nx bridge module** — `ExArrow.Nx` for converting Arrow numeric columns
  to `Nx.Tensor` values (and back) by sharing the raw byte buffer — no
  list materialisation.  Functions: `column_to_tensor/2`, `to_tensors/1`,
  `from_tensor/2`.  Supports all integer and float Arrow types.
  Non-numeric columns return `{:error, ...}` and are silently skipped by
  `to_tensors/1`.  Requires `{:nx, "~> 0.7"}` in your `mix.exs`.
- **New optional dependency** — `{:nx, "~> 0.7", optional: true}` added to
  `mix.exs`.  No action required unless you use `ExArrow.Nx`.
- **`ExArrow.Stream` Parquet backend** — `Stream.schema/1` and
  `Stream.next/1` dispatch correctly for `:parquet`-backed streams returned
  by `ExArrow.Parquet.Reader`.
- **New Rust crate dependencies** — `arrow-select`, `arrow-ord`,
  `arrow-buffer`, `arrow-data` (compute kernels) and `parquet` (Parquet
  support) added to `native/ex_arrow_native/Cargo.toml`.
- **New guides** — `docs/parquet_guide.md` and `docs/compute_guide.md` with
  full API walkthroughs, examples, and performance notes.

### Fixed

- Dialyzer `call_without_opaque` warnings in `ExArrow.Explorer` and
  `ExArrow.Nx` — removed unnecessary struct pattern matches from function
  heads that were leaking the concrete struct type through the `@opaque`
  boundary of `ExArrow.Stream.t()` and `ExArrow.RecordBatch.t()`.
- Credo `alias must appear before module attribute` in `nx_test.exs` and
  `explorer_test.exs`.
- Credo `Pipe chain should start with a raw value` in `parquet_test.exs`.
- Credo `length/1 is expensive` in `explorer_test.exs`.
- `checksum-Elixir.ExArrow.Native.exs` regenerated for v0.3.0 across all
  supported platforms.

## [0.2.0] - 2026-03-09

### Added

- **TLS for Arrow Flight server** — `Server.start_link/2` now accepts a `:tls`
  option for one-way TLS (`[cert_pem: ..., key_pem: ...]`) and mutual TLS (add
  `ca_cert_pem:`). The Rust NIF uses tonic's `ServerTlsConfig` and `Identity`.
- **Flight server routing** — the built-in Flight server now stores multiple
  named datasets in a `HashMap`. Each `do_put` keys the dataset by the
  `FlightDescriptor` (cmd bytes or joined path segments), falling back to the
  legacy `"echo"` ticket when no descriptor is provided. New `"list_tickets"`
  action returns all stored ticket names.
- **`Client.do_put/4`** — optional `:descriptor` keyword argument
  (`{:cmd, binary()}` or `{:path, [String.t()]}`) routes the upload to a named
  ticket on the server.
- **ADBC connection pool** — `ExArrow.ADBC.ConnectionPool` is a first-class
  NimblePool-backed pool with `start_link/1`, `query/3`, and
  `with_connection/3`. Use it from a supervision tree via the companion
  `ExArrow.ADBC.DatabaseServer` GenServer.
- **`ExArrow.ADBC.DatabaseServer`** — supervised GenServer that holds an open
  `Database` handle and vends it by registered name to connection pools.
- **`Database.close/1` and `Connection.close/1`** — explicit close helpers
  (idiomatic no-ops backed by NIF GC; useful in pool `terminate_worker`).
- **`ExArrow.Schema.field_names/1`** — convenience accessor that returns just
  the field name strings without allocating `Field` structs.
- **`ExArrow.Stream.to_list/1`** — collects all remaining batches from a stream
  into an Elixir list.
- **Integration test matrix** — `test/ex_arrow/adbc_integration_test.exs` with
  PostgreSQL (pg 14/15/16) and DuckDB (1.1.3, 1.2.0) suites, gated behind the
  `:adbc_integration` tag and driven by a new
  `.github/workflows/integration.yml` CI workflow.

### Changed

- **`flight_server_start` NIF** now takes a third `server_tls` argument.
  Elixir callers use `Server.start_link/2` with the `:tls` option; the arity
  change is hidden behind the public API.
- **`flight_client_do_put` NIF** now takes a fourth `descriptor` argument.
  Existing calls pass `:none`; the default is wired in automatically by
  `Client.do_put/3` (3-arity form still works unchanged).
- **`ClientBehaviour.do_put/4`** — callback now includes the `opts` argument.
  Any existing Mox stubs must be updated to match 4 arguments.

### Fixed

- Dialyzer `call_without_opaque` warning in `ConnectionPool.init_worker/1` —
  replaced struct pattern match on opaque `Database.t()` with an `is_atom/1`
  guard, preserving the opaque boundary.
- Credo `alias must appear before module attribute` warning in integration test.
- Credo `length/1 is expensive` warnings replaced with `!= []` comparisons.
- `ExUnit.skip/1` compile warning in integration test replaced with
  `raise ExUnit.SkipError`.

## [0.1.0] - 2026-02-27

Initial release.

### Added

- **IPC**: Stream and file format. Read from binary or file; write to binary or file. Random-access file API (schema, batch count, get batch by index).
- **Arrow Flight**: Client and echo server. Connect, do_put/do_get, list_flights, get_flight_info, get_schema, list_actions, do_action. Plaintext HTTP/2 only.
- **ADBC**: Database, Connection, Statement. Open by driver path or name; execute SQL to Arrow stream. Metadata APIs (get_table_types, get_table_schema, get_objects) and Statement.bind where supported by driver.
- **Memory model**: Opaque handles (Schema, RecordBatch, Table, Stream). Data stays in native Arrow buffers; no BEAM heap copy by default. Dirty NIFs for long-running work.
- **Precompiled NIFs**: RustlerPrecompiled; prebuilt binaries for common targets (Linux, macOS, Windows) from GitHub releases. Optional local build via `EX_ARROW_BUILD=1`.

### Requirements

- Elixir ~> 1.14 (OTP 25/26, NIF 2.15 and 2.16)
- No Rust required for normal use (precompiled NIFs)
