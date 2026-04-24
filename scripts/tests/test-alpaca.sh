#!/usr/bin/env bash
# Alpaca wrapper — behavioural tests.
#
# Every subcommand is exercised; live API hits happen only when paper creds
# are present in .env. The full order round-trip (buy → stop → cancel → close)
# is opt-in via TRADING_ROUTINE_LIVE_ORDERS=1 because it places real paper
# orders and should run once per CI cycle, not on every `bash run-all.sh`.

AP="$ROOT/scripts/alpaca.sh"
assert_file_exists "$AP" "alpaca.sh exists"
[ -x "$AP" ] && _pass "alpaca.sh executable" || _fail "alpaca.sh executable" "chmod +x missing"

# -----  a) missing creds  -----
(
  unset ALPACA_API_KEY ALPACA_SECRET_KEY
  export TRADING_ROUTINE_SKIP_DOTENV=1
  out=$("$AP" account 2>&1) ; rc=$?
  if [ "$rc" -eq 2 ] || [ "$rc" -eq 3 ]; then
    _pass "missing creds → exit 2/3"
  else
    _fail "missing creds → exit 2/3" "rc=$rc out=$out"
  fi
  case "$out" in
    *ALPACA*|*"missing"*|*"API key"*) _pass "missing creds → stderr names the missing var" ;;
    *) _fail "missing creds → stderr names the missing var" "out=$out" ;;
  esac
  printf '%d %d\n' "$TESTS_PASSED" "$TESTS_FAILED" > "$RESULTS"
)
if [ -f "$RESULTS" ]; then
  read -r sp sf < "$RESULTS" || true
  TESTS_PASSED="$sp"
  TESTS_FAILED="$sf"
fi

# -----  b) usage / help  -----
help_out=$("$AP" help 2>&1) || true
assert_contains "$help_out" "account"      "help lists 'account' subcommand"
assert_contains "$help_out" "buy"          "help lists 'buy' subcommand"
assert_contains "$help_out" "trailing-stop" "help lists 'trailing-stop' subcommand"
assert_contains "$help_out" "close-all"    "help lists 'close-all' subcommand"

# -----  c) live read-only calls  -----
have_live=0
if [ -f "$ROOT/.env" ] \
   && grep -q '^ALPACA_API_KEY=.\+' "$ROOT/.env" \
   && grep -q '^ALPACA_SECRET_KEY=.\+' "$ROOT/.env"; then
  have_live=1
fi

if [ "$have_live" = "1" ]; then
  acct=$("$AP" account 2>/dev/null) || acct=""
  if [ -z "$acct" ]; then
    _fail "live: account returns JSON" "empty"
  else
    eq=$(printf '%s' "$acct" | jq -r '.equity // empty' 2>/dev/null)
    if [ -n "$eq" ]; then
      _pass "live: account.equity present (=$eq)"
    else
      _fail "live: account.equity present" "resp=${acct:0:200}"
    fi
  fi

  pos=$("$AP" positions 2>/dev/null) || pos=""
  if printf '%s' "$pos" | jq -e 'type == "array"' >/dev/null 2>&1; then
    _pass "live: positions returns array"
  else
    _fail "live: positions returns array" "resp=${pos:0:200}"
  fi

  q=$("$AP" quote SPY 2>/dev/null) || q=""
  if printf '%s' "$q" | jq -e '(.latestTrade // .latestQuote // .quote // .trade) != null' >/dev/null 2>&1; then
    _pass "live: quote SPY has trade/quote data"
  else
    _fail "live: quote SPY has trade/quote data" "resp=${q:0:200}"
  fi

  ord=$("$AP" orders 2>/dev/null) || ord=""
  if printf '%s' "$ord" | jq -e 'type == "array"' >/dev/null 2>&1; then
    _pass "live: orders returns array"
  else
    _fail "live: orders returns array" "resp=${ord:0:200}"
  fi
else
  _pass "live alpaca read-only: SKIPPED (no creds)"
fi

# -----  d) round-trip order test (opt-in)  -----
if [ "$have_live" = "1" ] && [ "${TRADING_ROUTINE_LIVE_ORDERS:-0}" = "1" ]; then
  # Close anything left over from a previous run, ignoring failures.
  "$AP" cancel-all >/dev/null 2>&1 || true
  "$AP" close-all  >/dev/null 2>&1 || true
  sleep 2

  SYM="F"
  QTY=1

  buy_resp=$("$AP" buy "$SYM" "$QTY" 2>/dev/null) || buy_resp=""
  order_id=$(printf '%s' "$buy_resp" | jq -r '.id // empty')
  if [ -n "$order_id" ]; then
    _pass "round-trip: buy submitted (id=${order_id:0:8})"
  else
    _fail "round-trip: buy submitted" "resp=${buy_resp:0:300}"
  fi

  # Wait for fill.
  filled=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 2
    status=$("$AP" position "$SYM" 2>/dev/null | jq -r '.qty // empty')
    if [ -n "$status" ] && [ "$status" != "null" ]; then
      filled=1
      break
    fi
  done
  if [ "$filled" = "1" ]; then
    _pass "round-trip: position opened"
  else
    _fail "round-trip: position opened" "never reported qty"
  fi

  stop_resp=$("$AP" trailing-stop "$SYM" "$QTY" --percent=10 2>/dev/null) || stop_resp=""
  stop_id=$(printf '%s' "$stop_resp" | jq -r '.id // empty')
  if [ -n "$stop_id" ]; then
    _pass "round-trip: trailing stop placed (id=${stop_id:0:8})"
  else
    _fail "round-trip: trailing stop placed" "resp=${stop_resp:0:300}"
  fi

  "$AP" cancel "$stop_id" >/dev/null 2>&1 && _pass "round-trip: stop cancelled" || _fail "round-trip: stop cancelled" "cancel failed"

  "$AP" close "$SYM" >/dev/null 2>&1
  sleep 3
  remaining=$("$AP" position "$SYM" 2>/dev/null | jq -r '.qty // empty')
  if [ -z "$remaining" ] || [ "$remaining" = "null" ] || [ "$remaining" = "0" ]; then
    _pass "round-trip: position closed"
  else
    _fail "round-trip: position closed" "qty still=$remaining"
  fi
else
  _pass "round-trip order test: SKIPPED (set TRADING_ROUTINE_LIVE_ORDERS=1 to run)"
fi
