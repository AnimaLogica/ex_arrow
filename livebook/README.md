# ExArrow Livebooks

Tutorial notebooks for the **ex_arrow** library, suitable for an introductory Medium article or self-paced learning.

## Notebooks

| File | Purpose |
|------|---------|
| **00_quickstart.livemd** | Get something running in minutes: IPC read/write, Flight echo client/server, ADBC SQLite query, Explorer/Nx interchange, and v0.7.0 streaming pipelines. |
| **01_ipc.livemd** | IPC deep dive: stream vs file format, reading from binary/file, writing, schema and types, optional Explorer interop. |
| **02_flight.livemd** | Arrow Flight: echo server, client, do_put/do_get, list_flights, get_flight_info, get_schema, actions, Flight SQL prepared statements. |
| **03_adbc.livemd** | ADBC: `:adbc_package` backend, Database → Connection → Statement → Stream, metadata APIs (native driver), Explorer roundtrip. |
| **04_adbc_integration.livemd** | **adbc_package** backend with connection pooling (NimblePool), concurrent queries. |
| **05_parquet.livemd** | v0.8 Parquet pushdown, compressed write, multi-file directory, IPC file writer (PyArrow side-by-side). |
| **06_datasets.livemd** | v0.9 Dataset / Scanner: Hive open, Expression filters, prune stats (PyArrow `dataset` side-by-side). |

Together they demonstrate ExArrow functionality: IPC (stream + file), Flight (client + server + Flight SQL), ADBC (Arrow result streams), Parquet pushdown/multi-file, Datasets/Scanners, and the pipeline DSL (`ExArrow.Stream`, `ExArrow.Batch`, `ExArrow.Pipeline`, telemetry).

## How to run

1. Install [Livebook](https://livebook.dev) or run `mix livebook.server` from a project that depends on `ex_arrow`.
2. Open notebooks from this repo’s **`livebook/`** directory (File → Open) so the setup cell can find a local checkout when developing.
3. Run the **first cell** in each notebook (`Mix.install`).  It installs Hex packages and, when opened from the repo, builds `ex_arrow` from source (requires **Rust**).
4. Run remaining cells in order.

### Setup cell behaviour

| Where you open the notebook | `ex_arrow` source |
|----------------------------|-------------------|
| From `livebook/` in a git clone | Local path + `EX_ARROW_BUILD=1` (compile NIF from Rust) |
| From Livebook autosave or elsewhere | Hex `~> 0.9.0` (precompiled NIF, no Rust) |

### ADBC in Livebook

Notebooks **00**, **03**, and **04** use the [`adbc`](https://hex.pm/packages/adbc) package to download the SQLite driver.  Tutorials **03** and **04** use ExArrow’s **`:adbc_package`** backend so you get `ExArrow.Stream` results **without** a native ADBC `.dylib`.

For production deployments with a native C driver (PostgreSQL, DuckDB, etc.), see [Installing an ADBC driver](INSTALL_ADBC_DRIVER.md) and the [ADBC guide on HexDocs](https://ex-arrow.hexdocs.pm/adbc_guide.html). Package overview: [ex-arrow.hexdocs.pm](https://ex-arrow.hexdocs.pm).

### Local development tips

- If autosaved notebooks fall back to Hex but you want local source, reopen the file from `livebook/` in the repo or set `EX_ARROW_BUILD=1` and use a path dependency manually (see commented block in each setup cell).
- First local NIF build takes 1–2 minutes; later runs use the cache.
