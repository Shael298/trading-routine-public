# Research Log

One dated entry per trading day. Written by the **pre-market** cloud routine at
12:00 UK (with an optional midday addendum if something material breaks). Read by
market-open and weekly-review.

Append-only, newest at the **top**.

---

## Entry schema (every pre-market entry must have these three subsections)

### Account Snapshot
- **Equity**, **cash**, **buying power**, **deployment %**, **positions held**, **open orders**.
- Pulled from `./scripts/alpaca.sh account` and `positions`. Raw, not interpreted.

### Market Context
- S&P 500 futures direction (Tavily query).
- VIX level (Tavily query).
- Oil & major commodities headline (Tavily).
- Pre-market earnings of note (Tavily).
- Economic calendar: any high-impact prints today (Tavily).
- Sector momentum signal (tech / financials / energy / healthcare).
- Per-held-ticker news scan: any catalyst on anything currently owned.

### Trade Ideas
- Up to 3 ideas. Each one has: `symbol`, `catalyst` (why buy today), `entry` (price zone), `stop` (10% trail from entry), `target` (optional), `decision` (default **HOLD** unless the catalyst is clean and live).
- Tickers structurally excluded by tier sizing must **not** appear as ideas.
- `decision: BUY` carries a commitment: market-open will try to execute it provided all gate checks still pass.

---

## Seed

Research will begin with the first pre-market routine firing. Entries land above
this line.
