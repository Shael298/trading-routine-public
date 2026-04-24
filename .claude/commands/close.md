---
description: Close a position manually — cancel its stop, market-close, log, notify.
allowed-tools: Bash, Read, Edit, Write
---

Argument: `$ARGUMENTS` — `<SYM>` (required) `<reason-tag>` (optional; defaults to `manual-close`). Valid tags: `stop-loss-cut`, `thesis-broken`, `manual-close`, `trail-hit-recorded`.

**Steps:**

1. `bash scripts/alpaca.sh position <SYM>` — confirm the position exists. Note `qty`, `avg_entry_price`, `current_price`, `unrealized_plpc`.
2. `bash scripts/alpaca.sh orders --status=open` — find the open trailing stop (or stop) on `<SYM>`. Cancel it: `bash scripts/alpaca.sh cancel <ORDER_ID>`. Ignore "already-cancelled" errors.
3. `bash scripts/alpaca.sh close <SYM>` — this sends a market order to close. Poll `position <SYM>` until it reports not-found (up to 10×2s).
4. Append an **exit** entry at the top of `memory/TRADE-LOG.md`: date, symbol, qty, exit price, realised P&L %, reason tag, one-line note. Append-only, never edit prior entries.
5. `git add -A && git commit -m "Manual close: SYM @ EXIT · reason" && git push origin main`.
6. `bash scripts/telegram.sh send "🛑 Closed SYM @ EXIT · realised ±N.N% · reason"`.

If any step fails before the position is fully flat, notify immediately so the operator can intervene. Never leave a dangling stop order alive after the position is closed.
