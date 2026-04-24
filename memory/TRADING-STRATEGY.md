# Trading Strategy — Rulebook

The authoritative rulebook every routine obeys. The Friday weekly-review routine is
the **only** routine permitted to edit this file, and only when a rule has proven
itself 2+ weeks or failed badly. All other routines treat this file as read-only.

**Last reviewed:** 2026-04-22 (added pyramid rule + constructive-pullback preference; weekly cap 3→5)

---

## Mission

Grow the paper account from **$1,000 → $1,100 per month (~10%)** through
disciplined swing trading on quality US equities. Aspirational — not a gate.
Discipline > hit rate.

---

## Tier Table (position sizing auto-relaxes as equity grows)

The bot picks the tier matching current `account.equity` at the moment of the buy-side gate check.

| Tier | Equity | Max per position | Max positions |
|------|--------|------------------|---------------|
| **Tier 1 (current)** | ≤ $2,000 | **40%** | **6** |
| Tier 2 | $2,001 – $5,000 | 30% | 5 |
| Tier 3 | > $5,000 | 20% | 6 |

At Tier 1, META (~$550) and MSFT (~$420) are structurally excluded because 1 share
exceeds 40% of $1,000. Once equity crosses $2,000, MSFT becomes reachable. Once
equity crosses $5,000, META too. This is a feature, not a bug: small accounts buy
smaller names and learn on lower risk.

---

## Hard Rules (non-negotiable gates)

Rules 1–8, 12, and 13 are enforced *inside* `scripts/gate.sh` at buy time (pure
function, stdin → stdout). Rules 7–11 are cross-trade or post-fill concerns
— they're enforced by the **market-open** and **midday** cloud routines,
not by gate.sh, because they need state the gate payload doesn't carry
(fill confirmations, sector history, live stop-order ids).

1. **No options. Stocks only.** Anything with `asset_class != "us_equity"` is rejected.
2. **Whole shares only.** Fractional shares can't carry GTC stops on Alpaca — rejected.
3. **Tiered sizing.** Max cost ≤ tier % of current equity (see table above). Current Tier 1 = **40%**. For a pyramid add, the check is against the *combined* position cost (starter + add), not the add alone.
4. **Max positions.** Total concurrent positions ≤ tier cap. Current Tier 1 = **6**. A pyramid add into an existing name does **not** count as a new position.
5. **Weekly new-trade cap.** Max **5 new trades per week** (Mon–Fri rolling, measured at gate time). Pyramid adds **do not** count against this cap — they are not new trades.
6. **Deployment target.** Target **75–85%** of equity deployed. Outside that band, research log should flag it.
7. **Trailing stop on entry.** Every filled buy ⇒ immediately place **10% trailing stop** as a **real GTC order** on Alpaca. No mental stops. No synthetic stops.
8. **Cut at -7%.** If P&L ≤ -7% from entry, manual market sell + cancel trail. Don't wait for trail to catch up.
9. **Tighten on winners.** Up ≥ 15% → tighten trailing stop to 7%. Up ≥ 20% → tighten to 5%.
10. **Never worsen a stop.** Never move a stop down. Never tighten within 3% of current price (instant-fill risk).
11. **Sector kill-switch.** After **2 consecutive failed trades in a sector**, exit the entire sector and flag in research log.
12. **PDT guard.** On accounts < $25k, `daytrade_count` must be **< 3** before any buy (preserves headroom for same-day exit).
13. **Pyramid gating.** A pyramid add requires an *existing* position in the symbol that is up **≥ 15%** from cost basis. The add qty ≤ ½ starter qty (integer floor). One pyramid per position, ever. After the add, the stop is replaced with a **fixed stop at the weighted-average cost basis** (break-even) — converting paper gains into a free shot at more upside.

---

## Buy-side Gate (every buy passes all of these, OR the trade is rejected)

Implemented in `scripts/gate.sh` — pure function, stdin JSON → stdout JSON. Input shape:

