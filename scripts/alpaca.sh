#!/usr/bin/env bash
# Alpaca trading wrapper — the ONLY path for broker I/O in this repo.
#
# Subcommands:
#   account                                  Account snapshot (JSON).
#   positions                                All open positions (JSON array).
#   position <SYM>                           One position by symbol.
#   quote <SYM>                              Market snapshot (data endpoint).
#   orders [--status=open|closed|all]        List orders.
#   buy <SYM> <QTY> [--limit=PRICE] [--tif=day|gtc]
#                                            Submit market/limit buy.
#   trailing-stop <SYM> <QTY> --percent=N [--tif=gtc]
#                                            Place GTC trailing stop sell.
#   stop <SYM> <QTY> --price=P [--tif=gtc]   Place fixed stop sell.
#   cancel <ORDER_ID>                        Cancel one open order.
#   cancel-all                               Cancel every open order.
#   close <SYM>                              Market-close a symbol position.
#   close-all                                Market-close every position.
#
# Exit codes:
#   0 success · 2 usage · 3 auth/network · 4 API rejected (422/etc.)
#
# Design: thin wrapper. Every request is one curl. The routine prompts compose
# higher-level workflows (buy-then-stop-in-same-firing, PDT guard, sizing)
# because those are policy, not plumbing.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "${TRADING_ROUTINE_SKIP_DOTENV:-0}" != "1" ] && [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

: "${ALPACA_ENDPOINT:=https://paper-api.alpaca.markets}"
: "${ALPACA_DATA_ENDPOINT:=https://data.alpaca.markets}"

_require_creds() {
  if [ -z "${ALPACA_API_KEY:-}" ] || [ -z "${ALPACA_SECRET_KEY:-}" ]; then
    echo "alpaca.sh: ALPACA_API_KEY / ALPACA_SECRET_KEY missing" >&2
    exit 3
  fi
}

_curl() {
  # $1=METHOD $2=BASE $3=PATH (4+=curl opts, e.g. -d BODY).
  # Response body goes to stdout, non-2xx status → stderr + exit 3/4.
  local method="$1" base="$2" path="$3"
  shift 3
  local url="$base$path"
  local body_file status
  body_file=$(mktemp)
  status=$(curl -sS --max-time 20 \
    -X "$method" \
    -H "APCA-API-KEY-ID: ${ALPACA_API_KEY}" \
    -H "APCA-API-SECRET-KEY: ${ALPACA_SECRET_KEY}" \
    -H "Content-Type: application/json" \
    -o "$body_file" \
    -w '%{http_code}' \
    "$@" \
    "$url" 2>/dev/null)
  local rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$status" ]; then
    rm -f "$body_file"
    echo "alpaca.sh: network failure on $method $path (curl rc=$rc)" >&2
    exit 3
  fi
  local json
  json=$(cat "$body_file")
  rm -f "$body_file"
  if [ "${status:0:1}" = "2" ]; then
    printf '%s' "$json"
    return 0
  fi
  echo "alpaca.sh: HTTP $status on $method $path — $json" >&2
  if [ "$status" = "401" ] || [ "$status" = "403" ]; then exit 3; fi
  exit 4
}

_get()    { _curl GET    "$ALPACA_ENDPOINT"      "$1"; }
_post()   { _curl POST   "$ALPACA_ENDPOINT"      "$1" -d "$2"; }
_delete() { _curl DELETE "$ALPACA_ENDPOINT"      "$1"; }
_data()   { _curl GET    "$ALPACA_DATA_ENDPOINT" "$1"; }

cmd="${1:-}"
shift || true

