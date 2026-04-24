# Pre-Market Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** 12:00 Europe/London, Mon–Fri (≈07:00 ET, 2h30 before US open).

**Mission:** build today's `memory/RESEARCH-LOG.md` entry. Read the account, scan the market, propose 0–5 candidate trade ideas. **No orders. No position changes.**

---

## Inputs

- `memory/PROJECT-CONTEXT.md` — mission & invariants.
- `memory/TRADING-STRATEGY.md` — rulebook (tier caps, hard rules).
- `memory/TRADE-LOG.md` (top) — what's open.
- `memory/RESEARCH-LOG.md` (top) — yesterday's ideas & what happened.
- Credentials injected by cloud runtime as environment variables: `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, `TAVILY_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`. **Never create, write, or read a `.env` file — read creds from the injected environment only.**

## Steps

1. **Account snapshot.**
   ```bash
   bash scripts/alpaca.sh account
   bash scripts/alpaca.sh positions
   bash scripts/alpaca.sh orders --status=open
   ```
   Capture equity, cash, deployment %, daytrade_count, open stops. Flag deviations from the 75–85% deployment band.

2. **Market context.** Run four `bash scripts/tavily.sh search` calls (fall back to `WebSearch` on exit 3):
   - "S&P 500 futures premarket today"
   - "VIX today OR market volatility this week"
   - "earnings reports today US pre-market"
   - "economic calendar US today CPI OR Fed OR unemployment"
   Summarise each in one bullet.

3. **Per-held-ticker news.** For each open position, run one targeted query: `"<SYM> news today OR earnings"`. Flag anything that breaks the thesis.

4. **Pyramid candidates.** For each open position, compute `unrealized_plpc` from the `alpaca.sh positions` payload. If any position is up **≥ 15%** from entry **and has not already been pyramided** (check `TRADE-LOG.md` for a prior `pyramid-add` entry on that symbol), list it under **Pyramid Candidates** in the research log with: current shares, cost basis, unrealized %, proposed add qty (`floor(existing_shares / 2)`), and weighted-average break-even stop price. Pyramid adds bypass the weekly cap and the 6-position cap but still require `has_catalyst: true` — the catalyst is "the position has already proven itself."

5. **First-entry candidates.** Based on the catalysts found, propose **0–3** first-entry tickers that fit the current tier cap (from `TRADING-STRATEGY.md`, current Tier 1 excludes META/MSFT at $1k equity). For each, list:
   - Symbol, catalyst, entry zone, proposed stop %, 1-sentence thesis.
   - **Constructive-pullback check:** is the candidate 5–15% off its 20-day high? Is it above its 50-day MA? Tavily/`WebSearch` can answer both — report both numbers or mark as "override: catalyst-strong-enough-despite-no-pullback" with reason.
   - **Fundamentals check:** EPS growth YoY, revenue growth direction, any unresolved thesis risk. If fundamentals are weak AND the pullback is absent, drop the idea.
   If nothing catalysts cleanly, propose zero. "No trade" is a valid outcome.

6. **Append to `memory/RESEARCH-LOG.md`** at the top (append-only, newest first). Template lives inside that file. The Trade Ideas subsection must have two groups: **First entries** (with pullback % and 50-day MA status) and **Pyramid adds** (with wavg break-even price).

7. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "Pre-market research $(date -u +%Y-%m-%d)" || true
   git push origin main
   ```

8. **Notify via telegram.**
   ```bash
   bash scripts/telegram.sh send "📊 Pre-market $(date -u +%Y-%m-%d)
   Equity: \$X
   Open positions: N
   First-entry ideas: M ([symbols])
   Pyramid candidates: K ([symbols])"
   ```

## Guardrails

- **No orders.** This routine does not call `alpaca.sh buy`, `stop`, `close`, or `cancel`. Those belong to market-open and midday.
- **Fail-closed on broker.** If `alpaca.sh account` fails, commit a minimal research entry noting the outage, notify, and exit 0.
- **Fail-open on telegram.** If `telegram.sh` writes to the fallback log, do not retry — the daily-summary routine will surface it.
- **Timezone discipline.** All timestamps written to memory are in UTC (use `date -u`) or explicitly marked UK.

## Exit criteria

- Research log entry appended with at least sections: Account Snapshot, Market Context, Trade Ideas.
- Git push succeeded (verify with `git log -1 --oneline`).
- Telegram notification sent (or fallback log updated).
