"""
Grant credits to a user for manual development/admin top-ups.

Usage:
  python scripts/grant_credits.py --email user@example.com --amount 100
  python scripts/grant_credits.py --user-id <uuid> --amount 100 --reason support_adjustment
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.db.supabase import get_supabase  # noqa: E402
from app.services.credit_service import CreditService  # noqa: E402


def find_user_id(email: str | None, user_id: str | None) -> str:
    if user_id:
        return user_id
    if not email:
        raise SystemExit("Provide --email or --user-id")

    db = get_supabase()
    result = (
        db.table("users")
        .select("id")
        .eq("email", email)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise SystemExit(f"No user found with email: {email}")
    return result.data[0]["id"]


async def main() -> None:
    parser = argparse.ArgumentParser(description="Grant credits to a Camsur user")
    parser.add_argument("--email", help="User email to top up")
    parser.add_argument("--user-id", help="User UUID to top up")
    parser.add_argument("--amount", type=int, required=True, help="Positive credit amount")
    parser.add_argument("--reason", default="manual_topup", help="Ledger reason")
    parser.add_argument("--idempotency-key", help="Optional external/manual idempotency key")
    args = parser.parse_args()

    if args.amount <= 0:
        raise SystemExit("--amount must be positive")

    user_id = find_user_id(args.email, args.user_id)
    service = CreditService(get_supabase())
    tx = await service.grant_manual(
        user_id=user_id,
        amount=args.amount,
        reason=args.reason,
        idempotency_key=args.idempotency_key,
        metadata={"source": "grant_credits.py", "email": args.email},
    )
    balance = await service.get_balance(user_id)

    print(f"Granted {args.amount} credit(s) to {user_id}")
    print(f"Transaction: {tx.id}")
    print(f"New balance: {balance.balance}")


if __name__ == "__main__":
    asyncio.run(main())
