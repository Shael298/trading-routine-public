#!/usr/bin/env bash
# gate.sh — pure-function buy-side gate.
#
# Reads a trade-idea JSON object on stdin. Writes a decision JSON object on
# stdout. Never touches the network or the filesystem. Every rule in
# `memory/TRADING-STRATEGY.md` § "Buy-side Gate" is enforced here; when a
# rule changes there, update this file in the same commit.
#
# Input shape:
#   { symbol, qty, price, equity, cash, positions_count, weekly_trades,
#     daytrade_count, has_catalyst, is_stock, is_fractional,
#     is_pyramid, existing_shares, existing_cost_basis, existing_unrealized_plpc }
#
# The last four fields default to 0 / false when omitted — plain first-entry
# buys don't need to supply them. Pyramid adds (is_pyramid: true) must
# populate all three existing_* fields from the live position.
#
# Output shape:
#   { approved: bool, reasons: [tag, ...], tier: 1|2|3, sizing: {...} }
#
# Reason tags (stable vocabulary — routines match on these):
#   not-a-stock · fractional-not-allowed · tier-size-exceeded · insufficient-cash
#   positions-cap · weekly-trade-cap · pdt-guard · no-catalyst · malformed-qty
#   pyramid-no-existing-position · pyramid-not-yet-winning · pyramid-add-too-large
#
# Exit codes: 0 on clean decision (approved or not), 2 on malformed input.

set -u

input=$(cat)

if ! printf '%s' "$input" | jq -e . >/dev/null 2>&1; then
  echo "gate.sh: stdin is not valid JSON" >&2
  exit 2
fi

# jq does all the work. Floats are compared as numbers; integers as integers.
# Tier picker: equity ≤ $2k → T1/40%/6; ≤ $5k → T2/30%/5; else T3/20%/6.
printf '%s' "$input" | jq '
  def tier_for(eq):
    if eq <= 2000 then {tier:1, pct:0.40, max_positions:6}
    elif eq <= 5000 then {tier:2, pct:0.30, max_positions:5}
    else {tier:3, pct:0.20, max_positions:6}
    end;

  . as $in
  | ($in.is_pyramid // false) as $pyr
  | tier_for($in.equity) as $t
  | ($in.qty * $in.price) as $add_cost
  | (($in.existing_cost_basis // 0) + $add_cost) as $combined_cost
  | ($in.equity * $t.pct) as $tier_max_dollars
  | ($in.existing_shares // 0) as $ex_sh
  | ($in.existing_unrealized_plpc // 0) as $ex_plpc
  | [
      (if ($in.is_stock // false) then empty else "not-a-stock" end),
      (if ($in.is_fractional // false) then "fractional-not-allowed" else empty end),
      (if ($in.qty // 0) <= 0 or (($in.qty // 0) | floor) != ($in.qty // 0) then "malformed-qty" else empty end),
      (if $combined_cost > $tier_max_dollars then "tier-size-exceeded" else empty end),
      (if $add_cost > ($in.cash // 0) then "insufficient-cash" else empty end),
      # positions-cap and weekly-trade-cap skip for pyramid adds (not a new position, not a new trade).
      (if $pyr then empty
       elif (($in.positions_count // 0) + 1) > $t.max_positions then "positions-cap"
       else empty end),
      (if $pyr then empty
       elif (($in.weekly_trades // 0) + 1) > 5 then "weekly-trade-cap"
       else empty end),
      (if ($in.daytrade_count // 0) >= 3 then "pdt-guard" else empty end),
      (if ($in.has_catalyst // false) then empty else "no-catalyst" end),
      # Pyramid-only rules.
      (if $pyr and $ex_sh <= 0 then "pyramid-no-existing-position" else empty end),
      (if $pyr and $ex_plpc < 0.15 then "pyramid-not-yet-winning" else empty end),
      (if $pyr and $ex_sh > 0 and ($in.qty // 0) > (($ex_sh / 2) | floor) then "pyramid-add-too-large" else empty end)
    ] as $reasons
  | {
      approved: (($reasons | length) == 0),
      reasons: $reasons,
      tier: $t.tier,
      sizing: {
        tier_pct: $t.pct,
        tier_max_dollars: $tier_max_dollars,
        add_cost_dollars: $add_cost,
        combined_cost_dollars: $combined_cost,
        cash: $in.cash,
        positions_count: $in.positions_count,
        max_positions: $t.max_positions,
        is_pyramid: $pyr,
        wavg_cost_per_share: (if $pyr and ($ex_sh + ($in.qty // 0)) > 0
                              then (($in.existing_cost_basis // 0) + $add_cost) / ($ex_sh + $in.qty)
                              else null end)
      }
    }
'
