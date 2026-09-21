# ExArrow 0.1.0 — Release notes

**Release date:** 2026-02-26 
**Package:** [Hex](https://hex.pm/packages/ex_arrow) | **Docs:** [hexdocs.pm/ex_arrow](https://hexdocs.pm/ex_arrow) | **Source:** [GitHub](https://github.com/AnimaLogica/ex_arrow)

---

## Summary

ExArrow 0.1.0 is the first public release. It brings Apache Arrow support to the BEAM: IPC (stream and file), Arrow Flight (client and server), and ADBC (Arrow Database Connectivity). Data stays in native Rust/Arrow buffers; Elixir uses opaque handles. Precompiled NIFs are provided for Linux (x86_64, aarch64), macOS (x86_64, arm64), and Windows (x86_64), so no Rust toolchain is required for normal use.

**Requirements:** Elixir ~> 1.14 (OTP 25 / NIF 2.15 and OTP 26+ / NIF 2.16)

---

## What's included

**IPC (Inter-Process Communication)**  
- Read/write Arrow stream format from binary or file.  
- Random-access file format: open by path or binary, read schema, batch count, and any batch by index.  
- Same `ExArrow.Stream` and `ExArrow.Schema` / `ExArrow.RecordBatch` handles as Flight and ADBC.

**Arrow Flight**  
- gRPC client: connect, do_put, do_get, list_flights, get_flight_info, get_schema, list_actions, do_action.  
- Built-in echo server for testing or simple services.  
- Plaintext HTTP/2 only in this release (TLS planned). Compatible with Dremio, InfluxDB IOx, and custom Flight servers.

**ADBC**  
- Open database by driver path or driver name (e.g. SQLite, PostgreSQL). Execute SQL and get an Arrow result stream.  
- Metadata APIs where the driver supports them: get_table_types, get_table_schema, get_objects.  
- Statement.bind for parameter binding where supported.  
- **Optional integration with the [`adbc`](https://hex.pm/packages/adbc) package:** use it to configure and download drivers (e.g. SQLite, PostgreSQL) on first use; ExArrow then opens the database and returns Arrow streams.  
- **`ExArrow.ADBC.DriverHelper.ensure_driver_and_open/2`:** one-step “ensure driver then open”: when the `adbc` package is present it calls `Adbc.download_driver/1`, then opens the database via `ExArrow.ADBC.Database.open/1`. When `adbc` is not installed, it skips the download step and opens with the inferred options. Returns `{:ok, db}` or `{:error, reason}` (no raises).

**Livebook tutorials**  
- Four notebooks in the repo: quick start (IPC, Flight, ADBC in one place), plus tutorials for IPC (stream vs file, read/write, schema, Explorer interop), Flight (echo server, client, list_flights, get_schema, actions), and ADBC (Database → Connection → Statement → Stream, metadata). Suitable for learning and for an introductory article.

**Explorer interop**  
- Move data between ExArrow and [Explorer](https://hex.pm/packages/explorer) via Arrow IPC: use `ExArrow.IPC.Writer.to_binary/2` (or `to_file/3`) and `Explorer.DataFrame.load_ipc_stream!/1` to get a dataframe from ExArrow streams (stream format); use `Explorer.DataFrame.dump_ipc_stream!/1` (stream format) and `ExArrow.IPC.Reader.from_binary/1` for the reverse. ExArrow handles streaming and protocols; Explorer handles in-memory analysis.

**Memory and scheduling**  
- Arrow data lives in native memory; no BEAM heap copy by default.  
- Long-running NIF work uses dirty schedulers so the BEAM is not blocked.

---

## Installation

```elixir
def deps do
  [{:ex_arrow, "~> 0.1.0"}]
end
```

Then `mix deps.get` and `mix compile`. The precompiled NIF is downloaded from GitHub releases. To build from source (e.g. unsupported platform), set `EX_ARROW_BUILD=1` and have Rust installed.

---

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for the full 0.1.0 entry.

---

## Feedback

Issues and discussions: [GitHub Issues](https://github.com/AnimaLogica/ex_arrow/issues).
