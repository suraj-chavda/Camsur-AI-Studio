"""
Reconcile credit_accounts.balance vs ledger sum.

Thin CLI wrapper over app.services.admin_analytics_service.AdminAnalyticsService.ledger_health
— the same check is also exposed via GET /admin/health/ledger in the admin panel.
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
from app.services.admin_analytics_service import AdminAnalyticsService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=500)
    args = parser.parse_args()

    analytics = AdminAnalyticsService(get_supabase(), get_settings())
    health = analytics.ledger_health(limit=args.limit)

    for mismatch in health["mismatches"]:
        print(
            f"MISMATCH user={mismatch['user_id']} balance={mismatch['balance']} "
            f"ledger_sum={mismatch['ledger_sum']}"
        )

    print(f"Checked: {health['checked']} Mismatches: {len(health['mismatches'])}")


if __name__ == "__main__":
    main()
