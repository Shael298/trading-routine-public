#!/usr/bin/env bash
# Cloud routine prompts — one .md per scheduled firing. Each is the full
# prompt copy-pasted into the Claude Code cloud routine configuration.
# This test pins existence, required steps, and cross-references.

R="$ROOT/cloud-routines"
assert_dir_exists "$R" "cloud-routines/ exists"

for name in before-market-opening market-opening afternoon-review earnings-risk-check EOD-summary EOW-summary; do
  assert_file_exists "$R/$name.md" "$name.md exists"
  assert_file_contains "$R/$name.md" "Europe/London"          "$name pins Europe/London"
  assert_file_contains "$R/$name.md" "git (add|commit|push)"  "$name commits to git"
  assert_file_contains "$R/$name.md" "telegram"               "$name notifies via telegram"
done

# Before market opening: research only, no orders.
assert_file_contains "$R/before-market-opening.md" "tavily"             "before-market-opening runs research"
assert_file_contains "$R/before-market-opening.md" "RESEARCH-LOG"       "before-market-opening writes research log"
assert_file_contains "$R/before-market-opening.md" "[Nn]o orders"       "before-market-opening states: no orders"

# Market opening: gate + buy + mandatory stop.
assert_file_contains "$R/market-opening.md" "gate.sh"            "market-opening runs gate"
assert_file_contains "$R/market-opening.md" "trailing.stop"      "market-opening places trailing stop"
assert_file_contains "$R/market-opening.md" "same.firing"        "market-opening places stop in same firing"
assert_file_contains "$R/market-opening.md" "TRADE-LOG"          "market-opening appends to trade log"

# Afternoon review: sell-side logic.
assert_file_contains "$R/afternoon-review.md" "sell.side"          "afternoon review runs sell-side logic"
assert_file_contains "$R/afternoon-review.md" "-8%"                "afternoon review enforces -8% cut"
assert_file_contains "$R/afternoon-review.md" "14%"                "afternoon review applies 14% tighten"
assert_file_contains "$R/afternoon-review.md" "18%"                "afternoon review applies 18% tighten"

# Daily summary: EOD snapshot.
assert_file_contains "$R/EOD-summary.md" "EOD"                "EOD-summary writes EOD snapshot"
assert_file_contains "$R/EOD-summary.md" "TRADE-LOG"          "EOD-summary appends to trade log"
assert_file_contains "$R/EOD-summary.md" "notification_fallback" "EOD-summary drains fallback log"

# Earnings risk check: research only, no orders, flags binary events.
assert_file_contains "$R/earnings-risk-check.md" "tavily"             "earnings-risk-check runs research"
assert_file_contains "$R/earnings-risk-check.md" "RESEARCH-LOG"       "earnings-risk-check writes research log"
assert_file_contains "$R/earnings-risk-check.md" "[Nn]o orders"       "earnings-risk-check states: no orders"
assert_file_contains "$R/earnings-risk-check.md" "earnings"           "earnings-risk-check checks for earnings events"
assert_file_contains "$R/earnings-risk-check.md" "2 trading days"     "earnings-risk-check uses 2-day window"

# Weekly summary: Friday, grade A-F.
assert_file_contains "$R/EOW-summary.md" "WEEKLY-REVIEW"      "EOW-summary appends to WEEKLY-REVIEW.md"
assert_file_contains "$R/EOW-summary.md" "A.F"                "EOW-summary applies A-F grading"
assert_file_contains "$R/EOW-summary.md" "Friday"             "EOW-summary runs Friday"
assert_file_contains "$R/EOW-summary.md" "TRADING-STRATEGY"   "EOW-summary may edit strategy"

# Every routine reads memory.
for f in "$R"/*.md; do
  name=$(basename "$f" .md)
  assert_file_contains "$f" "memory/" "$name reads memory/"
done
