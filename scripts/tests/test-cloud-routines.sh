#!/usr/bin/env bash
# Cloud routine prompts — one .md per scheduled firing. Each is the full
# prompt copy-pasted into the Claude Code cloud routine configuration.
# This test pins existence, required steps, and cross-references.

R="$ROOT/cloud-routines"
assert_dir_exists "$R" "cloud-routines/ exists"

for name in pre-market market-open midday earnings-risk-check daily-summary weekly-review; do
  assert_file_exists "$R/$name.md" "$name.md exists"
  assert_file_contains "$R/$name.md" "Europe/London"          "$name pins Europe/London"
  assert_file_contains "$R/$name.md" "git (add|commit|push)"  "$name commits to git"
  assert_file_contains "$R/$name.md" "telegram"               "$name notifies via telegram"
done

# Pre-market: research only, no orders.
assert_file_contains "$R/pre-market.md"    "tavily"             "pre-market runs research"
assert_file_contains "$R/pre-market.md"    "RESEARCH-LOG"       "pre-market writes research log"
assert_file_contains "$R/pre-market.md"    "[Nn]o orders"       "pre-market states: no orders"

# Market-open: gate + buy + mandatory stop.
assert_file_contains "$R/market-open.md"   "gate.sh"            "market-open runs gate"
assert_file_contains "$R/market-open.md"   "trailing.stop"      "market-open places trailing stop"
assert_file_contains "$R/market-open.md"   "same.firing"        "market-open places stop in same firing"
assert_file_contains "$R/market-open.md"   "TRADE-LOG"          "market-open appends to trade log"

# Midday: sell-side logic.
assert_file_contains "$R/midday.md"        "sell.side"          "midday runs sell-side logic"
assert_file_contains "$R/midday.md"        "-7%"                "midday enforces -7% cut"
assert_file_contains "$R/midday.md"        "15%"                "midday applies 15% tighten"
assert_file_contains "$R/midday.md"        "20%"                "midday applies 20% tighten"

# Daily summary: EOD snapshot.
assert_file_contains "$R/daily-summary.md" "EOD"                "daily-summary writes EOD snapshot"
assert_file_contains "$R/daily-summary.md" "TRADE-LOG"          "daily-summary appends to trade log"
assert_file_contains "$R/daily-summary.md" "notification_fallback" "daily-summary drains fallback log"

# Earnings risk check: research only, no orders, flags binary events.
assert_file_contains "$R/earnings-risk-check.md" "tavily"             "earnings-risk-check runs research"
assert_file_contains "$R/earnings-risk-check.md" "RESEARCH-LOG"       "earnings-risk-check writes research log"
assert_file_contains "$R/earnings-risk-check.md" "[Nn]o orders"       "earnings-risk-check states: no orders"
assert_file_contains "$R/earnings-risk-check.md" "earnings"           "earnings-risk-check checks for earnings events"
assert_file_contains "$R/earnings-risk-check.md" "2 trading days"     "earnings-risk-check uses 2-day window"

# Weekly review: Friday, grade A–F.
assert_file_contains "$R/weekly-review.md" "WEEKLY-REVIEW"      "weekly-review appends to WEEKLY-REVIEW.md"
assert_file_contains "$R/weekly-review.md" "A.F"                "weekly-review applies A–F grading"
assert_file_contains "$R/weekly-review.md" "Friday"             "weekly-review runs Friday"
assert_file_contains "$R/weekly-review.md" "TRADING-STRATEGY"   "weekly-review may edit strategy"

# Every routine reads memory.
for f in "$R"/*.md; do
  name=$(basename "$f" .md)
  assert_file_contains "$f" "memory/" "$name reads memory/"
done
