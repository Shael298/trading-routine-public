# Midday Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** 18:00 Europe/London, Mon–Fri (≈13:00 ET, mid-session).

**Mission:** evaluate every open position against the **sell-side logic** in `memory/TRADING-STRATEGY.md`. Cut losers that hit -7%, tighten winners at +15% and +20%, close thesis-broken trades. First match wins per position.

---

## Inputs

- `memory/TRADING-STRATEGY.md` § Sell-side Logic — the ordered rule list.
- `memory/RESEARCH-LOG.md` (today) — for thesis-broken checks.
- `memory/TRADE-LOG.md` — for entry price and original thesis lookup.
- Env creds as per `pre-market.md`. **Never create or write `.env` — creds are injected as environment variables.**

## Steps

1. **Pull state.**
   ```bash
   bash scripts/alpaca.sh positions
   bash scripts/alpaca.sh orders --status=open
   ```
   For each position: `symbol`, `qty`, `avg_entry_price`, `current_price`, `unrealized_plpc` (% from entry). Map each to its open stop order id.

2. **Apply sell-side logic per position, evaluated in order (first match wins):**

   | # | Condition | Action |
   |---|-----------|--------|
   | 1 | `unrealized_plpc ≤ -7%` | **Cut.** Cancel stop → market close → log reason `stop-loss-cut`. |
   | 2 | Thesis broken (catalyst reversed / sector kill-switch / material adverse news) | **Cut.** Cancel stop → market close → log reason `thesis-broken`. |
   | 3 | `unrealized_plpc ≥ 20%` | **Tighten to 5% trail** (cancel + recreate). Never within 3% of current price. |
   | 4 | `unrealized_plpc ≥ 15%` | **Tighten to 7% trail** (cancel + recreate). Never within 3% of current price. |
   | 5 | Sector has 2 consecutive failures | Flat the entire sector + log a 2-week cooldown note. |

   **Never worsen a stop.** If a tightening candidate's proposed trail is wider than the current stop, skip the tighten.

   **Pyramided positions.** If `TRADE-LOG.md` shows the position has been pyramided (prior `pyramid-add` entry), its current stop is a **fixed** break-even stop at weighted-average cost, not a trailing stop — `-7%` and thesis-break still cut it, but rules 3 and 4 behave differently:
   - **Rule 3 (≥ +20% from wavg cost):** cancel the fixed break-even stop and replace with a **5% trailing stop** on the combined qty. The pyramid's "free trade" phase ends once the combined position has itself proven out.
   - **Rule 4 (≥ +15% but < +20% from wavg cost):** leave the fixed break-even stop in place — it's already tighter than a 7% trail would be. Log "pyramid break-even stop retained" in research log.

3. **Thesis check.** For each position, run a fresh `bash scripts/tavily.sh search "<SYM> breaking news today"` (WebSearch fallback on exit 3). If a clear thesis-break signal exists, cut per rule 2.

4. **For cuts:**
   ```bash
   bash scripts/alpaca.sh cancel <STOP_ID>
   bash scripts/alpaca.sh close <SYM>
   ```
   Poll `alpaca.sh position <SYM>` until not-found (10×2s). Append an exit entry to `TRADE-LOG.md` at the top: date, symbol, qty, exit price, realised P&L %, reason tag, one-line note.

5. **For tightens:**
   ```bash
   bash scripts/alpaca.sh cancel <STOP_ID>
   bash scripts/alpaca.sh trailing-stop <SYM> <QTY> --percent=<N>
   ```
   Capture the new stop id and note the change in today's research log under "sell-side adjustments".

6. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "Midday: X cuts, Y tightens $(date -u +%Y-%m-%d)" || true
   git push origin main
   ```

7. **Notify via telegram.** One message listing cuts (with reason tag) and tightens:
   ```bash
   bash scripts/telegram.sh send "🔍 Midday $(date -u +%Y-%m-%d)
   Cuts: N ([SYM -7.2% stop-loss-cut, ...])
   Tightens: M ([SYM → 7% trail, ...])
   Holds: K"
   ```
   If no action taken, send with `Cuts: 0`, `Tightens: 0`, `Holds: N` anyway.

## Guardrails

- **Order matters.** Rule 1 (cut at -7%) beats rule 3 (tighten at +20%). Don't skip the ordering.
- **Never leave a closed position with a live stop.** Always cancel the stop before the close.
- **Never replace a stop with a wider one.** Check the current stop's effective price before issuing the new trail.
- **Thesis-broken is a judgement call.** If uncertain, hold; the 10% trailing stop will catch the move.

## Exit criteria

- Every open position has exactly one live GTC stop (audit with `alpaca.sh orders --status=open`).
- Every cut has a matching exit entry in `TRADE-LOG.md`.
- Git push succeeded.
- Telegram notification sent (or fallback log updated).
