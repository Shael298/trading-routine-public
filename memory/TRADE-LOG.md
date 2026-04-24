# Trade Log

Every buy, sell, stop placement, stop cancel, and daily EOD snapshot lives here.
Append-only. Newest entries at the **top** (reverse chronological).

Written by: `market-open`, `midday`, `daily-summary`, `/trade` local command.

---

## Entry format

Each entry is a dated section. Two templates:

### Template: trade entry

```
## 2026-04-21 14:46 BUY AAPL 1 @ $240.10
- **Gate**: approved (0 reasons blocking)
- **Cost**: $240.10 / $1000 equity (24.01%)
- **Cash after**: $759.90
- **Trailing stop**: 10% GTC order #abc-123, submitted 14:47
- **Catalyst**: (from research log) — earnings beat, guidance raise
- **Thesis**: Q3 print + guide hike; hold to $270 or trail
- **Risk**: gap-down overnight through stop
```

### Template: EOD snapshot (written by daily-summary routine at 21:05 UK)

```
## 2026-04-21 EOD
- **Equity**: $1,004.50 (+0.45% day, +0.45% since 2026-04-20)
- **Cash**: $759.90 (76.0% deployed)
- **Positions** (1):

| Symbol | Qty | Entry | Last | P&L% | Stop | Days held |
|--------|-----|-------|------|------|------|-----------|
| AAPL   | 1   | 240.10| 244.60| +1.87% | 220.14 (trail 10%) | 0 |

- **Today's trades**: 1 buy, 0 sells
- **Week-to-date**: 1/5 new trades used
- **Notes**: Quiet session. AAPL pushed into close. Watching for continuation tomorrow.
```

---

## Seed

No trades yet. First entry will appear above this line after the first market-open routine fires.
