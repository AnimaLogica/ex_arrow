# ExArrow 0.9.0 — Release notes

**Release date:** 2026-09-13  
**Package:** [Hex](https://hex.pm/packages/ex_arrow) | **Docs:** [ex-arrow.hexdocs.pm](https://ex-arrow.hexdocs.pm) | **Source:** [GitHub](https://github.com/thanos/ex_arrow)

---

## Summary

ExArrow 0.9.0 finishes the Dataset half of the original roadmap: discover
Hive-partitioned Parquet (and IPC) trees, filter with a first-class
`Compute.Expression` AST, and scan through a three-level pushdown ladder —
partition prune → Parquet row-group pushdown → residual `Compute.filter/2`.

v0.8.0 Parquet pushdown on a single file or path list remains; Dataset
generalises that into discovered, partitioned layouts with exact
`Scanner.stats/1` for verifying what was pruned.

**Requirements:** Elixir ~> 1.14 (CI covers 1.18/OTP 27, 1.19/OTP 28,
1.20/OTP 29). Native stack: arrow-rs / parquet / Flight **59.3.0**.

---

## What's included

**Dataset discovery**  
- `ExArrow.Dataset.open/2` over a directory, file, glob, or path list.  
- Hive partitioning with typed keys (`{:hive, schema: [...]}`).  
- `ExArrow.Dataset.Fragment` with path, format, size, `partition_values`.  
- `ExArrow.FileSystem.Local` and `Memory` backends.

**Scanner**  
- `Dataset.scanner/2` + `Scanner.to_stream/1` (`:dataset` stream backend).  
- Options: `:columns`, `:filter` (`Expression` or legacy tuple), `:batch_size`.  
- `Scanner.stats/1` — exact fragment / row-group counts; closed stream →
  `{:error, "stream is closed"}`.

**Expressions and residual filter**  
- `ExArrow.Compute.Expression` builders, `validate/2`, `to_parquet_filters/1`.  
- `Compute.filter/2` / `Batch.filter/2` evaluate residuals after decode.  
- Int→Float64/Float32 casts reject non-representable literals.

**Ergonomics**  
- `RecordBatch.from_lists/1`, `from_map/1`.

**Docs**  
- [Datasets guide](../guides/11_datasets.md), `livebook/06_datasets.livemd`,
  `bench/dataset_scan_bench.exs`, checked-in PyArrow Hive fixture.

---

## Installation

```elixir
def deps do
  [{:ex_arrow, "~> 0.9.0"}]
end
```

Precompiled NIFs download from GitHub releases after the `v0.9.0` tag assets
are published. To build from source: `EX_ARROW_BUILD=1 mix compile`.

---

## Out of scope (deferred)

Dataset writes, object-store filesystems, CSV/JSON fragments, `expr do`
macro sugar, page-level Parquet filtering, full compute catalog / aggregates,
and the core Arrow model release.

---

## Changelog

See [CHANGELOG.md](https://github.com/thanos/ex_arrow/blob/v0.9.0/CHANGELOG.md) for the full 0.9.0 entry.

---

## Feedback

Issues and discussions: [GitHub Issues](https://github.com/thanos/ex_arrow/issues).
