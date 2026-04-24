---
description: Pipe a trade-idea JSON payload through the buy-side gate. Returns the approve/reject decision only.
allowed-tools: Bash
---

Argument: `$ARGUMENTS` — either a JSON blob inline, or `-` meaning read stdin from the operator's next turn.

**Steps:**

1. If `$ARGUMENTS` is non-empty and parses as JSON, use it as the payload; otherwise echo the expected schema and wait for the operator to paste:
   ```json
   {
     "symbol": "SYM", "qty": 1, "price": 10.00,
     "equity": 1000, "cash": 500,
     "positions_count": 0, "weekly_trades": 0, "daytrade_count": 0,
     "has_catalyst": true, "is_stock": true, "is_fractional": false,
     "is_pyramid": false,
     "existing_shares": 0, "existing_cost_basis": 0, "existing_unrealized_plpc": 0
   }
   ```
   The four pyramid fields default to 0/false when omitted — include them only for pyramid-add dry-runs (and set `is_pyramid: true` plus the three existing_* fields from the live position).
2. Pipe the payload through `bash scripts/gate.sh`.
3. Show the result verbatim (it's already formatted JSON). If `approved=false`, list the reason tags one per line with their short meaning (e.g. `tier-size-exceeded → cost > tier_pct × equity`).

No network calls. No orders placed. No commits.
