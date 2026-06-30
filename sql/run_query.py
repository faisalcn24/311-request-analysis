"""
Tiny runner so each .sql file stays a real, executable artifact (queries are
never inlined in Python). Loads a .sql file, runs it against nyc_311.db, and
prints the result.

Run:  & .\.venv\Scripts\python.exe sql\run_query.py sql\01_median_by_complaint_type.sql
"""
import sqlite3
import sys
from pathlib import Path

import pandas as pd

DB = Path(__file__).resolve().parent.parent / "nyc_311.db"

sql = Path(sys.argv[1]).read_text(encoding="utf-8")
with sqlite3.connect(DB) as conn:
    df = pd.read_sql_query(sql, conn)

print(df.to_string(index=False))
print(f"\n({len(df)} rows)")
