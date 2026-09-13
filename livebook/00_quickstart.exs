# Run as: iex --dot-iex path/to/notebook.exs

# Title: ExArrow Quick Start - fork

deps = [
  {:explorer, "~> 0.11"},
  {:kino, "~> 0.19.0"},
  {:adbc, "~> 0.12"},
  {:nimble_pool, "~> 1.1"},
  {:gen_stage, "~> 1.3"},
  {:nx, "~> 0.12.1"}
]

# Opened from livebook/ in the repo → local source; otherwise Hex (precompiled NIF).
local? = File.exists?(Path.join(__DIR__, "../native/ex_arrow_native/Cargo.toml"))

{ex_arrow_dep, extra_deps, config} =
  if local? do
    System.put_env("EX_ARROW_BUILD", "1")

    {
      {:ex_arrow, path: Path.expand("..", __DIR__)},
      [{:rustler, "~> 0.36", optional: true}],
      [adbc: [drivers: [:sqlite]], rustler_precompiled: [force_build: [ex_arrow: true]]]
    }
  else
    {
      {:ex_arrow, "~> 0.9.0"},
      [],
      [adbc: [drivers: [:sqlite]]]
    }
  end

Mix.install(deps ++ [ex_arrow_dep] ++ extra_deps, config: config)

# ── Start ──

# Get up and running with ExArrow in a few minutes. This notebook touches all major features: **IPC** (read/write Arrow streams), **Arrow Flight** (client/server), **Flight SQL** (parameterized queries), **ADBC** (query databases), and **data interchange** (Explorer/Nx).

# Configure adbc to use the SQLite driver (for section 5):

Application.put_env(:adbc, :drivers, [:sqlite])
:ok = Adbc.download_driver!(:sqlite)

db = Kino.start_child!({Adbc.Database, driver: :sqlite})
conn = Kino.start_child!({Adbc.Connection, database: db})
{:ok, result} = Adbc.Connection.query(conn, "SELECT 1 AS n, 'hello' AS msg")

# ── 1. Setup ──

# Add `ex_arrow` to your Mix project and start a Livebook (or run in IEx). Here we assume the dependency is already in place.

# Verify the NIF loaded
ExArrow.native_version()

# ---

# ── 2. IPC: Read an Arrow stream ──

# ExArrow can read Arrow IPC from a binary (e.g. from a file, socket, or HTTP body). We'll use a small built-in fixture so you can run this without any external file.

# Get a small IPC stream binary (schema: id int64, name utf8; 2 rows)
{:ok, ipc_bytes} = ExArrow.Native.ipc_test_fixture_binary()

# Open a stream from the binary
{:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bytes)

# Inspect schema (without consuming the stream)
{:ok, schema} = ExArrow.Stream.schema(stream)
ExArrow.Schema.fields(schema) |> Enum.map(& &1.name)

# Read batches one at a time until the stream is done:

# First batch
batch1 = ExArrow.Stream.next(stream)
if batch1, do: ExArrow.RecordBatch.num_rows(batch1), else: nil

# Second call: no more batches
ExArrow.Stream.next(stream)

# ---

# ── 3. IPC: Write then read (roundtrip) ──

# You can write the same schema and batches back to a binary or file, then read again.

# Rebuild stream from fixture and collect schema + all batches
{:ok, ipc_bytes} = ExArrow.Native.ipc_test_fixture_binary()
{:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bytes)
{:ok, schema} = ExArrow.Stream.schema(stream)

batches =
  Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end)
  |> Enum.take_while(&(is_struct(&1, ExArrow.RecordBatch)))

# Write to binary
{:ok, out_binary} = ExArrow.IPC.Writer.to_binary(schema, batches)
byte_size(out_binary)

# ---

# ── 4. Arrow Flight: Echo server and client ──

# Arrow Flight is a gRPC-based protocol for streaming Arrow data. ExArrow includes a small **echo server**: you upload data with `do_put`, then download it with `do_get` using the ticket `"echo"`.

# Start the server (one cell), then use the client in the next.

# Start the built-in echo server on port 9999
{:ok, server} = ExArrow.Flight.Server.start_link(9999, [])
{:ok, port} = ExArrow.Flight.Server.port(server)
port

