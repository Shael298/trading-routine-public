# Earnings Risk Check Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** 19:30 Europe/London, Mon–Fri (≈14:30 ET, mid-afternoon).

**Mission:** detect scheduled binary events (earnings, FDA decisions, macro data) within 2 trading days for every open position and flag them before daily-summary so the operator can decide to hold, trim, or close ahead of the event.

---

## Inputs

- `memory/TRADE-LOG.md` — open positions and original thesis.
- `memory/RESEARCH-LOG.md` (today's entry if pre-market has already run) — for context.
- Env creds as per `pre-market.md`. **Never create or write `.env` — creds are injected as environment variables.**

## Steps

1. **Pull open positions.**
   ```bash
   bash scripts/alpaca.sh positions
   ```
   Extract the list of symbols. If no open positions, skip to step 4 (silent exit).

2. **Search for upcoming binary events per symbol.**
   For each symbol, run:
   ```bash
   bash scripts/tavily.sh search "<SYM> earnings date announcement next week"
   ```
   WebSearch fallback on exit 3. Other non-zero → log "search failed for SYM" and continue.

   Look for:
   - Earnings release date
   - FDA approval / PDUFA date
   - Major macro event directly tied to the position's thesis

3. **Classify each position.**

   | Classification | Condition |
   |---|---|
   | `🔴 BINARY EVENT ≤2 days` | Earnings / catalyst scheduled within 2 trading days from today |
   | `🟡 BINARY EVENT 3–5 days` | Earnings / catalyst scheduled within 3–5 trading days |
   | `🟢 clear` | No scheduled binary event found in next 5 trading days |

4. **Append a block to today's `RESEARCH-LOG.md`** (at the top of today's section, or as a new dated section if pre-market hasn't run):

   ```
   ## Earnings Risk Check — YYYY-MM-DD HH:MM UTC

   | Symbol | Event | Date | Classification | Recommendation |
   |--------|-------|------|----------------|----------------|
   | NVDA   | Q1 earnings | 2026-05-21 | 🟡 3–5 days | Monitor — consider trimming if thesis is weak |
   | TSLA   | none found  | —          | 🟢 clear     | No action |
   ```

   Recommendation logic:
   - `🔴` → **"Close or trim before event — binary risk unacceptable under strategy rules."**
   - `🟡` → **"Monitor — consider trimming if position is at risk; raise awareness at pre-market tomorrow."**
   - `🟢` → **"No action."**

5. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "Earnings risk check: $(date -u +%Y-%m-%d) — <N flags>" || true
   git push origin main
   ```

6. **Notify via Telegram — only if at least one 🔴 or 🟡 flag exists.**
   ```bash
   bash scripts/telegram.sh send "⚠️ Earnings risk $(date -u +%Y-%m-%d)
   🔴 Binary ≤2 days: [SYM (event, date), ...]
   🟡 Watch 3–5 days: [SYM (event, date), ...]
   Action: check RESEARCH-LOG for recommendations"
   ```
   If all positions are 🟢, send nothing (silent exit).

## Guardrails

- **This routine flags; it does not trade.** No orders, no stops, no closes. Decisions are the operator's (or the market-open routine's) to execute.
- **Uncertainty is a 🟡.** If search results are ambiguous about whether an event falls within the window, err on the side of flagging.
- **Gap risk is the concern.** Earnings after-hours or pre-market can gap through a trailing stop. The flag exists to prompt a deliberate hold/close decision, not to force a close.

## Exit criteria

- `RESEARCH-LOG.md` has a new earnings-risk-check block for today.
- Git push succeeded.
- Telegram sent if any 🔴/🟡 flags, silent otherwise.
