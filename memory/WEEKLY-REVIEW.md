# Weekly Review

Friday 21:10 UK, after the daily-summary routine. Reviews the full trading week and
assigns a **Grade A–F**. If a grade ≤ C repeats 2 weeks, the weekly-review routine
must propose a concrete rule change in `TRADING-STRATEGY.md` in the same commit.

Append-only, newest at the **top**.

---

## Grading scale (A–F)

| Grade | Criteria |
|-------|----------|
| **A** | +2% or better week, discipline 100% (no rule violations), ≥ 50% win rate |
| **B** | +0.5 to +2% week OR flat week with perfect discipline, no violations |
| **C** | Flat to -1% week, minor discipline slip (one tightening-too-close or late-cut), process sound |
| **D** | -1% to -3% week OR one material rule violation (missed stop, oversized position, weekly-trade cap breached) |
| **F** | Worse than -3% week OR multiple rule violations OR an un-stopped loss |

A "rule violation" is measured against `TRADING-STRATEGY.md` as-of the start of the week.

---

## Entry template

```
## 2026-W17 (2026-04-20 → 2026-04-24)

**Grade: B**

| Metric | Value |
|--------|-------|
| Start equity | $1,000.00 |
| End equity   | $1,013.40 (+1.34%) |
| vs S&P 500   | +0.41 pp |
| Trades       | 3 (2 win, 1 loss) |
| Win rate     | 66% |
| Profit factor| 2.1 |
| Best trade   | AAPL +4.8% |
| Worst trade  | NVDA -3.1% |
| Open EOW     | 2 |

**What worked**: catalyst-led entries on earnings beats; disciplined trail tightening on AAPL.

**What didn't**: NVDA entered without clean catalyst (gap-n-go momentum only) — 7% cut fired; rule 7 held.

**Strategy changes**: None. Grade B two weeks running is the threshold to start relaxing if it continues.

**Next-week focus**: Tighter catalyst standard — no "momentum only" ideas.
```

---

## Seed

No weeks reviewed yet. First entry will appear above this line after the first
Friday weekly-review routine fires.