# Connect and upload our fixture data
{:ok, ipc_bytes} = ExArrow.Native.ipc_test_fixture_binary()
{:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bytes)
{:ok, schema} = ExArrow.Stream.schema(stream)
batches = Stream.repeatedly(fn -> ExArrow.Stream.next(stream) end) |> Enum.take_while(&is_struct(&1, ExArrow.RecordBatch))

{:ok, client} = ExArrow.Flight.Client.connect("localhost", 9999, [])
:ok = ExArrow.Flight.Client.do_put(client, schema, batches)

# Download the same data via do_get
{:ok, down_stream} = ExArrow.Flight.Client.do_get(client, "echo")
{:ok, down_schema} = ExArrow.Stream.schema(down_stream)

first = ExArrow.Stream.next(down_stream)
ExArrow.RecordBatch.num_rows(first)

# Clean up
ExArrow.Flight.Server.stop(server)

# ---

# ### 5. ADBC: Query a database, get Arrow results

# With ADBC you open a database (e.g. SQLite), run SQL, and get an **Arrow stream** of result batches—same `ExArrow.Stream` API as IPC and Flight.

# This cell uses the **`:adbc_package`** backend (see [03 ADBC](03_adbc.livemd) and [04 ADBC integration](04_adbc_integration.livemd)): the [`adbc`](https://hex.pm/packages/adbc) package downloads SQLite; ExArrow returns `ExArrow.Stream` batches without a native `.dylib`. For native C drivers in production, see [Installing an ADBC driver](INSTALL_ADBC_DRIVER.md).

:ok = Adbc.download_driver!(:sqlite)
Application.put_env(:adbc, :drivers, [:sqlite])
Application.put_env(:ex_arrow, :adbc_package, driver: :sqlite, uri: ":memory:")

unless Process.whereis(ExArrow.ADBC.AdbcPackageManager) do
  {:ok, _pid} = ExArrow.ADBC.AdbcPackageManager.start_link()
end

case ExArrow.ADBC.Database.open(:adbc_package) do
  {:ok, db} ->
    {:ok, conn} = ExArrow.ADBC.Connection.open(db)
    {:ok, stmt} = ExArrow.ADBC.Statement.new(conn, "SELECT 1 AS n, 'hello' AS msg")
    {:ok, stream} = ExArrow.ADBC.Statement.execute(stmt)
    {:ok, schema} = ExArrow.Stream.schema(stream)
    batch = ExArrow.Stream.next(stream)
    IO.inspect(ExArrow.Schema.fields(schema), label: "Columns")
    IO.inspect(ExArrow.RecordBatch.num_rows(batch), label: "Rows")

  {:error, msg} ->
    IO.puts("ADBC query failed: #{msg}")
end

# ---

# ### Next steps

# * **Notebook 01 — IPC**: Stream vs file format, reading from files, writing to files, schema and types.
# * **Notebook 02 — Flight**: Full server/client API, Flight SQL prepared statements with parameter binding.
# * **Notebook 03 — ADBC**: Metadata APIs, optional Explorer roundtrip, and production tips.

# ---

# ── 6. Explorer interchange (v0.6+) ──

# ExArrow can convert between Arrow data and Explorer DataFrames in one call:

if Code.ensure_loaded?(Explorer.DataFrame) do
  df = Explorer.DataFrame.new(id: [1, 2, 3], name: ["alice", "bob", "carol"])

  # DataFrame → Arrow
  {:ok, batch} = ExArrow.from_dataframe(df)
  IO.puts("Batch rows: #{ExArrow.RecordBatch.num_rows(batch)}")

  # Arrow → DataFrame
  {:ok, df2} = ExArrow.to_dataframe(batch)
  IO.inspect(df2)
else
  "Explorer not loaded; add {:explorer, \"~> 0.11\"} to deps."
end

# ---

# ── 7. Nx interchange (v0.6+) ──

# ExArrow can convert between Arrow columns and Nx tensors without materialising lists:

if Code.ensure_loaded?(Nx) do
  tensor = Nx.tensor([1, 2, 3], type: {:s, 64})

  # Tensor → Arrow
  {:ok, batch} = ExArrow.from_nx(tensor)
  IO.puts("NX Batch rows: #{ExArrow.RecordBatch.num_rows(batch)}")

  # Arrow → Tensor
  {:ok, back} = ExArrow.to_nx(batch)
  IO.inspect(Nx.to_list(back))
