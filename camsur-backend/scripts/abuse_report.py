"""
Abuse / power-user report (read-only).

Thin CLI wrapper over app.services.admin_analytics_service.AdminAnalyticsService.top_users
— the same numbers are also exposed via GET /admin/analytics/top-users in the admin panel.
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
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--top", type=int, default=20)
    args = parser.parse_args()

    analytics = AdminAnalyticsService(get_supabase(), get_settings())
    rows = analytics.top_users(args.days, limit=args.top)

    print(f"Period: last {args.days} day(s)")
    print("Top generators:")
    for row in rows:
        print(
            f"  {row['user_id']} gens={row['generations']} credits≈{row['credits_spent']} "
            f"fails={row['fails']} fail_rate={row['fail_rate_pct']}%"
        )


if __name__ == "__main__":
    main()
