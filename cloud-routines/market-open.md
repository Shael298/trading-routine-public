# Market-Open Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** 14:45 Europe/London, Mon–Fri (≈09:45 ET, 15 minutes after US open — avoids opening-print chaos).

**Mission:** execute the trade ideas approved in today's pre-market research, each guarded by `scripts/gate.sh` and a mandatory GTC trailing stop placed in the same firing.

---

## Inputs

- `memory/TRADING-STRATEGY.md` — rulebook (read-only).
- `memory/RESEARCH-LOG.md` (top) — today's ideas.
- `memory/TRADE-LOG.md` (top) — last 7 days' closed trades (for weekly-trade-cap counting).
- Env creds as per `pre-market.md`. **Never create or write `.env` — creds are injected as environment variables.**

## Steps

1. **Refresh account state.**
   ```bash
   bash scripts/alpaca.sh account   # equity, cash, daytrade_count
   bash scripts/alpaca.sh positions # positions_count
   ```
   Count `weekly_trades` = number of **buy** entries in `TRADE-LOG.md` since Monday 00:00 UK.

2. **For each FIRST-ENTRY idea in today's research log**, in priority order:

   a. **Preference check.** The research entry must contain either (i) a constructive-pullback datapoint — pullback 5–15% off 20-day high AND above 50-day MA — or (ii) an explicit override note naming the catalyst that justifies entering without a pullback. If neither is present, **reject the idea** (log `missing-pullback-datapoint`) and move on. This is enforced here because `gate.sh` is a pure function and doesn't see the research log.

   b. **Quote & size.** `bash scripts/alpaca.sh quote <SYM>` → price. Compute qty = `floor(equity * tier_pct / price)`, capped by `cash / price`. Skip if qty < 1.

   c. **Gate check.** Build the payload JSON (with `is_pyramid: false` and the four existing_* fields all 0) and pipe through `bash scripts/gate.sh`. If `approved=false`, log the reason tags into today's research log under "rejected at gate" and move to the next idea.

   d. **Buy.** `bash scripts/alpaca.sh buy <SYM> <QTY>`. Capture `order.id`.

   e. **Wait for fill.** Poll `bash scripts/alpaca.sh position <SYM>` up to 10×2s. If still unfilled, cancel: `bash scripts/alpaca.sh cancel <ORDER_ID>`, log the miss, continue.

   f. **Place trailing stop in the same firing** (non-negotiable):
      ```bash
      bash scripts/alpaca.sh trailing-stop <SYM> <QTY> --percent=10
      ```
      Capture `stop.id`. If this call fails, **immediately market-close the position** (`alpaca.sh close <SYM>`) and notify — never leave an unguarded long.

   g. **Append to `memory/TRADE-LOG.md`** at the top with: date, symbol, qty, fill price, cost %, stop order id, catalyst, thesis, risk. Append-only, newest first.

3. **For each PYRAMID CANDIDATE in today's research log**, in priority order:

   a. **Re-read the live position.** `bash scripts/alpaca.sh position <SYM>` → `existing_shares`, `existing_cost_basis` (= `avg_entry_price * qty`), `existing_unrealized_plpc`. If the live `unrealized_plpc` has dropped below 0.15 since pre-market, skip — conditions changed.

   b. **Quote & size.** `bash scripts/alpaca.sh quote <SYM>` → price. Add qty = `floor(existing_shares / 2)` (always an integer). Skip if `add_qty < 1`.

   c. **Gate check.** Build the payload JSON with `is_pyramid: true`, `existing_shares`, `existing_cost_basis`, `existing_unrealized_plpc`, and the freshly-quoted price. Pipe through `bash scripts/gate.sh`. If `approved=false`, log the reason tags and move on.

   d. **Cancel the existing trailing stop first.** `bash scripts/alpaca.sh orders --status=open` → find the stop for this symbol → `bash scripts/alpaca.sh cancel <STOP_ORDER_ID>`. This is critical: Alpaca rejects a second sell order for shares already committed to an open sell.

   e. **Buy the add.** `bash scripts/alpaca.sh buy <SYM> <ADD_QTY>`. Capture `order.id`. Wait for fill (same poll as first-entry flow). If the add never fills, **immediately re-place the original 10% trailing stop on the existing shares** before exit — we cannot be left unguarded.

   f. **Compute weighted-average cost.** `wavg_cost = (existing_cost_basis + add_qty * fill_price) / (existing_shares + add_qty)`. Extract from `gate.sh` output's `sizing.wavg_cost_per_share` field or recompute locally.

   g. **Place FIXED stop at wavg break-even** on the *combined* share count:
      ```bash
      bash scripts/alpaca.sh stop <SYM> <COMBINED_QTY> --price=<WAVG_COST>
      ```
      Capture `stop.id`. If this call fails, **immediately market-close the full combined position** and notify — pyramid-without-stop is never acceptable. Note: this is a **fixed** stop (type `stop`, not `trailing_stop`) — the pyramid converts paper gains into guaranteed break-even, so the stop is a fixed price at wavg cost, not a trailing %.

   h. **Append to `memory/TRADE-LOG.md`** with `type: pyramid-add`, symbol, add qty, fill price, new combined qty, new wavg cost, new stop order id, catalyst ("proven winner, position up ≥15%"), and the original entry's row reference.

4. **Handle sell-side hits at open.** If any position already triggered a -7% cut gap-down, run the midday sell-side logic on it now (see `midday.md` § sell-side).

5. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "Market-open: N first-entries, K pyramid-adds $(date -u +%Y-%m-%d)" || true
   git push origin main
   ```

6. **Notify via telegram.** One message summarising all buys/adds/stops/rejections:
   ```bash
   bash scripts/telegram.sh send "🟢 Market-open $(date -u +%Y-%m-%d)
   First entries: N ([SYM @ \$price, stop 10%])
   Pyramid adds: K ([SYM add qty, break-even stop])
   Rejected: M ([SYM: reason])
   Deployed: X%"
   ```
   If zero trades executed, send a "no trades" message anyway — silence is not acceptable.

## Guardrails

- **Every buy gets a GTC stop in the same firing** — 10% trailing on first entries, fixed wavg break-even on pyramid adds. If the stop call fails, close the position.
- **No gate → no trade.** Never call `alpaca.sh buy` without a preceding `gate.sh` approval.
- **Fail-closed on broker outage.** If Alpaca is down mid-run, stop after the current symbol, commit what's done, notify the exception, exit 0.
- **Don't exceed 5 first-entry buys/week.** The gate enforces this for first entries (and exempts pyramid adds), but cross-check locally before calling `buy`.

## Exit criteria

- Every executed buy has a matching trailing-stop order id captured in the trade log.
- No open long exists without a live GTC stop (run `alpaca.sh orders --status=open` before exit and sanity-check).
- Git push succeeded.
- Telegram notification sent (or fallback log updated).
