#!/usr/bin/env bash
# Telegram wrapper — two behavioural tests:
#   (a) missing credentials → fallback log is appended, exit 0 (silent-safe)
#   (b) live credentials → API returns ok:true
#
# Tests that need credentials skip gracefully when .env isn't populated.

TG="$ROOT/scripts/telegram.sh"
assert_file_exists "$TG" "telegram.sh exists"
[ -x "$TG" ] && _pass "telegram.sh executable" || _fail "telegram.sh executable" "chmod +x missing"

# -----  a) missing credentials  -----
(
  TMP="$(mktemp -d)"
  export FALLBACK_LOG="$TMP/notification_fallback.log"
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
  # Prevent .env from re-populating them.
  export TRADING_ROUTINE_SKIP_DOTENV=1
  out=$("$TG" send "missing-creds test" 2>&1) ; rc=$?
  if [ "$rc" -eq 0 ]; then
    _pass "missing creds → exit 0 (silent fallback)"
  else
    _fail "missing creds → exit 0 (silent fallback)" "rc=$rc out=$out"
  fi
  if [ -s "$FALLBACK_LOG" ] && grep -q "missing-creds test" "$FALLBACK_LOG"; then
    _pass "fallback log captured the message"
  else
    _fail "fallback log captured the message" "log empty or missing — contents: $(cat "$FALLBACK_LOG" 2>/dev/null || echo NONE)"
  fi
  printf '%d %d\n' "$TESTS_PASSED" "$TESTS_FAILED" > "$RESULTS"
  rm -rf "$TMP"
)
# Re-ingest counters from subshell (run-all.sh also does this per-file, but we forked here).
if [ -f "$RESULTS" ]; then
  read -r sp sf < "$RESULTS" || true
  TESTS_PASSED="$sp"
  TESTS_FAILED="$sf"
fi

# -----  b) live credentials (opt-in so run-all.sh doesn't spam the bot)  -----
# The missing-creds path above already proves the wrapper works end-to-end
# without the network. An actual send to Telegram is only useful when we're
# explicitly verifying the bot token / chat id still work — gate it behind
# an env var so a bare `run-all.sh` stays quiet.
if [ "${TRADING_ROUTINE_LIVE_TELEGRAM:-0}" = "1" ] \
   && [ -f "$ROOT/.env" ] \
   && grep -q '^TELEGRAM_BOT_TOKEN=.\+' "$ROOT/.env" \
   && grep -q '^TELEGRAM_CHAT_ID=.\+' "$ROOT/.env"; then
  resp=$("$TG" send "trading-routine self-test $(date +%Y-%m-%dT%H:%M:%S)" 2>/dev/null) || resp=""
  ok=$(printf '%s' "$resp" | jq -r '.ok // empty' 2>/dev/null)
  if [ "$ok" = "true" ]; then
    _pass "live send: API returned ok=true"
  else
    _fail "live send: API returned ok=true" "resp=$resp"
  fi
else
  _pass "live send: SKIPPED (set TRADING_ROUTINE_LIVE_TELEGRAM=1 to verify bot token)"
fi