else
  "Nx not loaded; add {:nx, \"~> 0.9\"} to deps."
end

# ---

# ── 8. Flight SQL prepared statements with parameter binding (v0.6+) ──

# Connect to a Flight SQL server, prepare a query, bind parameters, and execute:

# Requires a running Flight SQL server (e.g. DuckDB with flight_sql extension)
# {:ok, client} = ExArrow.FlightSQL.Client.connect("localhost:32010")
#
# {:ok, stmt} = ExArrow.FlightSQL.Client.prepare(client, "SELECT * FROM users WHERE id = ?")
#
# {:ok, schema} = ExArrow.FlightSQL.Statement.parameter_schema(stmt)
# # => [%ExArrow.Field{name: "id", type: :int64, nullable: false}]
#
# {:ok, params} = ExArrow.RecordBatch.from_columns(["id"], [<<42::little-signed-64>>], ["s64"], 1)
# :ok = ExArrow.FlightSQL.Statement.bind(stmt, params)
# {:ok, stream} = ExArrow.FlightSQL.Statement.execute(stmt)
# batches = Enum.to_list(stream)
#
# # Re-bind with a different parameter value
# {:ok, other} = ExArrow.RecordBatch.from_columns(["id"], [<<99::little-signed-64>>], ["s64"], 1)
# :ok = ExArrow.FlightSQL.Statement.bind(stmt, other)
# {:ok, stream2} = ExArrow.FlightSQL.Statement.execute(stmt)
#
# :ok = ExArrow.FlightSQL.Statement.close(stmt)

IO.puts("Uncomment the cells above when a Flight SQL server is available.")

# ---

# ── 9. Streaming pipelines (v0.7.0) ──

# v0.7.0 introduces first-class streaming and a pipeline DSL.  The unit of
# execution is the Arrow `RecordBatch`.

# **Stream constructors** — one entry point per source:

# From an IPC binary (built-in fixture)
{:ok, ipc_bytes} = ExArrow.Native.ipc_test_fixture_binary()
{:ok, stream} = ExArrow.Stream.from_ipc(ipc_bytes)
{:ok, schema} = ExArrow.Stream.schema(stream)
ExArrow.Schema.field_names(schema)

# **Batch operations** — lightweight, Arrow-native transforms:

batch = ExArrow.Stream.next(stream)

{:ok, slim} = ExArrow.Batch.select(batch, ["id"])
ExArrow.RecordBatch.column_names(slim)

{:ok, renamed} = ExArrow.Batch.rename(slim, %{"id" => "user_id"})
ExArrow.RecordBatch.column_names(renamed)

{:ok, first1} = ExArrow.Batch.take(renamed, 1)
ExArrow.RecordBatch.num_rows(first1)

# **Pipeline DSL** — lazy `map_batches` + sink:

# Re-open the stream (the previous one was consumed)
{:ok, stream2} = ExArrow.Stream.from_ipc(ipc_bytes)
out_path = Path.join(System.tmp_dir!(), "ex_arrow_quickstart_pipeline.parquet")

{:ok, stream2}
|> ExArrow.Pipeline.map_batches(fn b ->
  {:ok, s} = ExArrow.Batch.select(b, ["id"])
  s
end)
|> ExArrow.Pipeline.write_parquet(out_path)

File.exists?(out_path)

# **Telemetry** — attach a handler and observe every batch:

:telemetry.attach(
  "ex-arrow-quickstart",
  [:ex_arrow, :stream, :batch],
  fn _event, measurements, metadata, _config ->
    IO.puts("batch: #{measurements[:rows]} rows from #{inspect(metadata[:source])}")
  end,
  nil
)

{:ok, stream3} = ExArrow.Stream.from_ipc(ipc_bytes)
_ = ExArrow.Stream.to_list(stream3)

:telemetry.detach("ex-arrow-quickstart")

# Docs: [ex-arrow.hexdocs.pm](https://ex-arrow.hexdocs.pm) · [ADBC guide](https://ex-arrow.hexdocs.pm/adbc_guide.html).