case "$cmd" in
  account)
    _require_creds
    _get "/v2/account"
    echo
    ;;

  positions)
    _require_creds
    _get "/v2/positions"
    echo
    ;;

  position)
    _require_creds
    sym="${1:?usage: alpaca.sh position <SYM>}"
    _get "/v2/positions/$sym"
    echo
    ;;

  quote)
    _require_creds
    sym="${1:?usage: alpaca.sh quote <SYM>}"
    _data "/v2/stocks/$sym/snapshot"
    echo
    ;;

  orders)
    _require_creds
    status="open"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --status=*) status="${1#*=}" ;;
        *) echo "orders: unknown flag '$1'" >&2; exit 2 ;;
      esac
      shift
    done
    _get "/v2/orders?status=$status&limit=100&direction=desc"
    echo
    ;;

  buy)
    _require_creds
    sym="${1:?usage: alpaca.sh buy <SYM> <QTY> [--limit=PRICE] [--tif=day|gtc]}"
    qty="${2:?usage: alpaca.sh buy <SYM> <QTY> [--limit=PRICE] [--tif=day|gtc]}"
    shift 2 || true
    order_type="market"
    limit_price=""
    tif="day"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --limit=*)  order_type="limit"; limit_price="${1#*=}" ;;
        --tif=*)    tif="${1#*=}" ;;
        *) echo "buy: unknown flag '$1'" >&2; exit 2 ;;
      esac
      shift
    done
    if [ "$order_type" = "market" ]; then
      body=$(jq -n --arg s "$sym" --arg q "$qty" --arg tif "$tif" \
        '{symbol:$s, qty:$q, side:"buy", type:"market", time_in_force:$tif}')
    else
      body=$(jq -n --arg s "$sym" --arg q "$qty" --arg tif "$tif" --arg lp "$limit_price" \
        '{symbol:$s, qty:$q, side:"buy", type:"limit", limit_price:$lp, time_in_force:$tif}')
    fi
    _post "/v2/orders" "$body"
    echo
    ;;

  trailing-stop)
    _require_creds
    sym="${1:?usage: alpaca.sh trailing-stop <SYM> <QTY> --percent=N}"
    qty="${2:?usage: alpaca.sh trailing-stop <SYM> <QTY> --percent=N}"
    shift 2 || true
    percent=""
    tif="gtc"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --percent=*) percent="${1#*=}" ;;
        --tif=*)     tif="${1#*=}" ;;
        *) echo "trailing-stop: unknown flag '$1'" >&2; exit 2 ;;
      esac
      shift
    done
    if [ -z "$percent" ]; then
      echo "trailing-stop: --percent=N is required" >&2; exit 2
    fi
    body=$(jq -n --arg s "$sym" --arg q "$qty" --arg tif "$tif" --arg p "$percent" \
      '{symbol:$s, qty:$q, side:"sell", type:"trailing_stop", trail_percent:$p, time_in_force:$tif}')
    _post "/v2/orders" "$body"
    echo
    ;;

  stop)
    _require_creds
    sym="${1:?usage: alpaca.sh stop <SYM> <QTY> --price=P}"
    qty="${2:?usage: alpaca.sh stop <SYM> <QTY> --price=P}"
    shift 2 || true
    price=""
    tif="gtc"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --price=*) price="${1#*=}" ;;
        --tif=*)   tif="${1#*=}" ;;
        *) echo "stop: unknown flag '$1'" >&2; exit 2 ;;
      esac
      shift
    done
    if [ -z "$price" ]; then
      echo "stop: --price=P is required" >&2; exit 2
    fi
    body=$(jq -n --arg s "$sym" --arg q "$qty" --arg tif "$tif" --arg p "$price" \
      '{symbol:$s, qty:$q, side:"sell", type:"stop", stop_price:$p, time_in_force:$tif}')
    _post "/v2/orders" "$body"
    echo
    ;;

  cancel)
    _require_creds
    oid="${1:?usage: alpaca.sh cancel <ORDER_ID>}"
    _delete "/v2/orders/$oid"
    echo
    ;;

  cancel-all)
    _require_creds
    _delete "/v2/orders"
    echo
    ;;

  close)
    _require_creds
    sym="${1:?usage: alpaca.sh close <SYM>}"
    _delete "/v2/positions/$sym"
    echo
    ;;

  close-all)
    _require_creds
    _delete "/v2/positions"
    echo
    ;;

  ""|help|-h|--help)
    cat <<'EOF'
alpaca.sh — Alpaca trading wrapper.

Read:
  account
  positions
  position <SYM>
  quote <SYM>
  orders [--status=open|closed|all]

Write:
  buy <SYM> <QTY> [--limit=PRICE] [--tif=day|gtc]
  trailing-stop <SYM> <QTY> --percent=N [--tif=gtc]
  stop <SYM> <QTY> --price=P [--tif=gtc]
  cancel <ORDER_ID>
  cancel-all
  close <SYM>
  close-all

Env:
  ALPACA_API_KEY ALPACA_SECRET_KEY ALPACA_ENDPOINT ALPACA_DATA_ENDPOINT
EOF
    exit 0
    ;;

  *)
    echo "alpaca.sh: unknown subcommand '$cmd'" >&2
    exit 2
    ;;
esac
