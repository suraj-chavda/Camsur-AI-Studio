"""
Apply sql/storage_policies.sql against Supabase Postgres.

Usage:
  python scripts/run_storage_policies.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
POLICY_FILE = ROOT / "sql" / "storage_policies.sql"


def main() -> None:
    load_dotenv(ROOT / ".env")
    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        raise SystemExit("Missing SUPABASE_DB_URL in .env")

    sql = POLICY_FILE.read_text(encoding="utf-8")
    with psycopg.connect(db_url) as conn:
        conn.execute(sql)
        conn.commit()
    print(f"Applied {POLICY_FILE.name}")


if __name__ == "__main__":
    main()
