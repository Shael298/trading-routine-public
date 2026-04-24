#!/usr/bin/env bash
# Tavily wrapper — behavioural tests:
#   (a) missing key → exit 3, stderr explains, no crash
#   (b) live key → JSON with .results array (length ≥ 1 on a common query)
#
# The live test is skipped when TAVILY_API_KEY is blank so CI without secrets
# still passes.

TV="$ROOT/scripts/tavily.sh"
assert_file_exists "$TV" "tavily.sh exists"
[ -x "$TV" ] && _pass "tavily.sh executable" || _fail "tavily.sh executable" "chmod +x missing"

# -----  a) missing key  -----
(
  unset TAVILY_API_KEY
  export TRADING_ROUTINE_SKIP_DOTENV=1
  out=$("$TV" search "anything" 2>&1) ; rc=$?
  if [ "$rc" -eq 3 ]; then
    _pass "missing key → exit 3"
  else
    _fail "missing key → exit 3" "rc=$rc out=$out"
  fi
  case "$out" in
    *TAVILY*|*"API key"*|*"missing"*) _pass "missing key → stderr names the missing var" ;;
    *) _fail "missing key → stderr names the missing var" "out=$out" ;;
  esac
  printf '%d %d\n' "$TESTS_PASSED" "$TESTS_FAILED" > "$RESULTS"
)
if [ -f "$RESULTS" ]; then
  read -r sp sf < "$RESULTS" || true
  TESTS_PASSED="$sp"
  TESTS_FAILED="$sf"
fi

# -----  b) live key  -----
if [ -f "$ROOT/.env" ] && grep -q '^TAVILY_API_KEY=.\+' "$ROOT/.env"; then
  resp=$("$TV" search --max-results=3 "S&P 500 today" 2>/dev/null) || resp=""
  if [ -z "$resp" ]; then
    _fail "live tavily: returns JSON body" "empty response"
  else
    count=$(printf '%s' "$resp" | jq -r '.results | length' 2>/dev/null)
    if [ -n "$count" ] && [ "$count" -ge 1 ] 2>/dev/null; then
      _pass "live tavily: results array non-empty (count=$count)"
    else
      _fail "live tavily: results array non-empty" "resp=${resp:0:200}"
    fi
  fi
else
  _pass "live tavily: SKIPPED (no TAVILY_API_KEY in .env)"
fi
