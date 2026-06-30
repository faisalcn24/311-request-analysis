"""
Phase 2 loader: cleaned Parquet -> SQLite (nyc_311.db).

Why this exists: the SQL layer is the analysis engine for Phase 2. We load the
committed Parquet into a local SQLite DB (rebuildable, gitignored) so every
business question can live in its own .sql file (never inlined in Python).

We load only the 9 columns the queries need -- this keeps the DB small/fast and
drops the heavy free-text `resolution_description` (already encoded as
`resolution_category` during cleaning) and unused `descriptor`/`incident_zip`.

Run:  & .\.venv\Scripts\python.exe sql\00_load_to_sqlite.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
PARQUET = ROOT / "data" / "311_cleaned_2024.parquet"
DB = ROOT / "nyc_311.db"

# Columns the SQL layer needs. created/closed kept for month + open-rate logic.
COLS = [
    "unique_key", "created_date", "closed_date", "agency", "complaint_type",
    "borough", "status", "resolution_time_hours", "resolution_category",
]

print(f"Reading {PARQUET.name} ...")
df = pd.read_parquet(PARQUET, columns=COLS)
# category -> str so SQLite stores plain text (not the integer codes).
for c in df.select_dtypes("category").columns:
    df[c] = df[c].astype(str)
print(f"  {len(df):,} rows, {len(df.columns)} cols")

print(f"Writing {DB.name} ...")
with sqlite3.connect(DB) as conn:
    df.to_sql("tickets", conn, if_exists="replace", index=False,
              chunksize=100_000)
    # Indexes for the group-by / order-by dimensions the queries hit most.
    cur = conn.cursor()
    for col in ("complaint_type", "agency", "borough", "resolution_time_hours"):
        cur.execute(f"CREATE INDEX idx_tickets_{col} ON tickets({col});")
    conn.commit()

    n = cur.execute("SELECT COUNT(*) FROM tickets;").fetchone()[0]
    # Sanity: confirm the row count survived the round-trip and dates are
    # strftime-readable (month extraction is used by the seasonality query).
    sample_month = cur.execute(
        "SELECT strftime('%Y-%m', created_date) FROM tickets LIMIT 1;"
    ).fetchone()[0]

print(f"Loaded {n:,} rows into 'tickets'. "
      f"created_date month parses as: {sample_month}")
