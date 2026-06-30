# SQL Layer — NYC 311 (2024)

Phase 2 of the project. The cleaned Parquet is loaded into a local SQLite database
(`nyc_311.db`, gitignored — rebuildable) and every business question lives in its own
commented `.sql` file. Queries are **never** inlined in Python.

## How to run

```powershell
$py = ".\.venv\Scripts\python.exe"

# 1. Build the DB from the committed Parquet (one-off, ~1 min)
& $py sql\00_load_to_sqlite.py

# 2. Run any query and print it as a table
& $py sql\run_query.py sql\01_median_by_complaint_type.sql
```

`00_load_to_sqlite.py` loads the 9 columns the queries need into a `tickets` table and
indexes the group-by dimensions. `run_query.py` is a ~25-line helper that executes a
`.sql` file and prints the result — it keeps the SQL in `.sql` files while still being
runnable.

## The queries

Built around the analysis framing (see `report/analysis_decisions.md`): **median-first**,
**complaint type + agency are the signal / borough is a caveated slicer**, **seasonality
is per-type**, and **speed is always paired with effectiveness**.

| File | Question | Headline finding |
|---|---|---|
| `01_median_by_complaint_type.sql` | Which complaint types resolve slowest (by median)? | Long-cycle Parks/inspection types dominate; *New Tree Request* sits on the 290-day cap (labeled `>290 days (long-cycle)`). |
| `02_speed_vs_effectiveness_by_agency.sql` | Who closes fast but fixes little? | Separates median speed from the substantive (`Action/Enforcement`) rate — NYPD-style fast closes vs HPD-style slower-but-substantive. |
| `03_monthly_volume_by_complaint_type.sql` | When does demand spike, for what? | Seasonality is per-type: Heat/Hot Water peaks in Dec (index ~285), Noise in summer — they cancel out in aggregate. |
| `04_open_rate_by_complaint_type.sql` | Which types build a backlog? | % still open, keyed on the **null close date** (not `status`), since 27.5k tickets are `Closed` with no timestamp. |
| `05_resolution_time_distribution.sql` | What does the spread look like? | ~25% of closes happen in <1h alongside a long multi-week tail — the evidence for leading with the median. |
| `06_borough_within_complaint_type.sql` | Is any borough really slower? | **No — it's a composition artifact.** Bronx is slowest overall yet *fastest* for Heat/Hot Water. Borough-within-type shown next to borough-overall. |

## SQL techniques demonstrated

- **Window functions** — median via `ROW_NUMBER()/COUNT() OVER (PARTITION BY ...)` (SQLite
  has no `MEDIAN()`); seasonality index via `AVG() OVER (PARTITION BY ...)`;
  percent-of-total via `SUM(COUNT(*)) OVER ()`.
- **JOIN** — stitching per-group medians to aggregates (01, 02) and borough-within-type to
  borough-overall (06).
- **GROUP BY + conditional aggregation** — substantive / no-fix / open rates via
  `SUM(CASE WHEN ...)`.
- **CTEs** throughout for readability; `HAVING` volume thresholds to suppress noisy small
  categories.
