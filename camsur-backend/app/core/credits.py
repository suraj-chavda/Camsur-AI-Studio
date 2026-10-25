"""Integer credit math — never use float for credits."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation, ROUND_CEILING


class CreditMathError(ValueError):
    pass


def ceil_credits(raw: int | float | Decimal | str) -> int:
    """
    Convert a raw credit requirement to a billed integer.

    Always rounds UP. Never rounds down.
    Rejects negatives, NaN, and infinities.
    """
    if isinstance(raw, bool):
        raise CreditMathError("Invalid credit value")

    if isinstance(raw, int):
        if raw < 0:
            raise CreditMathError("Credit cost cannot be negative")
        return raw

    try:
        value = Decimal(str(raw))
    except (InvalidOperation, ValueError) as exc:
        raise CreditMathError("Invalid credit value") from exc

    if not value.is_finite():
        raise CreditMathError("Credit cost must be finite")
    if value < 0:
        raise CreditMathError("Credit cost cannot be negative")
    if value == 0:
        return 0

    # Exact integers stay exact; fractional amounts ceiling.
    ceiled = value.to_integral_value(rounding=ROUND_CEILING)
    return int(ceiled)


def calculate_credit_cost(
    *,
    tool_credit_cost: int,
    minimum_charge: int = 0,
) -> int:
    """
    Authoritative Camsur credit charge for a generation.

    Today tools store integer prices (10/15). This helper still ceilings any
    future fractional inputs and enforces a non-negative integer result.
    """
    if not isinstance(tool_credit_cost, int) or isinstance(tool_credit_cost, bool):
        # Defensive: DB/JSON might hand us a float-like — ceil, never truncate.
        cost = ceil_credits(tool_credit_cost)
    else:
        cost = ceil_credits(tool_credit_cost)

    min_charge = ceil_credits(minimum_charge)
    return max(cost, min_charge)


def usd_to_decimal(amount: str | int | Decimal) -> Decimal:
    """Money must use Decimal — never float."""
    try:
        value = Decimal(str(amount))
    except (InvalidOperation, ValueError) as exc:
        raise CreditMathError("Invalid money amount") from exc
    if not value.is_finite():
        raise CreditMathError("Money amount must be finite")
    return value.quantize(Decimal("0.01"), rounding=ROUND_CEILING)
