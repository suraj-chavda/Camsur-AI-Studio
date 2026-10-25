"""
Apply a single SQL migration file.

Usage:
  python scripts/run_migration.py sql/migrations/20260830_production_controls.sql
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    load_dotenv(ROOT / ".env")
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python scripts/run_migration.py <sql-file>")

    sql_path = Path(sys.argv[1])
    if not sql_path.is_absolute():
        sql_path = ROOT / sql_path
    if not sql_path.exists():
        raise SystemExit(f"Missing file: {sql_path}")

    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        raise SystemExit("Missing SUPABASE_DB_URL")

    sql = sql_path.read_text(encoding="utf-8")
    with psycopg.connect(db_url) as conn:
        conn.execute(sql)
        conn.commit()
    print(f"Applied {sql_path.name}")


if __name__ == "__main__":
    main()
