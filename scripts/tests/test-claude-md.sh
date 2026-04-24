#!/usr/bin/env bash
# CLAUDE.md is the master rulebook loaded at the start of every routine. It
# contains a set of invariants that, if silently deleted, would let the bot
# misbehave in ways no other test would catch. This test pins those phrases
# so a future edit can't quietly drop them.

CM="$ROOT/CLAUDE.md"
assert_file_exists "$CM" "CLAUDE.md exists at repo root"

# Identity & scope.
assert_file_contains "$CM" "Trading Routine"                         "CLAUDE.md names the project"
assert_file_contains "$CM" "Europe/London"                           "CLAUDE.md pins the timezone"
assert_file_contains "$CM" "paper"                                   "CLAUDE.md says paper account"

# Workflow discipline.
assert_file_contains "$CM" "read memory"                             "CLAUDE.md: read-memory step"
assert_file_contains "$CM" "commit"                                  "CLAUDE.md: commit step"
assert_file_contains "$CM" "notify"                                  "CLAUDE.md: notify step"

# Script-only I/O boundary.
assert_file_contains "$CM" "scripts/alpaca.sh"                       "CLAUDE.md: alpaca wrapper is the only broker I/O"
assert_file_contains "$CM" "scripts/telegram.sh"                     "CLAUDE.md: telegram wrapper is the only notifier"
assert_file_contains "$CM" "scripts/tavily.sh"                       "CLAUDE.md: tavily wrapper is the only research call"
assert_file_contains "$CM" "scripts/gate.sh"                         "CLAUDE.md: gate.sh is the buy decision"
assert_file_contains "$CM" "never.*curl"                             "CLAUDE.md forbids direct curl to third parties"

# Invariants from PROJECT-CONTEXT.
assert_file_contains "$CM" "If it isn't pushed"                      "CLAUDE.md: git-as-truth rule"
assert_file_contains "$CM" "never create .env"                       "CLAUDE.md: cloud never creates .env"
assert_file_contains "$CM" "GTC trailing stop"                       "CLAUDE.md: GTC trail rule"

# Memory file roles.
assert_file_contains "$CM" "TRADING-STRATEGY.md"                     "CLAUDE.md points to strategy"
assert_file_contains "$CM" "TRADE-LOG.md"                            "CLAUDE.md points to trade log"
assert_file_contains "$CM" "RESEARCH-LOG.md"                         "CLAUDE.md points to research log"
assert_file_contains "$CM" "WEEKLY-REVIEW.md"                        "CLAUDE.md points to weekly review"
assert_file_contains "$CM" "PROJECT-CONTEXT.md"                      "CLAUDE.md points to project context"
assert_file_contains "$CM" "append-only"                             "CLAUDE.md: logs are append-only"
assert_file_contains "$CM" "read-only"                               "CLAUDE.md: strategy is read-only"

# Fail-open vs fail-closed.
assert_file_contains "$CM" "fail.closed"                             "CLAUDE.md: broker/gate fail closed"
assert_file_contains "$CM" "fail.open"                               "CLAUDE.md: telegram fails open (silent fallback)"

# Routine topology.
assert_file_contains "$CM" "pre-market"                              "CLAUDE.md names pre-market routine"
assert_file_contains "$CM" "market-open"                             "CLAUDE.md names market-open routine"
assert_file_contains "$CM" "midday"                                  "CLAUDE.md names midday routine"
assert_file_contains "$CM" "daily-summary"                           "CLAUDE.md names daily-summary routine"
assert_file_contains "$CM" "weekly-review"                           "CLAUDE.md names weekly-review routine"
assert_file_contains "$CM" "earnings-risk-check"                     "CLAUDE.md names earnings-risk-check routine"

# Kill switch.
assert_file_contains "$CM" "revoke"                                  "CLAUDE.md documents GitHub App revoke kill-switch"
