# ExArrow 0.1.0 — Release notes and announcements

Copy-paste ready text for each channel. Links use `https://github.com/AnimaLogica/ex_arrow`; change if your repo is elsewhere.

Full release notes: [RELEASE_NOTES_0.1.0.md](RELEASE_NOTES_0.1.0.md).

---

## Elixir Forum (Announcements)

**Title:** ExArrow 0.1.0 – Apache Arrow for the BEAM (IPC, Flight, ADBC)

**Body:**

ExArrow 0.1.0 is now on Hex. It adds Apache Arrow support for Elixir/OTP: IPC (stream and file read/write), Arrow Flight (gRPC client and echo server), and ADBC (Arrow Database Connectivity) so you can run SQL and get Arrow result streams from drivers like SQLite and PostgreSQL.

Data stays in native Rust/Arrow buffers; Elixir uses opaque handles (Schema, RecordBatch, Stream). No Rust required for normal use: precompiled NIFs are shipped for Linux, macOS, and Windows via RustlerPrecompiled.

Use it for: ingesting Arrow IPC from pipelines, querying databases via ADBC and re-exporting to IPC or Flight, connecting to Flight-compatible services (e.g. Dremio, InfluxDB IOx), and interchanging Arrow files with Explorer, Python, or R.

Requirements: Elixir ~> 1.14 (OTP 25/26, NIF 2.15 and 2.16).

- Hex: https://hex.pm/packages/ex_arrow  
- Docs: https://hexdocs.pm/ex_arrow  
- GitHub: https://github.com/AnimaLogica/ex_arrow  

Feedback and issues welcome.

---

## Reddit — r/elixir

**Title:** ExArrow 0.1.0 – Apache Arrow on the BEAM (IPC, Flight, ADBC)

**Body:**

First release of ExArrow is on Hex. It brings Apache Arrow to Elixir: read/write IPC streams and files, Arrow Flight client and echo server (gRPC), and ADBC so you can run SQL and get Arrow result batches from SQLite, Postgres, etc. Data lives in native buffers; Elixir holds handles. Precompiled NIFs for Linux, macOS, and Windows so you don’t need Rust.

Good fit for data pipelines, ETL, talking to Flight services (Dremio, InfluxDB IOx), and swapping Arrow data with Explorer or Python/R. Elixir ~> 1.14, OTP 25+.

- https://hex.pm/packages/ex_arrow  
- https://hexdocs.pm/ex_arrow  
- https://github.com/AnimaLogica/ex_arrow  

---

## Reddit — r/programming (shorter)

**Title:** ExArrow 0.1.0 – Apache Arrow for Elixir/BEAM (IPC, Flight, ADBC)

**Body:**

ExArrow 0.1.0 is a new Elixir library for Apache Arrow: IPC stream/file read-write, Arrow Flight (gRPC) client and server, and ADBC for SQL-to-Arrow result streams. Data stays in native memory; precompiled NIFs so no Rust toolchain needed. Elixir ~> 1.14.

https://hex.pm/packages/ex_arrow | https://github.com/AnimaLogica/ex_arrow

---

## Newsletter (e.g. Elixir Weekly)

**Subject line:** ExArrow 0.1.0 — Apache Arrow for the BEAM (IPC, Flight, ADBC)

**Blurb:**

ExArrow 0.1.0 is on Hex. Apache Arrow support for Elixir: IPC (stream and file), Arrow Flight (client and echo server), and ADBC for Arrow-native database results. Data in native buffers; precompiled NIFs for Linux, macOS, Windows. Elixir ~> 1.14, OTP 25+. [Hex](https://hex.pm/packages/ex_arrow) | [Docs](https://hexdocs.pm/ex_arrow) | [GitHub](https://github.com/AnimaLogica/ex_arrow)

---

## One-liner (tweet / Mastodon / slack)

ExArrow 0.1.0 is on Hex: Apache Arrow for the BEAM (IPC, Flight, ADBC). Precompiled NIFs, no Rust needed. https://hex.pm/packages/ex_arrow

---

## GitHub Release (description)

Use the first two paragraphs of [RELEASE_NOTES_0.1.0.md](RELEASE_NOTES_0.1.0.md) (Summary + What's included), then add:

**Installation:** `{:ex_arrow, "~> 0.1.0"}` — then `mix deps.get` and `mix compile`.

**Links:** [Hex](https://hex.pm/packages/ex_arrow) | [Docs](https://hexdocs.pm/ex_arrow) | [GitHub](https://github.com/AnimaLogica/ex_arrow)
