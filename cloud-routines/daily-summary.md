# Daily Summary Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** 21:05 Europe/London, Mon–Fri (≈16:05 ET, 5 minutes after US close).

**Mission:** write the end-of-day (EOD) snapshot to `TRADE-LOG.md`, drain any accumulated `notification_fallback.log`, and deliver the day's Telegram summary.

---

## Inputs

- `memory/TRADE-LOG.md` — previous snapshots.
- `memory/RESEARCH-LOG.md` (today) — what happened.
- `memory/notification_fallback.log` (if present) — queued Telegram messages.
- Env creds as per `pre-market.md`. **Never create or write `.env` — creds are injected as environment variables.**

## Steps

1. **Final account pull.**
   ```bash
   bash scripts/alpaca.sh account
   bash scripts/alpaca.sh positions
   bash scripts/alpaca.sh orders --status=all
   ```
   Capture: equity, cash, deployment %, realised P&L since Monday, open positions with Qty / Entry / Last / P&L% / Stop id / Days held.

2. **Stop-order audit.** For each open position, confirm it has exactly one live GTC stop. If any position is unguarded, immediately place a 10% trailing stop (`alpaca.sh trailing-stop ...`) and flag the gap in the summary.

3. **Append an EOD snapshot to `memory/TRADE-LOG.md`** at the top using the EOD template in that file. Append-only, newest first. Include:
   - Date · equity · cash · deployment %
   - Positions table (symbol, qty, entry, last, P&L%, stop id, days held)
   - Today's closed trades (if any)
   - Anomalies noted during the stop-order audit

4. **Drain the notification fallback log.** If `memory/notification_fallback.log` exists and is non-empty, include its contents in the Telegram summary (prefixed with "📮 Backlog:"), then truncate the file: `: > memory/notification_fallback.log`. The drained contents are preserved in git history via the next commit.

5. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "EOD $(date -u +%Y-%m-%d) · equity \$X · N open" || true
   git push origin main
   ```

6. **Notify via telegram.** Structured summary:
   ```bash
   bash scripts/telegram.sh send "📋 EOD $(date -u +%Y-%m-%d)
   Equity: \$X (±Y% today, ±Z% week)
   Positions: N | Deployed: D%
   Closed today: [SYM reason ±N.N%, ...]
   Open: [SYM ±P&L%, ...]
   [Backlog: ... (if fallback log was drained)]"
   ```

## Guardrails

- **Audit stops before summarising.** If a position has no stop, fix it *before* writing the summary so the EOD snapshot reflects a truly-guarded book.
- **Drain, don't delete.** Fallback log contents must be included in the Telegram summary before the file is truncated — the operator needs to see what was missed during the day.
- **Honest accounting.** If a rule was violated today, say so explicitly in the summary (and in the EOD snapshot). Silent drift undermines the whole system.

## Exit criteria

- EOD snapshot entry exists at the top of `TRADE-LOG.md`.
- Every open position is backed by a live GTC stop.
- `notification_fallback.log` is empty or nonexistent (drained).
- Git push succeeded.
- Telegram summary delivered (or fallback log updated — the *next* daily-summary will drain it).
