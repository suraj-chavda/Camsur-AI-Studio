"""
# Generation Lifecycle

```text
pending → processing → completed
pending → processing → refunded   (failure + successful refund)
pending → processing → failed     (failure without spend/refund)
failed → refunded                 (retry-refund after the fact)
pending → cancelled
```

Worker entrypoint: `GenerationService.process_generation(id)` — **never deducts credits**.

Statuses exposed to clients: pending, processing, completed, failed, refunded, cancelled.

Failed user message is sanitized; internal error text stays in logs/DB for ops.

## Cost tracking on failure

The user always gets a full 1:1 credit refund on failure — that does not change. But if
the BFL job was actually submitted before failing (polling/download/host-check error
after a successful submit), `generations.provider_cost_usd` and `provider_request_id`
are still recorded, because real provider cost was likely incurred even though the user
paid nothing net. See `docs/COST_CONTROLS.md` for how this feeds the margin monitor.
