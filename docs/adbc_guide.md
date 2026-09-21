# ADBC (Arrow Database Connectivity)

ADBC exposes databases through the canonical adbc.h API. ExArrow binds to the ADBC driver manager and returns Arrow streams from SQL execution.

## Concepts

| Handle | Module | Purpose |
|--------|--------|---------|
| Database | `ExArrow.ADBC.Database` | Driver + init options (e.g. URI). |
| Connection | `ExArrow.ADBC.Connection` | Session from a database. |
| Statement | `ExArrow.ADBC.Statement` | SQL text, execute → stream of record batches. |

Flow: **Database.open** → **Connection.open** → **Statement.new(conn, sql)** → **execute** → **Stream** (same `ExArrow.Stream` as IPC/Flight; use `ExArrow.Stream.schema/1` and `ExArrow.Stream.next/1`).

## Driver loading

- **By path** — pass a string: the path to the driver shared library (e.g. `libadbc_driver_sqlite.so` or absolute path).
- **By name** — pass a keyword list with `driver_name` and optionally `uri`. The driver manager looks up the library by name (e.g. from `ADBC_DRIVER` or system search paths). If you pass `uri`, it is sent to the driver as the database URI (e.g. SQLite `uri: ":memory:"`). If you omit `uri`, no URI option is set; behavior is driver-dependent (some drivers require a URI and will fail at connection time).

If the driver cannot be loaded (wrong path, missing env), `Database.open/1` returns `{:error, message}`.

