"""
Run sql/schema.sql directly against Supabase Postgres.

Required .env value:
  SUPABASE_DB_URL=postgresql://postgres.<project-ref>:<password>@aws-...pooler.supabase.com:6543/postgres

Get it from Supabase:
  Project Settings -> Database -> Connection string -> Transaction pooler
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from urllib.parse import urlparse

import psycopg
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_FILE = ROOT / "sql" / "schema.sql"


def main() -> None:
    load_dotenv(ROOT / ".env")

    db_url = os.getenv("SUPABASE_DB_URL")
    if not db_url:
        raise SystemExit(
            "Missing SUPABASE_DB_URL in .env.\n"
            "Copy it from Supabase -> Project Settings -> Database -> "
            "Connection string -> Transaction pooler."
        )

    _validate_db_url(db_url)

    sql = SCHEMA_FILE.read_text(encoding="utf-8")

    try:
        with psycopg.connect(db_url, autocommit=True) as conn:
            with conn.cursor() as cur:
                cur.execute(sql)
    except Exception as exc:
        raise SystemExit(f"Failed to run schema: {exc}") from exc

    print(f"Schema applied from {SCHEMA_FILE}")


def _validate_db_url(db_url: str) -> None:
    if "[YOUR-PASSWORD]" in db_url or "your-db-password" in db_url:
        raise SystemExit("SUPABASE_DB_URL still contains the password placeholder.")

    if "..." in db_url:
        raise SystemExit(
            "SUPABASE_DB_URL contains '...' in the host.\n"
            "Copy the full Transaction pooler URI from Supabase instead of the shortened UI text."
        )

    parsed = urlparse(db_url)
    if parsed.scheme not in {"postgresql", "postgres"} or not parsed.hostname:
        raise SystemExit("SUPABASE_DB_URL is not a valid Postgres URI.")


if __name__ == "__main__":
    sys.exit(main())
