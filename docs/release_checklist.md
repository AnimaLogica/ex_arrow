# Release checklist: Hex.pm with precompiled Rust NIFs

This document describes how to cut an **industry-standard Elixir release for [Hex.pm](https://hex.pm)** that ships **precompiled Rust NIFs** via [RustlerPrecompiled](https://hexdocs.pm/rustler_precompiled), so users get the native extension without a local Rust toolchain.

---

## One-time repository setup

Before the first release:

1. **GitHub Actions permissions**  
   **Settings → Actions → General → Workflow permissions** → select **Read and write permissions** so the Precompiled NIFs workflow can create releases and upload assets.

2. **Base URL for NIF downloads**  
   In `lib/ex_arrow/native.ex`, the `base_url` must point at the GitHub
   releases for this repo:

   `https://github.com/AnimaLogica/ex_arrow/releases/download/v#{version}`

3. **Hex.pm account**  
   Ensure you have publish rights for the package (e.g. `mix hex.organization auth hexpm` if publishing under an org).

---

## Release steps (repeat for each version)

Follow this order so the Hex package includes the **checksum file** and precompiled NIF tarballs are available at the URL the package expects.

### 1. Bump version and changelog

- In `mix.exs`, set `version` to the new version (e.g. `"0.1.0"`).
- Update `CHANGELOG.md` (or your changelog file) with the release date and changes for this version.
- Commit: e.g. `git add mix.exs CHANGELOG.md && git commit -m "Release v0.1.0"`.

### 2. Tag and push (triggers NIF builds)

- Create an annotated tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
- Push branch and tag: `git push origin main && git push origin v0.1.0`

Pushing the tag triggers the **Precompiled NIFs** workflow (`.github/workflows/precompiled_nifs.yml`), which builds the Rust crate for all configured targets and NIF versions and creates a **GitHub release** with the tarballs attached.

### 3. Wait for precompiled NIFs

- In GitHub: **Actions → Precompiled NIFs** → open the run for your tag.
- Wait until **all matrix jobs** and the **Create release** job succeed.
- Confirm the GitHub release contains the expected `.tar.gz` assets (e.g. Linux, macOS, Windows, multiple NIF versions).

### 4. Generate the checksum file (required for Hex)

RustlerPrecompiled requires a **checksum file** in the Hex package to verify downloaded NIFs. Generate it **after** the GitHub release has all assets:

```bash
mix rustler_precompiled.download ExArrow.Native --all --print > checksum-Elixir.ExArrow.Native.exs
```

- Confirm the map is non-empty (real `sha256:` digests for `vX.Y.Z` assets).
- The file is **gitignored** on purpose (see `.gitignore`) so an empty map
  cannot be committed by accident. Force-add the populated file:

```bash
git add -f checksum-Elixir.ExArrow.Native.exs
git commit -m "Add checksum for precompiled NIFs v0.1.0"
git push origin main
```

`mix.exs` already lists `checksum-*.exs` in `:files`, so Hex packages the
on-disk file even if you publish without committing — committing the
populated checksum is still preferred so the release branch matches Hex.

### 5. Publish to Hex.pm

- From a clean tree that includes the new version and the checksum file:
  ```bash
  mix hex.publish
  ```
- Follow the prompts. Optionally publish docs: `mix hex.docs publish` (or your project's usual flow).

### 6. Verify the published package

- Unpack and inspect what users will get:
  ```bash
  mix hex.build --unpack
  ```
- Confirm the unpacked package contains `lib/`, `checksum-Elixir.ExArrow.Native.exs`, and `native/ex_arrow_native/` (Cargo.toml, src, etc.). Consumers will run `mix deps.get` and `mix compile`; RustlerPrecompiled will fetch the right NIF from the GitHub release URL and verify it with the checksum.

### 7. Announce the release

- Update the release date in `CHANGELOG.md` (replace `TBD` with the actual date).
- Use the copy-paste text in `docs/release_announcement.md` for the Elixir Forum, Elixir Weekly, and similar outlets. Links should use `https://github.com/AnimaLogica/ex_arrow`.

---

## Versioning policy

- **Library version**: `ex_arrow` and native crate `ex_arrow_native` share the same version (e.g. `0.1.0`).
- **0.x series**: No breaking API changes within a minor line (`0.1.x`, `0.2.x`, ...). If a breaking change is unavoidable, keep the old API for at least one minor with deprecation warnings and document migration in the changelog (and an "Upgrade guide" if needed).

---

## CI and NIF notes

- **CI**: Elixir/OTP and Rust jobs run on push/PR; the Rust job uses `EX_ARROW_BUILD=1` so the NIF is built from source when no precompiled NIFs exist yet.
- **Elixir**: `~> 1.14` (see `mix.exs`). CI covers Elixir 1.18/OTP 27,
  1.19/OTP 28, and 1.20/OTP 29. **Rustler**: `~> 0.36 or ~> 0.38`
  (optional Elixir dep; Rust crate per `native/ex_arrow_native/Cargo.toml`).
- **NIF**: Default is to **download** a precompiled NIF from GitHub releases. To build from source (e.g. unsupported platform or dev), set `EX_ARROW_BUILD=1` and have Rust (and `rustler` as optional dep) available.
- Native code lives under `native/ex_arrow_native` (cdylib `ex_arrow_native`). Long-running NIF work uses **dirty schedulers** (`schedule = "DirtyIo"`).

---

## Compatibility notes

- **Apache Arrow / Flight**
  - `arrow`, `arrow-ipc`, `arrow-schema`, `arrow-array`, `arrow-flight`,
    `parquet`: version **59** (v0.9.0; previously 56).
- **ADBC**
  - `adbc_core` and `adbc_driver_manager`: version **0.24**.
- **BEAM**
  - Designed for Elixir `~> 1.14`; CI exercises Elixir 1.18/OTP 27,
    1.19/OTP 28, and 1.20/OTP 29.

Any upgrade of Arrow/ADBC crates should be done in a coordinated fashion and noted in the changelog, including any behavioral changes (e.g. Flight or ADBC metadata changes).

---

## API stability / deprecation

- Public Elixir modules under `ExArrow.*` (`Schema`, `RecordBatch`, `Array`, `Table`, `Stream`, `IPC`, `Flight`, `ADBC`) are considered **public API**.
- For `0.1.x`:
  - No breaking changes to function signatures or semantics without deprecation.
  - If a change is needed:
    - Introduce a new function or option and deprecate the old one.
    - Keep the old entry point for at least one minor (`0.1.x` → `0.2.x`).
    - Document the deprecation in the changelog and in the module docs.

---

## Known limitations

- **ADBC driver availability**
  - Integration tests are driver-dependent. When no driver is available, ADBC tests tagged `:adbc` **fail with a clear message** instead of being marked as skipped dynamically at runtime.
  - Use `mix test --exclude adbc` when no driver is installed.
  - ExArrow does not manage or download ADBC drivers itself. For higher-level
    driver configuration and optional download (e.g. in Livebook or apps that
    want automatic driver setup), consumers can add the separate
    [`adbc`](https://hex.pm/packages/adbc) package to their own project and use
    it to ensure drivers are available before calling `ExArrow.ADBC.Database.open/1`.
- **Driver feature coverage**
  - ADBC metadata APIs (`get_table_types/1`, `get_table_schema/3`, `get_objects/2`) and parameter binding (`Statement.bind/2`) are exposed, but actual support is **driver-dependent**. Some drivers may return `{:error, message}` for these calls.
- **Platform coverage**
  - Primary development and testing have been on macOS and Linux. Windows is not yet part of the CI matrix and may require additional work (e.g. MSVC toolchain, Arrow/ADBC build peculiarities).
- **Error mapping**
  - ADBC and NIF errors are currently surfaced as `{:error, message}` strings. `ExArrow.ADBC.Error` exists for wrapping/normalizing, but vendor-specific SQLSTATE/vendor_code parsing is not yet implemented.
- **Performance**
  - No formal latency/throughput guarantees; current focus is on correctness and keeping large Arrow buffers in native memory.

---

## Performance gate and how to run locally

Design for a lightweight performance/heap-allocation gate (to be wired into CI before a stable release):

- **Target path**: IPC roundtrip (encode + decode) for a moderately sized dataset, e.g. tens of thousands of rows and several columns.
- **Test shape**:
  - Tagged ExUnit test (e.g. `@tag :perf`) in `test/ex_arrow/ipc_perf_test.exs`.
  - Generate a representative `RecordBatch` or table in native memory.
  - Measure BEAM memory before and after the roundtrip using `:erlang.memory(:total)`.
  - Assert:
    - Runtime stays below a conservative threshold on CI hardware (e.g. `< 500 ms`).
    - Heap growth on the Elixir side is bounded and dominated by handles/metadata, not large buffer copies.
- **Local run**:
  - Once the perf test is added, run only the gate via:  
    `mix test --only perf`

For the **0.1.0** release, the above gate is a design requirement and should be implemented and added to the CI pipeline before promoting to a stable `0.2.x` or `1.x` line.