```json
{
  "symbol": "AAPL",
  "qty": 1,
  "price": 240.00,
  "equity": 1000.00,
  "cash": 990.00,
  "positions_count": 2,
  "weekly_trades": 1,
  "daytrade_count": 0,
  "has_catalyst": true,
  "is_stock": true,
  "is_fractional": false,
  "is_pyramid": false,
  "existing_shares": 0,
  "existing_cost_basis": 0,
  "existing_unrealized_plpc": 0
}
```

The last four fields default to 0 / false when omitted — a plain first-entry buy
doesn't need to supply them. For a pyramid add the caller must set `is_pyramid:
true` and populate the three `existing_*` fields from `alpaca.sh positions`.

Output shape: `{"approved": true|false, "reasons": [...], "tier": N, "sizing": {...}}`. Every failing rule is appended.

Gate enforces:
- `positions_count + 1 ≤ tier_max_positions` (skipped for pyramid adds — no new position)
- `weekly_trades + 1 ≤ 5` (skipped for pyramid adds — not a new trade)
- `(existing_cost_basis + qty * price) ≤ equity * tier_max_pct` — cost cap is on the *combined* position
- `qty * price ≤ cash`
- `daytrade_count < 3`
- `has_catalyst == true` (today's research log documents a specific reason to buy)
- `is_stock == true`
- `is_fractional == false`
- **Pyramid-only rules** (when `is_pyramid == true`):
  - `existing_shares > 0` (otherwise tag `pyramid-no-existing-position`)
  - `existing_unrealized_plpc ≥ 0.15` (otherwise tag `pyramid-not-yet-winning`)
  - `qty ≤ floor(existing_shares / 2)` (otherwise tag `pyramid-add-too-large`)
- EPS growth ≥ 15% and solid fundamentals are **preferences**, logged in research — not a hard block.

---

## Entry preference — constructive pullback on quality

A first-entry buy should ideally be on a name that has **pulled back 5–15% from
its recent 20-day swing high** while still holding **above its 50-day moving
average**, and whose **fundamentals are intact** (EPS growth ≥ 15% YoY, revenue
growth positive, no major unresolved thesis risk).

This is a **preference**, not a hard block. If a trade fails the pullback test
but the catalyst is strong, document the override in the research log. If a
trade fails the fundamentals test, strongly reconsider — fundamental weakness
plus technical weakness = no trade.

The research routines (`pre-market`, `idea`) compute pullback % and 50-day MA
status for every candidate and log them in `RESEARCH-LOG.md` alongside the
catalyst. `market-open` refuses to execute an idea whose research entry doesn't
contain either a constructive-pullback datapoint or an explicit override note.

Pyramid adds are **exempt** from this preference — the +15% unrealized gain is
its own proof of strength, and an add by definition isn't a first entry.

---

## Sell-side Logic (midday + opportunistic)

Evaluated in order. First match wins.

1. **P&L ≤ -7% from entry** → market sell + cancel trail + log exit (`reason: stop-loss-cut`).
2. **Thesis broken** (catalyst reversed, sector kill-switch fired, material news against) → market sell + cancel trail + log exit (`reason: thesis-broken`).
3. **Up ≥ 20%** → tighten trailing stop to 5% (cancel + recreate). Never within 3% of current price.
4. **Up ≥ 15%** → tighten trailing stop to 7% (cancel + recreate). Never within 3% of current price.
5. **Sector has 2 consecutive failures** → flat the entire sector + 2-week cooldown.

For positions that have been pyramided, sell-side rules apply to the *combined*
position. The fixed break-even stop placed at pyramid time remains in force
until the position either stops out (P&L ≈ 0, logged `pyramid-break-even-stop`)
or hits +20% from weighted-average cost — at which point rule 3 converts the
fixed stop to a 5% trailing stop and normal winner-tighten mechanics resume.

---

## Aspirational Targets (not gates)

- **10% monthly growth** on paper (then on live, once validated).
- **≥ 50% win rate** when averaged over any rolling 4-week window.
- **Profit factor ≥ 1.5** (gross wins / gross losses, rolling 4 weeks).
- **≤ 20% max drawdown** from any intra-week peak.

If any of these slip for 2 consecutive weekly reviews, Friday's routine is expected
to audit the rulebook and propose a concrete rule change (committed in the same push).
