#!/usr/bin/env bash
# Protects against secrets leaking into git history and line-ending corruption.

assert_file_exists "$ROOT/.gitignore" ".gitignore exists"
assert_file_contains "$ROOT/.gitignore" "^\.env$" ".gitignore excludes .env"
assert_file_contains "$ROOT/.gitignore" "^\.env\." ".gitignore excludes .env.* variants"

assert_file_exists "$ROOT/.gitattributes" ".gitattributes exists"
assert_file_contains "$ROOT/.gitattributes" "text=auto[[:space:]]+eol=lf" ".gitattributes normalizes EOL to LF"
assert_file_contains "$ROOT/.gitattributes" "\*\.sh[[:space:]]+text[[:space:]]+eol=lf" ".gitattributes forces LF on *.sh"

# Defence-in-depth: .env must exist (user filled it in) but must not be tracked.
assert_file_exists "$ROOT/.env" ".env is present locally (for local runs)"

# If a git repo exists, verify .env is actually ignored.
if [ -d "$ROOT/.git" ]; then
  ( cd "$ROOT" && git check-ignore -q .env ) && \
    _pass "git check-ignore agrees .env is ignored" || \
    _fail "git check-ignore agrees .env is ignored" ".env is NOT ignored by git"
fi
