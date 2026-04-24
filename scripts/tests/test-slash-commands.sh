#!/usr/bin/env bash
# Local slash commands live under .claude/commands/*.md. Each is a prompt
# the operator triggers from the Claude Code CLI. This test pins their
# existence and confirms each references the wrapper(s) it should drive.

CMDS="$ROOT/.claude/commands"
assert_dir_exists "$CMDS" ".claude/commands exists"

for name in status idea gate buy close research review; do
  assert_file_exists "$CMDS/$name.md" "/$name command exists"
done

# Each command should invoke the wrapper that does the real work.
assert_file_contains "$CMDS/status.md"   "scripts/alpaca.sh"   "/status uses alpaca.sh"
assert_file_contains "$CMDS/idea.md"     "scripts/gate.sh"     "/idea uses gate.sh"
assert_file_contains "$CMDS/gate.md"     "scripts/gate.sh"     "/gate uses gate.sh"
assert_file_contains "$CMDS/buy.md"      "scripts/gate.sh"     "/buy runs gate.sh first"
assert_file_contains "$CMDS/buy.md"      "scripts/alpaca.sh"   "/buy uses alpaca.sh"
assert_file_contains "$CMDS/buy.md"      "trailing.stop"       "/buy mandates trailing stop"
assert_file_contains "$CMDS/close.md"    "scripts/alpaca.sh"   "/close uses alpaca.sh"
assert_file_contains "$CMDS/research.md" "scripts/tavily.sh"   "/research uses tavily.sh"
assert_file_contains "$CMDS/research.md" "WebSearch"           "/research names WebSearch fallback"
assert_file_contains "$CMDS/review.md"   "WEEKLY-REVIEW.md"    "/review reads WEEKLY-REVIEW.md"
assert_file_contains "$CMDS/review.md"   "TRADE-LOG.md"        "/review reads TRADE-LOG.md"

# Commands that WRITE to TRADE-LOG must declare append-only discipline.
# (Read-only references don't need the reminder — catches copy-paste drift
# in the mutating commands specifically.)
for name in buy close; do
  assert_file_contains "$CMDS/$name.md" "[Aa]ppend.only" "/$name respects append-only for TRADE-LOG"
done

# Every command's frontmatter has a description.
for f in "$CMDS"/*.md; do
  name=$(basename "$f" .md)
  assert_file_contains "$f" "^description:" "/$name has frontmatter description"
done
