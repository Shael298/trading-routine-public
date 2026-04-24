#!/usr/bin/env bash
# Memory seed files must exist and contain the load-bearing schema anchors that
# every routine depends on. These aren't tests of content quality — they're tests
# that the structural invariants are in place so routines can grep/append reliably.

MEM="$ROOT/memory"

# 1. All 5 memory files exist.
assert_file_exists "$MEM/TRADING-STRATEGY.md" "TRADING-STRATEGY.md exists"
assert_file_exists "$MEM/TRADE-LOG.md"        "TRADE-LOG.md exists"
assert_file_exists "$MEM/RESEARCH-LOG.md"     "RESEARCH-LOG.md exists"
assert_file_exists "$MEM/WEEKLY-REVIEW.md"    "WEEKLY-REVIEW.md exists"
assert_file_exists "$MEM/PROJECT-CONTEXT.md"  "PROJECT-CONTEXT.md exists"

# 2. TRADING-STRATEGY.md — tier table + all hard rules verbatim.
STRAT="$MEM/TRADING-STRATEGY.md"
assert_file_contains "$STRAT" "Tier 1"                         "strategy mentions Tier 1"
assert_file_contains "$STRAT" "Tier 2"                         "strategy mentions Tier 2"
assert_file_contains "$STRAT" "Tier 3"                         "strategy mentions Tier 3"
assert_file_contains "$STRAT" "40%"                            "strategy encodes 40% cap"
assert_file_contains "$STRAT" "6"                              "strategy encodes 6-position cap"
assert_file_contains "$STRAT" "10% trailing stop"              "strategy encodes 10% trailing stop"
assert_file_contains "$STRAT" "GTC"                            "strategy encodes GTC enforcement"
assert_file_contains "$STRAT" "-7%"                            "strategy encodes -7% cut"
assert_file_contains "$STRAT" "15%"                            "strategy encodes 15% tighten threshold"
assert_file_contains "$STRAT" "20%"                            "strategy encodes 20% tighten threshold"
assert_file_contains "$STRAT" "Whole shares only"              "strategy encodes whole shares only"
assert_file_contains "$STRAT" "5 new trades per week"          "strategy encodes 5 trades/week cap"
assert_file_contains "$STRAT" "pulled back 5"                  "strategy encodes constructive-pullback preference"
assert_file_contains "$STRAT" "50-day MA"                      "strategy names the 50-day MA in pullback preference"
assert_file_contains "$STRAT" "Pyramid"                        "strategy documents pyramid rule"
assert_file_contains "$STRAT" "weighted-average"               "strategy describes weighted-average break-even stop"
assert_file_contains "$STRAT" "pyramid-not-yet-winning"        "strategy lists pyramid-not-yet-winning tag"
assert_file_contains "$STRAT" "75" "strategy encodes deployment target lower bound"
assert_file_contains "$STRAT" "85" "strategy encodes deployment target upper bound"
assert_file_contains "$STRAT" "PDT"                            "strategy encodes PDT guard"
assert_file_contains "$STRAT" "## Hard Rules"                  "strategy has Hard Rules section"
assert_file_contains "$STRAT" "## Buy-side Gate"               "strategy has Buy-side Gate section"
assert_file_contains "$STRAT" "## Sell-side Logic"             "strategy has Sell-side Logic section"

# 3. RESEARCH-LOG.md — expected subsection headers so routines can grep.
RES="$MEM/RESEARCH-LOG.md"
assert_file_contains "$RES" "### Account Snapshot"  "research log documents Account Snapshot subsection"
assert_file_contains "$RES" "### Market Context"    "research log documents Market Context subsection"
assert_file_contains "$RES" "### Trade Ideas"       "research log documents Trade Ideas subsection"

# 4. TRADE-LOG.md — EOD snapshot format documented.
TL="$MEM/TRADE-LOG.md"
assert_file_contains "$TL" "EOD"              "trade log documents EOD snapshot format"
assert_file_contains "$TL" "Positions"        "trade log documents Positions table"

# 5. WEEKLY-REVIEW.md — grading scale present.
WR="$MEM/WEEKLY-REVIEW.md"
assert_file_contains "$WR" "Grade"            "weekly review documents grading scale"
assert_file_contains "$WR" "A–F|A-F"          "weekly review shows A–F letter range"

# 6. PROJECT-CONTEXT.md — mission + platform baseline present.
PC="$MEM/PROJECT-CONTEXT.md"
assert_file_contains "$PC" "Mission"          "project context has Mission section"
assert_file_contains "$PC" "Alpaca"           "project context names Alpaca"
assert_file_contains "$PC" "Europe/London"    "project context pins timezone"
