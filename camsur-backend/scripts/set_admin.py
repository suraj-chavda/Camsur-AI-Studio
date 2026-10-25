"""
Grant or revoke admin-panel access for a user.

Usage:
  python scripts/set_admin.py --email you@example.com
  python scripts/set_admin.py --email you@example.com --revoke
  python scripts/set_admin.py --user-id <uuid>
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.db.supabase import get_supabase  # noqa: E402


def find_user_id(db, email: str | None, user_id: str | None) -> str:
    if user_id:
        return user_id
    if not email:
        raise SystemExit("Provide --email or --user-id")

    result = db.table("users").select("id").eq("email", email).limit(1).execute()
    if not result.data:
        raise SystemExit(f"No user found with email: {email}")
    return result.data[0]["id"]


def main() -> None:
    parser = argparse.ArgumentParser(description="Grant/revoke Camsur admin-panel access")
    parser.add_argument("--email", help="User email")
    parser.add_argument("--user-id", help="User UUID")
    parser.add_argument("--revoke", action="store_true", help="Revoke admin (set role=user)")
    args = parser.parse_args()

    db = get_supabase()
    user_id = find_user_id(db, args.email, args.user_id)
    role = "user" if args.revoke else "admin"

    result = (
        db.table("users").update({"role": role}).eq("id", user_id).execute()
    )
    if not result.data:
        raise SystemExit(f"No user found with id: {user_id}")

    print(f"{result.data[0]['email']} ({user_id}) role is now: {role}")


if __name__ == "__main__":
    main()
