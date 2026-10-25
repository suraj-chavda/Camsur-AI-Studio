"""
# Credit System

Camsur sells **integer credits**. Storage is **not** billed separately.

## Charge

1. Resolve tool from DB (`tools.credit_cost`) via `resolve_generation_pricing`
2. `calculate_credit_cost` → integer, **always ceil**
3. Abuse/kill-switch checks (no charge if rejected)
4. Insert generation with **snapshot** `credit_cost` + `pricing_version`
5. Atomic RPC `spend_user_credits` with idempotency key `generation:{id}:spend`

## Refund

On terminal provider/storage failure after a spend:

- Atomic RPC `refund_user_credits` with key `generation:{id}:refund`
- Status → `refunded` (exactly once)
- Lifecycle deletion of media later does **not** refund

## Idempotency

Optional `idempotency_key` (JSON or form) unique per user.

Retry returns the existing generation and does **not** charge again.

## Async mode

Header `X-Async: true`:

1. Charge once
2. Return `pending`
3. Background task runs `process_generation` (worker never charges)

Default (no header): sync response after completion (Flutter-compatible).
