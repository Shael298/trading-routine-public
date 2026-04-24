#!/usr/bin/env bash
# Documentation must exist and cover the operator-critical surface.

README="$ROOT/README.md"
SETUP="$ROOT/docs/SETUP.md"

assert_file_exists "$README" "README.md exists"
assert_file_contains "$README" "Trading Routine"         "README names the project"
assert_file_contains "$README" "paper"                   "README: paper-first"
assert_file_contains "$README" "Alpaca"                  "README names Alpaca"
assert_file_contains "$README" "Tavily"                  "README names Tavily"
assert_file_contains "$README" "Telegram"                "README names Telegram"
assert_file_contains "$README" "scripts/tests/run-all.sh" "README: how to run tests"
assert_file_contains "$README" "env.template"            "README: env.template for local"
assert_file_contains "$README" "cloud-routines/"         "README points to cloud-routines"
assert_file_contains "$README" ".claude/commands"        "README points to slash commands"
assert_file_contains "$README" "memory/"                 "README points to memory/"
assert_file_contains "$README" "[Kk]ill"                 "README documents the kill-switch"
assert_file_contains "$README" "paper.*live|live.*paper" "README mentions paper→live progression"

assert_file_exists "$SETUP" "docs/SETUP.md exists"
assert_file_contains "$SETUP" "Alpaca"                   "SETUP covers Alpaca"
assert_file_contains "$SETUP" "Tavily"                   "SETUP covers Tavily"
assert_file_contains "$SETUP" "Telegram"                 "SETUP covers Telegram"
assert_file_contains "$SETUP" "env.template"             "SETUP describes env.template"
assert_file_contains "$SETUP" "Claude Code"              "SETUP covers Claude Code cloud routines"
assert_file_contains "$SETUP" "Europe/London"            "SETUP documents schedule timezone"
assert_file_contains "$SETUP" "Runbook"                  "SETUP has a runbook section"
