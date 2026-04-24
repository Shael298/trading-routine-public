---
description: Research a single ticker and dry-run it through the buy-side gate. Placed no orders.
allowed-tools: Bash, WebSearch, Read
---

Argument: `$ARGUMENTS` — a ticker symbol, optionally followed by a proposed qty (defaults to the largest whole qty that fits the current tier cap). Pass `--pyramid` anywhere in the arguments to dry-run a pyramid add instead of a first entry.

**Steps:**

1. Read `memory/TRADING-STRATEGY.md` § tier table, § buy-side gate, § entry preference — constructive pullback.
2. Run `bash scripts/alpaca.sh account` → note `equity`, `cash`, `daytrade_count`.
3. Run `bash scripts/alpaca.sh positions` → note current `positions_count`. If `--pyramid` was passed, also pull the live position for `<SYM>` and capture `qty` (→ `existing_shares`), `avg_entry_price * qty` (→ `existing_cost_basis`), and `unrealized_plpc` (→ `existing_unrealized_plpc`).
4. Count weekly trades: `bash scripts/alpaca.sh orders --status=closed` and filter to `side=buy` from the last 7 calendar days (or read `memory/TRADE-LOG.md` entries since Monday UK).
5. Pull a quote: `bash scripts/alpaca.sh quote <SYM>` — use `latestTrade.p` as the price.
6. Research the catalyst: `bash scripts/tavily.sh search "$SYM earnings OR catalyst OR news this week"`. If exit code is 3, fall back to the `WebSearch` tool with the same query. Summarise in one sentence.
7. **Constructive-pullback check (first entries only — skip for `--pyramid`):** using Tavily or `WebSearch`, determine (a) the 20-day swing high and current % pullback from it, (b) whether price is above the 50-day moving average, (c) EPS growth YoY, revenue growth direction. Print all four data points. If pullback is outside 5–15% or price is below the 50-day MA, surface "preference not met — override required before execution."
8. Compute qty:
   - First entry: `floor(equity * tier_pct / price)`, capped by `cash / price`.
   - Pyramid: `floor(existing_shares / 2)`.
   If the computed qty is < 1, say so and stop.
9. Construct the gate payload. For first entry:
   ```json
   {
     "symbol": "SYM", "qty": N, "price": P,
     "equity": E, "cash": C,
     "positions_count": X, "weekly_trades": W, "daytrade_count": D,
     "has_catalyst": true|false, "is_stock": true, "is_fractional": false,
     "is_pyramid": false
   }
   ```
   For pyramid add, additionally set `is_pyramid: true`, `existing_shares`, `existing_cost_basis`, `existing_unrealized_plpc`.
10. Pipe into `bash scripts/gate.sh` and show the decision JSON.

**Output:** Quote · catalyst one-liner · pullback % + 50-day MA status + fundamentals (first entries) · proposed size · gate decision (approved or rejected with reasons) · for pyramid adds, the weighted-average break-even stop price from `sizing.wavg_cost_per_share`. No orders placed. No commits made.
