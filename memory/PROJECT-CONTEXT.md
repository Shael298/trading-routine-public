# Project Context

Static mission and platform background. Read by every routine as part of its
memory block. Updated rarely — only when a platform assumption or mission goal
genuinely changes.

---

## Mission

Build and operate a fully autonomous swing-trading agent that runs on a schedule,
obeys `TRADING-STRATEGY.md`, commits every action to git, and notifies the user on
Telegram. Paper first. Live once validated.

The user's capital plan: ~$1,000 paper → mirror with ~£1,000 live once the paper
account clears the go-live bar (see `TRADING-STRATEGY.md` → "Criteria for
moving from paper → live").

---

## Platform

- **Broker**: Alpaca — paper account at `https://paper-api.alpaca.markets`, market data at `https://data.alpaca.markets`. All trading I/O goes through `scripts/alpaca.sh`.
- **Research**: Tavily free tier. Falls back to Claude's built-in WebSearch if key missing or quota exhausted. All research I/O goes through `scripts/tavily.sh`.
- **Notifications**: Telegram bot → the user's personal chat. All user-facing messages go through `scripts/telegram.sh`. Fallback: `memory/notification_fallback.log`.
- **Runtime**: Claude Code cloud routines (cron-triggered ephemeral containers). Six weekday firings: pre-market (12:00), market-open (14:45), midday (18:00), earnings-risk-check (19:30), daily-summary (21:05), Friday weekly-review (21:10). All times **Europe/London**.
- **Persistence**: Git — this repo on GitHub (private). Memory files in `main` are the single source of truth.

---

## Invariants

1. If it isn't pushed to `main`, it didn't happen.
2. Cloud routines **never create `.env`**. Credentials are injected as env vars by the routine runtime.
3. All external I/O goes through `scripts/*.sh`. Claude never `curl`s a third-party API directly.
4. Every buy that fills gets a real GTC trailing stop on Alpaca within the same routine firing.
5. The user can kill the entire bot by revoking the Claude GitHub App on the repo.

---

## Out of scope (for now)

- Options, futures, FX, crypto.
- Fractional shares (can't carry GTC stops on Alpaca).
- Market-making / high-frequency / intraday scalping.
- Any strategy that requires a data feed beyond Alpaca + Tavily.
