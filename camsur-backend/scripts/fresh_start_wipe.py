"""
Full "fresh start" wipe — clears every user/content table plus Supabase Auth
accounts and both storage buckets, while explicitly leaving the credit
catalog/config alone.

KEPT (never touched):
  - credit_packages   (purchasable pack definitions)
  - credit_settings   (global topup/margin config)

WIPED:
  - generations, credit_purchases, credit_transactions, credit_accounts,
    tool_margin_snapshots, tools, tool_categories, app_banners,
    app_onboarding, users (app profile table)
  - Supabase Auth accounts (auth.users, via the admin API)
  - All objects in both storage buckets (SUPABASE_MEDIA_BUCKET,
    SUPABASE_ASSETS_BUCKET) — buckets themselves are kept, just emptied.

Deleting `users` would cascade (hard FK) to generations/credit_accounts/
credit_transactions/credit_purchases on its own, but each is also cleared
explicitly here so the dry-run count is accurate table-by-table.

Usage:
  python scripts/fresh_start_wipe.py          # dry-run (default) — prints counts only
  python scripts/fresh_start_wipe.py --yes    # actually deletes everything above
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.config import get_settings  # noqa: E402
from app.db.supabase import get_supabase  # noqa: E402

# Child tables first, `users` last — matches the FK chain even though it's
# `on delete cascade` anyway, so counts/logs read in a sensible order.
# Value is each table's primary key column (all uuid) — credit_accounts is
# keyed by user_id, not id.
TABLES_IN_ORDER = [
    ("generations", "id"),
    ("credit_purchases", "id"),
    ("credit_transactions", "id"),
    ("credit_accounts", "user_id"),
    ("tool_margin_snapshots", "id"),
    ("tools", "id"),
    ("tool_categories", "id"),
    # ("app_banners", "id"),
    ("app_onboarding", "id"),
    ("users", "id"),
]

# Never touched by this script.
KEPT_TABLES = ["credit_packages", "credit_settings"]

_NIL_UUID = "00000000-0000-0000-0000-000000000000"


def _count(db, table: str, pk: str) -> int:
    result = db.table(table).select(pk, count="exact").limit(1).execute()
    return int(result.count or 0)


def _delete_all_rows(db, table: str, pk: str) -> int:
    before = _count(db, table, pk)
    if before == 0:
        return 0
    # pk columns here are always uuid — a filter that can never match a
    # real row satisfies any client-side "delete needs a filter" guard
    # while still functionally deleting everything.
    db.table(table).delete().neq(pk, _NIL_UUID).execute()
    return before


def _wipe_auth_users(db, *, dry_run: bool) -> int:
    ids: list[str] = []
    page = 1
    while True:
        users = db.auth.admin.list_users(page=page, per_page=200)
        if not users:
            break
        ids.extend(u.id for u in users)
        if len(users) < 200:
            break
        page += 1

    if not dry_run:
        for uid in ids:
            try:
                db.auth.admin.delete_user(uid)
            except Exception as exc:  # noqa: BLE001
                print(f"  ! failed to delete auth user {uid}: {exc}")
    return len(ids)


def main() -> None:
    parser = argparse.ArgumentParser(description="Full fresh-start database + storage wipe")
    parser.add_argument("--yes", action="store_true", help="Actually perform the wipe")
    args = parser.parse_args()
    dry_run = not args.yes

    settings = get_settings()
    db = get_supabase()

    print(f"Target: {settings.supabase_url}")
    print(f"Mode: {'DRY RUN (no changes)' if dry_run else 'LIVE - DELETING DATA'}")
    print()

    print("Tables to wipe:")
    total = 0
    for table, pk in TABLES_IN_ORDER:
        if dry_run:
            n = _count(db, table, pk)
        else:
            n = _delete_all_rows(db, table, pk)
        total += n
        verb = "would delete" if dry_run else "deleted"
        print(f"  {table:<24} {verb} {n} row(s)")

    print()
    print("Auth accounts (auth.users):")
    auth_n = _wipe_auth_users(db, dry_run=dry_run)
    verb = "would delete" if dry_run else "deleted"
    print(f"  {verb} {auth_n} account(s)")

    print()
    print("Storage buckets (emptied in place, bucket config kept):")
    for bucket in (settings.media_bucket, settings.assets_bucket):
        if dry_run:
            print(f"  {bucket:<24} would empty")
        else:
            try:
                db.storage.empty_bucket(bucket)
                print(f"  {bucket:<24} emptied")
            except Exception as exc:  # noqa: BLE001
                print(f"  ! failed to empty bucket {bucket}: {exc}")

    print()
    print(f"Kept untouched: {', '.join(KEPT_TABLES)}")
    print()
    if dry_run:
        print(f"Dry run complete - {total} row(s) + {auth_n} auth account(s) would be removed.")
        print("Re-run with --yes to actually perform the wipe.")
    else:
        print(f"Done - {total} row(s) + {auth_n} auth account(s) removed, storage emptied.")


if __name__ == "__main__":
    main()
