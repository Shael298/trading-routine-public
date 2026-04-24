#!/usr/bin/env bash
# Telegram notifier — the ONLY path for sending messages to the user.
#
# Usage:
#   telegram.sh send "message text"
#
# Behaviour:
#   * Loads .env from repo root unless TRADING_ROUTINE_SKIP_DOTENV=1.
#   * If TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are both set → POST to the
#     Telegram Bot API, print the JSON response, exit 0 on ok=true / exit 3
#     on network failure / exit 4 when the API returns ok=false.
#   * If either credential is missing → append a timestamped line to the
#     fallback log ($FALLBACK_LOG, else memory/notification_fallback.log) and
#     exit 0 silently. Cloud routines must NEVER block on missing Telegram.
#
# Design note: the silent-fallback-exit-0 rule is deliberate. A 21:05 routine
# firing that can't reach Telegram must still commit its memory updates and
# exit cleanly. The fallback log is read by the next routine and surfaced in
# the daily summary, so nothing is lost.

set -u

cmd="${1:-}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env unless caller opted out (tests do).
if [ "${TRADING_ROUTINE_SKIP_DOTENV:-0}" != "1" ] && [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

FALLBACK_LOG="${FALLBACK_LOG:-$REPO_ROOT/memory/notification_fallback.log}"

_fallback() {
  local reason="$1" msg="$2"
  mkdir -p "$(dirname "$FALLBACK_LOG")"
  printf '[%s] (%s) %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$msg" >> "$FALLBACK_LOG"
}

case "$cmd" in
  send)
    msg="${1:-}"
    if [ -z "$msg" ]; then
      echo "usage: telegram.sh send \"message\"" >&2
      exit 2
    fi

    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
      _fallback "missing-creds" "$msg"
      exit 0
    fi

    # Build JSON payload safely (jq handles escaping for us). First attempt
    # uses Markdown parse_mode for nicer formatting; if Telegram rejects the
    # payload on parse errors (unescaped _ * [ ` in routine messages), we
    # retry once as plain text so the message still lands.
    _send() {
      local mode_payload="$1"
      curl -sS --max-time 10 \
        -H 'Content-Type: application/json' \
        -d "$mode_payload" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" 2>/dev/null
    }

    payload_md=$(jq -n --arg cid "$TELEGRAM_CHAT_ID" --arg text "$msg" \
      '{chat_id: $cid, text: $text, parse_mode: "Markdown", disable_web_page_preview: true}')

    resp=$(_send "$payload_md") || {
      _fallback "network-fail" "$msg"
      printf '%s\n' '{"ok":false,"error":"network"}'
      exit 3
    }

    ok=$(printf '%s' "$resp" | jq -r '.ok // empty' 2>/dev/null)
    if [ "$ok" != "true" ]; then
      # Telegram returned ok=false. If the failure is a parse error, retry
      # once as plain text (no parse_mode) so the message still reaches the
      # user. Anything else (auth, rate-limit, chat not found) falls through.
      desc=$(printf '%s' "$resp" | jq -r '.description // empty' 2>/dev/null)
      case "$desc" in
        *"parse"*|*"Parse"*|*"entities"*)
          payload_plain=$(jq -n --arg cid "$TELEGRAM_CHAT_ID" --arg text "$msg" \
            '{chat_id: $cid, text: $text, disable_web_page_preview: true}')
          resp=$(_send "$payload_plain") || {
            _fallback "network-fail" "$msg"
            printf '%s\n' '{"ok":false,"error":"network"}'
            exit 3
          }
          ok=$(printf '%s' "$resp" | jq -r '.ok // empty' 2>/dev/null)
          ;;
      esac
    fi

    printf '%s\n' "$resp"
    if [ "$ok" = "true" ]; then
      exit 0
    else
      _fallback "api-not-ok" "$msg :: $resp"
      exit 4
    fi
    ;;
  ""|help|-h|--help)
    cat <<'EOF'
telegram.sh — Telegram notifier wrapper.

Subcommands:
  send "<message>"   Deliver a Markdown message. Silent fallback on missing creds.

Env:
  TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID   Bot credentials (from .env or injected).
  FALLBACK_LOG                           Override the fallback log path.
  TRADING_ROUTINE_SKIP_DOTENV=1          Skip .env loading (tests).
EOF
    exit 0
    ;;
  *)
    echo "telegram.sh: unknown subcommand '$cmd'" >&2
    exit 2
    ;;
esac
