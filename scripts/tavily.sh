#!/usr/bin/env bash
# Tavily research wrapper — the ONLY path for external research calls.
#
# Usage:
#   tavily.sh search [--max-results=N] [--depth=basic|advanced] "query string"
#
# Exit codes:
#   0   results returned (stdout = JSON body)
#   2   usage error
#   3   auth failure / missing key (caller should fall back to WebSearch)
#   4   API returned an error payload
#
# Design: Claude code routines call this wrapper. If exit != 0, the routine
# MUST fall back to Claude's built-in WebSearch tool so research is never
# blocked on a single-vendor outage. That fallback is implemented in the
# routine prompts, not here — this wrapper's only job is to be a thin,
# observable shell around the Tavily API.

set -u

cmd="${1:-}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "${TRADING_ROUTINE_SKIP_DOTENV:-0}" != "1" ] && [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

case "$cmd" in
  search)
    max_results=5
    depth="basic"
    query=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --max-results=*) max_results="${1#*=}" ;;
        --depth=*)       depth="${1#*=}" ;;
        --)              shift; query="$*"; break ;;
        -*)              echo "tavily.sh: unknown flag '$1'" >&2; exit 2 ;;
        *)               query="$1" ;;
      esac
      shift || true
    done

    if [ -z "$query" ]; then
      echo "usage: tavily.sh search [--max-results=N] [--depth=basic|advanced] \"query\"" >&2
      exit 2
    fi

    if [ -z "${TAVILY_API_KEY:-}" ]; then
      echo "tavily.sh: TAVILY_API_KEY missing — caller should fall back to WebSearch" >&2
      exit 3
    fi

    payload=$(jq -n \
      --arg q "$query" \
      --arg depth "$depth" \
      --argjson max "$max_results" \
      '{query:$q, search_depth:$depth, max_results:$max, include_answer:true}')

    resp=$(curl -sS --max-time 20 --ipv4 --retry 2 --retry-delay 1 \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer ${TAVILY_API_KEY}" \
      -d "$payload" \
      "https://api.tavily.com/search" 2>/dev/null) || {
        echo "tavily.sh: network failure contacting api.tavily.com" >&2
        exit 3
      }

    # Detect API-side error (auth, quota, malformed query).
    err=$(printf '%s' "$resp" | jq -r '.error // .detail // empty' 2>/dev/null)
    if [ -n "$err" ]; then
      echo "tavily.sh: API error: $err" >&2
      # Treat auth-shaped errors as exit 3 so the caller fallback triggers.
      case "$err" in
        *[Uu]nauthor*|*[Ff]orbidden*|*[Ii]nvalid*[Kk]ey*|*401*|*403*)
          exit 3 ;;
        *)
          exit 4 ;;
      esac
    fi

    printf '%s\n' "$resp"
    exit 0
    ;;
  ""|help|-h|--help)
    cat <<'EOF'
tavily.sh — Tavily research wrapper.

Subcommands:
  search [--max-results=N] [--depth=basic|advanced] "query"

Env:
  TAVILY_API_KEY              Free-tier key from https://app.tavily.com
  TRADING_ROUTINE_SKIP_DOTENV Skip .env loading (tests).
EOF
    exit 0
    ;;
  *)
    echo "tavily.sh: unknown subcommand '$cmd'" >&2
    exit 2
    ;;
esac
