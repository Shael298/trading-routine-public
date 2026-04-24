---
description: Manual weekly-review preview — read the log, compute metrics, draft a grade. Does not commit or push.
allowed-tools: Bash, Read
---

**Steps:**

1. Read `memory/WEEKLY-REVIEW.md` — note the last grade and any carry-forward focus items.
2. Read `memory/TRADE-LOG.md` — collect every closed trade since Monday 00:00 UK (i.e. this rolling trading week). For each: symbol, entry, exit, realised P&L %, reason tag.
3. Compute metrics:
   - Trades this week · wins · losses · win rate
   - Sum of realised P&L %  ·  profit factor (Σwins / Σlosses)
   - Current equity vs Monday-open equity → week P&L %
   - vs S&P 500 for the same window: `bash scripts/alpaca.sh quote SPY` → approximate week-over-week.
   - Open positions end-of-week · deployment %.
4. Apply the A–F scale from `memory/WEEKLY-REVIEW.md` § Grading scale. Propose a grade.
5. Identify any rule violations (reference `memory/TRADING-STRATEGY.md`) — a missed stop, an oversized position, a weekly-trade cap breach. A single material violation downgrades to D; multiple → F.
6. Identify what worked (entries with clear catalysts + discipline), what didn't (avoidable losses), and one focus item for next week.
7. Draft a markdown block matching `WEEKLY-REVIEW.md` § entry template and show it to the operator. **Do not** write it to the file — the Friday weekly-review routine owns that. This is a preview only.

Output format: metrics table · proposed grade · what-worked bullets · what-didn't bullets · next-week focus · the drafted entry block.
