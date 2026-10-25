from app.core.credits import CreditMathError, calculate_credit_cost, ceil_credits
import pytest


@pytest.mark.parametrize(
    "raw,expected",
    [
        (10, 10),
        (10.0, 10),
        (10.01, 11),
        (10.49, 11),
        (10.50, 11),
        (10.99, 11),
        (0, 0),
        ("15", 15),
    ],
)
def test_ceil_credits(raw, expected):
    assert ceil_credits(raw) == expected


@pytest.mark.parametrize("raw", [-1, float("nan"), float("inf"), True])
def test_ceil_credits_rejects_bad(raw):
    with pytest.raises(CreditMathError):
        ceil_credits(raw)


def test_calculate_credit_cost_preserves_tool_prices():
    assert calculate_credit_cost(tool_credit_cost=15) == 15
    assert calculate_credit_cost(tool_credit_cost=10) == 10
    assert calculate_credit_cost(tool_credit_cost=15, minimum_charge=1) == 15
