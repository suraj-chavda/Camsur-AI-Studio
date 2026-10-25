"""
Unit tests for MarginMonitorService using a minimal fake Supabase client —
no live DB required (matches this repo's "no live Supabase for unit tests" rule).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from app.config import Settings
from app.services.margin_monitor_service import MarginMonitorService

NOW = datetime.now(timezone.utc).isoformat()


@dataclass
class _Result:
    data: list | None = None


class _Query:
    def __init__(self, rows: list[dict]):
        self.rows = list(rows)

    def select(self, *_a, **_k):
        return self

    def eq(self, field, value):
        self.rows = [r for r in self.rows if r.get(field) == value]
        return self

    def gte(self, field, value):
        self.rows = [r for r in self.rows if r.get(field) is not None and str(r[field]) >= str(value)]
        return self

    def in_(self, field, values):
        self.rows = [r for r in self.rows if r.get(field) in values]
        return self

    def order(self, *_a, **_k):
        return self

    def limit(self, n):
        self.rows = self.rows[:n]
        return self

    def execute(self):
        return _Result(data=self.rows)


class _UpdateQuery:
    def __init__(self, db: "FakeDb", table: str, payload: dict):
        self.db = db
        self.table = table
        self.payload = payload
        self.filters: dict = {}

    def eq(self, field, value):
        self.filters[field] = value
        return self

    def execute(self):
        matched = []
        for row in self.db.tables.get(self.table, []):
            if all(row.get(k) == v for k, v in self.filters.items()):
                row.update(self.payload)
                matched.append(row)
        self.db.updates.append((self.table, dict(self.payload), dict(self.filters)))
        return _Result(data=matched)


class _InsertQuery:
    def __init__(self, db: "FakeDb", table: str, payload: dict):
        self.db = db
        self.table = table
        self.payload = payload

    def execute(self):
        self.db.inserts.append((self.table, dict(self.payload)))
        return _Result(data=[self.payload])


class _TableProxy:
    def __init__(self, db: "FakeDb", name: str):
        self.db = db
        self.name = name

    def select(self, *_a, **_k):
        return _Query(self.db.tables.get(self.name, []))

    def update(self, payload):
        return _UpdateQuery(self.db, self.name, payload)

    def insert(self, payload):
        return _InsertQuery(self.db, self.name, payload)


class FakeDb:
    def __init__(self, tables: dict[str, list[dict]]):
        self.tables = {name: [dict(r) for r in rows] for name, rows in tables.items()}
        self.inserts: list = []
        self.updates: list = []

    def table(self, name):
        return _TableProxy(self, name)


def _settings() -> Settings:
    return Settings(margin_monitor_window_days=7, margin_monitor_min_samples=3)


def _base_tables(tool_slug: str, *, is_active: bool, gens_cost: list[str], spend_credits: int):
    return {
        "tools": [{"slug": tool_slug, "is_active": is_active}],
        "generations": [
            {"tool_slug": tool_slug, "created_at": NOW, "provider_cost_usd": cost}
            for cost in gens_cost
        ],
        "credit_transactions": [
            {"tool_slug": tool_slug, "type": "spend", "amount": -spend_credits, "created_at": NOW}
        ],
        # $0.01 / credit blended rate: 100 cents for 100 credits.
        "credit_purchases": [
            {"status": "completed", "price_amount_cents": 100, "credits": 100, "created_at": NOW}
        ],
        "credit_settings": [{"min_gross_margin_bps": 2000}],
        "credit_packages": [],
    }


def test_losing_tool_gets_disabled():
    tables = _base_tables(
        "headshot", is_active=True, gens_cost=["5.00", "5.00", "5.00"], spend_credits=45
    )
    db = FakeDb(tables)
    monitor = MarginMonitorService(db, _settings())

    snapshots = monitor.recompute_and_enforce()

    snap = next(s for s in snapshots if s.tool_slug == "headshot")
    assert snap.margin_usd < 0
    assert snap.action_taken == "disabled"
    assert db.tables["tools"][0]["is_active"] is False
    assert db.tables["tools"][0]["disabled_reason"] == "auto_margin_breaker"
    assert len(db.inserts) == 1  # audit snapshot row


def test_profitable_tool_stays_active():
    # $0.001 real cost per gen vs $0.01/credit * 45 credits = $0.45 revenue — healthy margin.
    tables = _base_tables(
        "headshot", is_active=True, gens_cost=["0.001", "0.001", "0.001"], spend_credits=45
    )
    db = FakeDb(tables)
    monitor = MarginMonitorService(db, _settings())

    snapshots = monitor.recompute_and_enforce()

    snap = next(s for s in snapshots if s.tool_slug == "headshot")
    assert snap.margin_usd > 0
    assert snap.action_taken == "none"
    assert db.tables["tools"][0]["is_active"] is True


def test_insufficient_samples_does_not_trip():
    tables = _base_tables("headshot", is_active=True, gens_cost=["5.00"], spend_credits=15)
    db = FakeDb(tables)
    monitor = MarginMonitorService(db, _settings())

    snapshots = monitor.recompute_and_enforce()

    snap = next(s for s in snapshots if s.tool_slug == "headshot")
    assert snap.action_taken == "insufficient_samples"
    assert db.tables["tools"][0]["is_active"] is True


def test_already_disabled_tool_is_not_touched_again():
    tables = _base_tables(
        "headshot", is_active=False, gens_cost=["5.00", "5.00", "5.00"], spend_credits=45
    )
    db = FakeDb(tables)
    monitor = MarginMonitorService(db, _settings())

    snapshots = monitor.recompute_and_enforce()

    snap = next(s for s in snapshots if s.tool_slug == "headshot")
    assert snap.action_taken == "already_disabled"
    assert db.updates == []  # no redundant update issued
