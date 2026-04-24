---
description: Disciplined manual buy — gate check, market buy, mandatory GTC trailing stop, append to trade log, notify.
allowed-tools: Bash, Read, Edit, Write, WebSearch
---

Argument: `$ARGUMENTS` — `<SYM> <QTY>` (qty is whole shares) or just `<SYM>` (size to tier cap). Pass `--pyramid` anywhere in `$ARGUMENTS` to add to an existing proven-winner position instead of a first entry.

**This command may place real paper orders.** Follow every step. Abort if any invariant is violated.

**Steps (first entry — default):**

1. Read `memory/TRADING-STRATEGY.md` for the current rule set.
2. `bash scripts/alpaca.sh account` → equity, cash, daytrade_count. Fail-closed if `trading_blocked` or `account_blocked`.
3. `bash scripts/alpaca.sh positions` → positions_count. Reject if already holding SYM (use `/buy SYM --pyramid` to add to an existing holding).
4. `bash scripts/alpaca.sh quote <SYM>` → latest price.
5. Determine QTY: use `$ARGUMENTS` if specified, else `floor(equity * tier_pct / price)`.
6. Confirm (a) the catalyst is documented in today's `memory/RESEARCH-LOG.md` entry, and (b) the constructive-pullback preference is satisfied or explicitly overridden (pullback 5–15% off 20-day high AND above 50-day MA, OR a strong-catalyst override note). If neither, **stop** and tell the operator to run `/idea` or `/research` first.
7. Build gate payload JSON (with `is_pyramid: false`), pipe through `bash scripts/gate.sh`. If `approved=false`, print reasons and stop.
8. `bash scripts/alpaca.sh buy <SYM> <QTY>`. Capture `order.id`. Poll `bash scripts/alpaca.sh position <SYM>` (up to 10×2s) until `qty` reports.
9. **Immediately** place the trailing stop: `bash scripts/alpaca.sh trailing-stop <SYM> <QTY> --percent=10`. Capture the stop order id.
10. If step 9 fails, immediately `bash scripts/alpaca.sh close <SYM>` and notify — never leave an unguarded long.
11. Append a TRADE-LOG entry at the top of `memory/TRADE-LOG.md` with: date, symbol, qty, fill price, cost %, stop order id, catalyst, thesis, risk. Append-only, newest first.
12. `git add -A && git commit -m "Manual buy: SYM QTY @ PRICE" && git push origin main`.
13. `bash scripts/telegram.sh send "✅ Buy filled: SYM QTY @ PRICE · stop 10% trail · $deployed/$equity"`.

**Steps (pyramid add — when `--pyramid` is passed):**

1. Read `memory/TRADING-STRATEGY.md` for the current rule set.
2. `bash scripts/alpaca.sh account` → equity, cash, daytrade_count.
3. `bash scripts/alpaca.sh position <SYM>` → `qty` (= `existing_shares`), `avg_entry_price`, `unrealized_plpc`. If no position exists or `unrealized_plpc < 0.15`, **stop**. Compute `existing_cost_basis = qty * avg_entry_price`.
4. Check `memory/TRADE-LOG.md` — if there's already a `pyramid-add` entry for SYM, **stop** (one pyramid per position, ever).
5. `bash scripts/alpaca.sh quote <SYM>` → latest price.
6. Compute ADD_QTY: `floor(existing_shares / 2)`. If ADD_QTY < 1, **stop**. COMBINED_QTY = `existing_shares + ADD_QTY`.
7. Build gate payload JSON with `is_pyramid: true` and the three existing_* fields, pipe through `bash scripts/gate.sh`. If `approved=false`, print reasons and stop. Capture `sizing.wavg_cost_per_share` from the decision.
8. **Cancel the existing trailing stop first.** `bash scripts/alpaca.sh orders --status=open` → find SYM's stop id → `bash scripts/alpaca.sh cancel <STOP_ID>`.
9. `bash scripts/alpaca.sh buy <SYM> <ADD_QTY>`. Capture `order.id`. Poll `bash scripts/alpaca.sh position <SYM>` (up to 10×2s) until qty reports `COMBINED_QTY`. If the add never fills, **immediately re-place the original 10% trailing stop** on `existing_shares` before exit — we cannot be left unguarded.
10. **Immediately** place the fixed break-even stop on the combined position: `bash scripts/alpaca.sh stop <SYM> <COMBINED_QTY> --price=<WAVG>`. Capture the stop order id.
11. If step 10 fails, immediately `bash scripts/alpaca.sh close <SYM>` on the full combined position and notify — pyramid-without-stop is never acceptable.
12. Append a `pyramid-add` entry to `memory/TRADE-LOG.md` at the top with: date, symbol, add qty, add fill price, new combined qty, weighted-avg cost, new stop order id (fixed @ WAVG), catalyst ("proven winner, +15% hit"), reference to original entry row. Append-only, newest first.
13. `git add -A && git commit -m "Pyramid add: SYM ADD_QTY @ PRICE (wavg WAVG)" && git push origin main`.
14. `bash scripts/telegram.sh send "🔼 Pyramid: SYM +ADD_QTY @ PRICE · combined QTY @ wavg WAVG · fixed break-even stop"`.

Report back to the operator: symbol, qty (and whether first entry or pyramid add), fill, stop id + stop type (trailing vs fixed wavg), deployment %, commit sha.
