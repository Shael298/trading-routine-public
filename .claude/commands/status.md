---
description: Snapshot the trading account — equity, positions, open orders, recent activity.
allowed-tools: Bash, Read
---

Give a clean operator-facing status read of the trading account.

**Steps:**

1. Run `bash scripts/alpaca.sh account` and extract `equity`, `cash`, `buying_power`, `pattern_day_trader`, `daytrade_count`.
2. Run `bash scripts/alpaca.sh positions`. If the array is empty, say "no open positions"; otherwise format each as:
   ```
   SYM · qty=Q · entry=$X · last=$Y · P&L=±N.N% · stop order id
   ```
   Use `unrealized_plpc` for P&L %, `qty` for shares, `avg_entry_price` for entry, `current_price` for last.
3. Run `bash scripts/alpaca.sh orders --status=open`. List any open stops and their trail percent / stop price.
4. Read the top of `memory/TRADE-LOG.md` and show the last entry's date/symbol so the operator can sanity-check the log is current.
5. Read the top of `memory/RESEARCH-LOG.md` and show the latest research date.
6. Finally, compute **deployment %** = `(equity - cash) / equity * 100` and compare to the 75–85% target band from `memory/TRADING-STRATEGY.md`. Flag if outside.

**Do not** place any orders. **Do not** commit anything. This is read-only.

Output format: short markdown block — headline equity line, positions list, open stops, deployment %, last log dates. Keep it under 25 lines.
