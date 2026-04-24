# Weekly-Review Routine

**Setup (run first, before reading anything):**
```bash
git fetch origin main && git checkout main && git pull --rebase origin main
```

**Fires:** Friday 21:10 Europe/London (5 minutes after the Friday daily-summary). Runs once per week.

**Mission:** grade the trading week A–F against `memory/WEEKLY-REVIEW.md` § Grading scale, record what worked and what didn't, and — only when justified — propose a concrete rule change to `memory/TRADING-STRATEGY.md` in the same commit.

---

## Inputs

- `memory/WEEKLY-REVIEW.md` — grading scale + prior weeks.
- `memory/TRADE-LOG.md` — every trade and EOD snapshot this week.
- `memory/TRADING-STRATEGY.md` — the rulebook (this is the only routine allowed to edit it).
- `memory/RESEARCH-LOG.md` — week's ideas and rejections.
- Env creds as per `pre-market.md`. **Never create or write `.env` — creds are injected as environment variables.**

## Steps

1. **Week boundary.** The week is Monday 00:00 UK → Friday 23:59 UK. Grab every closed trade in that window from `TRADE-LOG.md`, plus Monday's opening equity and Friday's closing equity (from EOD snapshots).

2. **Compute metrics:**
   - Start equity · end equity · week P&L % · $ change
   - Trades count · wins · losses · win rate
   - Profit factor = Σwins / Σlosses (absolute values)
   - Best trade · worst trade
   - Open positions end-of-week (EOW) · deployment %
   - vs S&P 500: run `bash scripts/alpaca.sh quote SPY` at start and end of week (or use `prevDailyBar` for Monday close; current `latestTrade` for Friday close). Report delta in percentage points.

3. **Detect rule violations.** Walk each trade and each day's snapshot against `memory/TRADING-STRATEGY.md` § Hard Rules:
   - Any buy without a same-firing trailing stop?
   - Any position that hit -8% or worse (stop-cut late)?
   - Weekly trade cap (3) breached?
   - Position size exceeded tier %?
   - Unguarded position overnight?
   A single material violation downgrades the grade to D; multiple → F.

4. **Assign a grade A–F** using the table in `memory/WEEKLY-REVIEW.md`. Be honest — grade inflation corrupts the feedback loop.

5. **Evaluate trend.** If the last two weeks are both ≤ C, the routine **must** propose a concrete rule change to `memory/TRADING-STRATEGY.md` in the same commit. A "rule change" is specific and testable — e.g. "tighten initial trailing stop from 10% → 8%" — not vague ("be more disciplined"). Update the file's "Last reviewed" date and note the amendment in the commit message.

6. **Append a WEEKLY-REVIEW entry** at the top of `memory/WEEKLY-REVIEW.md` using the template in that file: week label, grade, metrics table, what worked / didn't / strategy changes / next-week focus.

7. **Commit + push.**
   ```bash
   git fetch origin main
   git checkout main
   git pull --rebase origin main
   git add -A
   git commit -m "Weekly review $(date +%G-W%V) · Grade X · [change summary]" || true
   git push origin main
   ```

8. **Notify via telegram.** One message:
   ```bash
   bash scripts/telegram.sh send "📈 Weekly review $(date +%G-W%V)
   Grade: X
   P&L: ±N.N% (vs SPY ±N pp)
   Trades: W wins / L losses
   Best: SYM +N% | Worst: SYM -N%
   Focus: [one-line next-week priority]
   [Strategy change: ... (if amended)]"
   ```

## Guardrails

- **You are the only routine allowed to edit `TRADING-STRATEGY.md`.** Other routines treat it as read-only.
- **Strategy amendments require 2 weeks of signal**, not a single bad week. A grade-A week proposing a relaxation is also valid — but again, tie it to sustained evidence.
- **Rule changes are committed in the same push as the review entry.** Never leave a half-amended rulebook.
- **Don't rewrite history.** If a prior grade was wrong, write a new entry correcting it — never edit the original.

## Exit criteria

- WEEKLY-REVIEW entry exists at the top of the file.
- If 2 weeks ≤ C: a concrete diff to `TRADING-STRATEGY.md` is staged in the same commit, along with a matching line in the review entry's "Strategy changes" section.
- Git push succeeded.
- Telegram summary delivered (or fallback log updated).
