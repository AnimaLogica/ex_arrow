#!/usr/bin/env python3
"""Generate the checked-in hive-partitioned Parquet fixture for ExArrow tests.

Requires: pip install pyarrow

Usage (from repo root):

    python3 script/generate_hive_events_fixture.py

Writes under test/fixtures/hive_events/ with Hive layout:

    year=YYYY/month=MM/part-0.parquet

Columns in each file: id (int64), amount (float64), account_id (utf8).
Partition keys live only in the path (not in the file schema).
"""

from __future__ import annotations

import shutil
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

ROOT = Path(__file__).resolve().parents[1] / "test" / "fixtures" / "hive_events"

# (year, month, rows) — rows are (id, amount, account_id)
PARTS = [
    (2025, 12, [(1, 10.0, "a"), (2, 0.0, "b")]),
    (2026, 1, [(3, 25.5, "a"), (4, 0.0, "c"), (5, 100.0, "a")]),
    (2026, 2, [(6, 50.0, "b"), (7, -1.0, "a")]),
]


def main() -> None:
    if ROOT.exists():
        shutil.rmtree(ROOT)

    for year, month, rows in PARTS:
        table = pa.table(
            {
                "id": pa.array([r[0] for r in rows], type=pa.int64()),
                "amount": pa.array([r[1] for r in rows], type=pa.float64()),
                "account_id": pa.array([r[2] for r in rows], type=pa.string()),
            }
        )
        dest = ROOT / f"year={year}" / f"month={month:02d}"
        dest.mkdir(parents=True, exist_ok=True)
        path = dest / "part-0.parquet"
        # Force multiple row groups when there are enough rows (stats pruning).
        row_group_size = 2 if len(rows) > 2 else max(len(rows), 1)
        pq.write_table(table, path, row_group_size=row_group_size, compression="snappy")
        meta = pq.read_metadata(path)
        print(f"wrote {path} rows={meta.num_rows} row_groups={meta.num_row_groups}")


if __name__ == "__main__":
    main()
