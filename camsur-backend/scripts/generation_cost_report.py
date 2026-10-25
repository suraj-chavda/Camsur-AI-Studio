"""
Generation / credit cost report for FinOps.

Thin CLI wrapper over app.services.admin_analytics_service.AdminAnalyticsService
and app.services.margin_monitor_service.MarginMonitorService — the same numbers
are also exposed via the admin panel (GET /admin/analytics/overview,
GET /admin/analytics/margin).

Usage:
  python scripts/generation_cost_report.py --days 1
  python scripts/generation_cost_report.py --days 7
  python scripts/generation_cost_report.py --days 30
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
from app.services.margin_monitor_service import MarginMonitorService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=7)
    args = parser.parse_args()

    settings = get_settings()
    db = get_supabase()
    analytics = AdminAnalyticsService(db, settings)
    summary = analytics.usage_summary(args.days)

    print(f"Period: last {summary['period_days']} day(s)")
    print(f"Generations: {summary['generations_total']}")
    print(f"Successful (completed): {summary['by_status'].get('completed', 0)}")
    print(f"Failed: {summary['by_status'].get('failed', 0)}")
    print(f"Refunded: {summary['by_status'].get('refunded', 0)}")
    print(f"Credits charged (spend txs): {summary['credits_spent']}")
    print(f"Credits refunded: {summary['credits_refunded']}")
    print(f"Net credits: {summary['net_credits']}")
    print(
        f"Real provider cost USD (recorded on {summary['generations_with_cost_recorded']} "
        f"generation(s), completed + submitted-but-failed): {summary['real_provider_cost_usd']}"
    )
    print("By tool:")
    for tool, count in summary["by_tool"].items():
        print(f"  {tool}: {count}")

    print(f"\nPer-tool margin (trailing {settings.margin_monitor_window_days}d window, report-only):")
    monitor = MarginMonitorService(db, settings)
    for snapshot in monitor.evaluate():
        flag = {
            "disabled": "WOULD DISABLE (loss)",
            "already_disabled": "disabled",
            "insufficient_samples": "insufficient data",
            "none": "ok",
        }[snapshot.action_taken]
        suggestion = (
            f" suggested_credit_cost={snapshot.suggested_credit_cost}"
            if snapshot.suggested_credit_cost is not None
            else ""
        )
        print(
            f"  {snapshot.tool_slug:20} margin=${snapshot.margin_usd:>8} "
            f"revenue=${snapshot.revenue_usd:>8} cost=${snapshot.provider_cost_usd:>8} "
            f"[{flag}]{suggestion}"
        )


if __name__ == "__main__":
    main()