**Installing a driver:** For step-by-step options (the [`adbc`](https://hex.pm/packages/adbc) Hex package and its precompiled artifacts, or building from [Apache Arrow ADBC](https://github.com/apache/arrow-adbc)), see [livebook/INSTALL_ADBC_DRIVER.md](https://github.com/AnimaLogica/ex_arrow/blob/main/livebook/INSTALL_ADBC_DRIVER.md).

## Using the `adbc` package for driver setup

ExArrow does **not** manage or download ADBC drivers itself. It assumes that
drivers such as `adbc_driver_sqlite` or `adbc_driver_postgresql` are already
installed and discoverable by the ADBC driver manager.

If you want higher-level driver management (configuration and on-demand
download), you can use the separate
[`adbc`](https://hex.pm/packages/adbc) package:

- Add `{:adbc, "~> 0.9"}` to your project.
- Configure drivers or call `Adbc.download_driver!/1` to ensure they are
  available (for example `:sqlite`, `:postgresql`, `:snowflake`).
- Then open the database with ExArrow, either by path or by `driver_name` and
  `uri`, exactly as described above.

For example, using `adbc` for driver setup and ExArrow for Arrow result
streams:

```elixir
# Ensure the SQLite driver is present (no-op if already installed)
Adbc.download_driver!(:sqlite)

{:ok, db} =
  ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: ":memory:")

{:ok, conn} = ExArrow.ADBC.Connection.open(db)
{:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
```

Alternatively, you can use
`ExArrow.ADBC.DriverHelper.ensure_driver_and_open/2`, which calls
`Adbc.download_driver/1` when the `:adbc` package is available and then opens
the database via `ExArrow.ADBC.Database.open/1`:

```elixir
{:ok, db} = ExArrow.ADBC.DriverHelper.ensure_driver_and_open(:sqlite, ":memory:")
```

## Using the adbc package as the backend (supervised)

When you want to use the [`adbc`](https://hex.pm/packages/adbc) Hex package’s process-based Database/Connection (and its drivers) **instead of** loading a native ADBC C driver, configure ExArrow to start and supervise the adbc processes:

1. Add `{:adbc, "~> 0.9"}`, `{:explorer, "~> 0.11"}` (needed to convert query results to `ExArrow.Stream`), and optionally `{:nimble_pool, "~> 1.1"}` (for connection pooling) to your deps.
2. Set `config :ex_arrow, :adbc_package` to a keyword list of options passed to `Adbc.Database.start_link/1` (e.g. `[driver: :sqlite, uri: ":memory:"]`).

ExArrow’s application will then start the adbc_package backend (which starts `Adbc.Database` and `Adbc.Connection` under ExArrow’s supervisor. You can open that connection with `Database.open(:adbc_package)` and use the usual flow (Connection.open → Statement.new(conn, sql) → execute). No native driver path or name is required.

**Example (e.g. in config/config.exs or Livebook):**

In Livebook or a script, ensure the driver is available before the backend starts (e.g. `Adbc.download_driver!(:sqlite)`). Then set config:

```elixir
config :ex_arrow, :adbc_package, [driver: :sqlite, uri: ":memory:"]
```

Then in code:

```elixir
{:ok, db} = ExArrow.ADBC.Database.open(:adbc_package)
{:ok, conn} = ExArrow.ADBC.Connection.open(db)
{:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n, 'hello' AS msg")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
{:ok, schema} = ExArrow.Stream.schema(stream)
batch = ExArrow.Stream.next(stream)
```

**Printing / displaying results** — Use `ExArrow.Stream.schema/1` and `ExArrow.Stream.next/1` in a loop until `next/1` returns `nil`. To show results as a table in Livebook or scripts, collect batches, write to IPC binary, then load into Explorer:

```elixir
{:ok, schema} = ExArrow.Stream.schema(stream)
batches = Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
          |> Enum.take_while(&is_struct(&1, ExArrow.RecordBatch))
{:ok, binary} = ExArrow.IPC.Writer.to_binary(schema, batches)
Explorer.DataFrame.load_ipc_stream!(binary)
```

`ExArrow.ADBC.DriverHelper.ensure_driver_and_open/2` will use this supervised connection when `:adbc_package` is configured (and will not try to download or open a native driver in that case). If config is set after the application has started (e.g. in a Livebook cell), the connection is started lazily on first use.

### Connection pooling (optional)

By default, the adbc-package backend starts a single `Adbc.Connection` process, so queries are serialized. If you want concurrent query throughput, set:

```elixir
config :ex_arrow, :adbc_package_pool_size, 8
```

When `:adbc_package_pool_size` is greater than 1 and `:nimble_pool` is available, ExArrow starts a `NimblePool` of `Adbc.Connection` workers and uses it for `Statement.execute/1`.

**Limitations when using the adbc_package backend:** metadata APIs (`get_table_types`, `get_table_schema`, `get_objects`) and `Statement.bind/2` are not implemented and return an error. Query results are converted to `ExArrow.Stream` via Explorer (Adbc.Result → DataFrame → IPC stream format → ExArrow.Stream); if Explorer is not available, `execute/1` returns an error.

## Example

```elixir
# Path to the driver .so / .dylib
{:ok, db} = ExArrow.ADBC.Database.open("/path/to/libadbc_driver_sqlite.so")
# Or by name (uses env / system search)
{:ok, db} = ExArrow.ADBC.Database.open(driver_name: "adbc_driver_sqlite", uri: ":memory:")

{:ok, conn} = ExArrow.ADBC.Connection.open(db)
{:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n")
{:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)

{:ok, schema} = ExArrow.Stream.schema(stream)
batch = ExArrow.Stream.next(stream)
# Consume until nil
```

## Local testing

You can test ADBC locally without a dedicated "dummy ADBC service".

### Fast path: `:adbc_package` (SQLite in-memory)

This is the easiest local check and does not require running PostgreSQL/DuckDB:

```bash
mix test --include adbc_package test/ex_arrow/adbc_package_test.exs
```

If you hit teardown flakes or `:nif_not_loaded` after dependency/build changes,
reset and rebuild first:

```bash
mix clean
EX_ARROW_BUILD=1 mix compile
mix test --include adbc_package test/ex_arrow/adbc_package_test.exs
```

### PostgreSQL integration (`:adbc_integration`)

Start a local PostgreSQL container:

```bash
docker run --name exarrow-pg -d \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 postgres:16
```

Run integration tests:

```bash
PG_HOST=localhost \
PG_PORT=5432 \
PG_USER=postgres \
PG_PASSWORD=postgres \
PG_DATABASE=postgres \
mix test --include adbc_integration test/ex_arrow/adbc_integration_test.exs
```

If PostgreSQL ADBC is not on your system path, set:
`PG_ADBC_DRIVER=/path/to/libadbc_driver_postgresql.so` (or `.dylib`).

On macOS, `driver_name: "adbc_driver_postgresql"` usually searches for a
`.dylib`, but Python wheels may install a `.so` instead. In that case, set
`PG_ADBC_DRIVER` explicitly to the installed file path.

Find the installed PostgreSQL driver file from Python:

```bash
python - <<'PY'
import pathlib
import adbc_driver_postgresql
p = pathlib.Path(adbc_driver_postgresql.__file__).parent
for pattern in ("**/libadbc_driver_postgresql*.so", "**/libadbc_driver_postgresql*.dylib"):
    matches = list(p.glob(pattern))
    if matches:
        print(matches[0])
        break
else:
    raise SystemExit("No PostgreSQL ADBC shared library found in adbc_driver_postgresql package")
PY
```

Then run:

```bash
PG_ADBC_DRIVER=/absolute/path/to/libadbc_driver_postgresql.so \
PG_HOST=localhost \
PG_PORT=5432 \
PG_USER=postgres \
PG_PASSWORD=postgres \
PG_DATABASE=postgres \
mix test --include adbc_integration test/ex_arrow/adbc_integration_test.exs
```

### DuckDB integration (`:adbc_integration`)

Point tests at your DuckDB ADBC driver:

```bash
DUCKDB_DRIVER=/path/to/libduckdb.so \
DUCKDB_DATABASE=:memory: \
mix test --include adbc_integration test/ex_arrow/adbc_integration_test.exs
```

On macOS the library is typically a `.dylib`.

## When no driver is available

ExUnit does not support skipping a test dynamically from `setup`. The ADBC integration test therefore **fails with a clear message** when the driver cannot be opened (instead of passing), so that missing driver setup is visible when running `mix test --include adbc`. Use `mix test --exclude adbc` to omit it when no driver is installed.

In your own tests you can match on `{:error, _}` and raise an actionable message or exit:

```elixir
case ExArrow.ADBC.Database.open(opts) do
  {:error, reason} -> raise "ADBC driver not available: #{inspect(reason)}"
  {:ok, db}        -> run_query(db)
end
```

In scripts, match on `{:error, _}` to log and exit or skip the workflow.

## Metadata APIs

When the driver supports them, you can query catalog metadata without executing SQL:

- **`Connection.get_table_types/1`** — returns a stream of table types (e.g. `TABLE`, `VIEW`). Use `ExArrow.Stream.schema/1` and `ExArrow.Stream.next/1` to read.
- **`Connection.get_table_schema/3`** — returns the Arrow schema of a table. Arguments: `(conn, catalog, db_schema, table_name)`; `catalog` and `db_schema` may be `nil` if not applicable.
- **`Connection.get_objects/2`** — hierarchical view of catalogs, schemas, tables, columns. Options: `:depth` (`"all"`, `"catalogs"`, `"schemas"`, `"tables"`, `"columns"`), optional `:catalog`, `:db_schema`, `:table_name`, `:column_name` filters.

If the driver does not support a given call, you get `{:error, message}`.

## Parameter binding

**`Statement.bind/2`** binds a record batch to the statement (e.g. for prepared statements or bulk insert). Use when rebinding; for an initial bind use `Statement.new(conn, sql, bind: record_batch)`. Pass an `ExArrow.RecordBatch` (e.g. from `ExArrow.Stream.next/1` or built from Arrow data). Not all drivers support binding; unsupported drivers return `{:error, message}`.

## Errors and diagnostics

Errors (driver load failure, execute failure, unsupported operation) are returned as `{:error, message}` where `message` is a string. The format is driver-dependent; it may include SQLSTATE, vendor codes, or internal details. Use `ExArrow.ADBC.Error.from_message/1` to wrap a string in a struct for consistent handling; `ExArrow.ADBC.Error.message/1` works on both structs and raw strings.

## Support matrix

| Feature | Native driver backend | `:adbc_package` backend |
|---------|----------------------|------------------------|
| `Database.open(path / keyword)` | ✓ All drivers | `Database.open(:adbc_package)` |
| `Connection.open` | ✓ All drivers | ✓ |
| `Statement.new(conn, sql)` + `execute` | ✓ All drivers | ✓ (requires Explorer) |
| `get_table_types` | ✓ Varies (SQLite ✓) | ✗ returns error |
| `get_table_schema` | ✓ Varies | ✗ returns error |
| `get_objects` | ✓ Varies | ✗ returns error |
| `Statement.bind` | ✓ Varies | ✗ returns error |
| Connection pooling | `ConnectionPool` (NimblePool) | ✓ `adbc_package_pool_size > 1` |

Run `mix test --include adbc` with a driver to exercise metadata and binding; without a driver those tests fail with a clear message. Use `mix test --exclude adbc` to skip ADBC integration tests.
