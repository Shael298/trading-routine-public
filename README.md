# Trading Routine

An autonomous swing-trading agent that runs on a schedule, obeys a committed
rulebook, and keeps the operator in the loop over Telegram. Paper first. Live
once the paper account clears the go-live bar.

**Status:** paper, Tier 1 (~$1,000 equity). Every action is committed to
`main` — if a routine didn't push, it didn't happen.

---

## What's in here

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Master rulebook loaded by every Claude Code session. |
| `memory/` | All state: strategy, trade log, research log, weekly review, project context. |
| `scripts/` | Thin wrappers for Alpaca, Tavily, Telegram, and the buy-side gate. |
| `scripts/tests/` | bash + jq test harness (`run-all.sh` is the only entry point). |
| `.claude/commands/` | Local slash commands (`/status`, `/idea`, `/buy`, …) for manual operation. |
| `cloud-routines/` | Five scheduled routine prompts (pre-market, market-open, midday, daily-summary, weekly-review). |
| `docs/` | Setup instructions, runbook, deployment notes. |
| `env.template` | Schema of the local `.env`. The real `.env` is gitignored. |

---

## The five-beat loop

Every routine (local or cloud) executes the same sequence:

1. **read memory** → `PROJECT-CONTEXT.md`, `TRADING-STRATEGY.md`, and the logs.
2. **gather data** → `scripts/alpaca.sh account|quote`, `scripts/tavily.sh search`.
3. **act** → `scripts/gate.sh` (for buys) + `scripts/alpaca.sh buy|trailing-stop|close`.
4. **commit** → `git add -A && git commit -m "..." && git push origin main`.
5. **notify** → `scripts/telegram.sh send "..."` (silent fallback if creds missing).

The discipline is codified in `CLAUDE.md`. The strategy (tier caps, hard rules,
sell-side logic) lives in `memory/TRADING-STRATEGY.md`.

---

## Platform

- **Broker:** Alpaca — paper account at `https://paper-api.alpaca.markets`.
- **Research:** Tavily (free tier, 1k/mo). Falls back to Claude's `WebSearch` on exit 3.
- **Notifications:** Telegram bot. Fallback log at `memory/notification_fallback.log` is drained by the daily-summary routine.
- **Runtime:** Claude Code cloud routines (cron-triggered ephemeral containers), all times Europe/London.
- **Persistence:** This git repo. Every routine commits.

### Schedule

| Routine | Time (UK) | What it does |
|---|---|---|
| pre-market    | 12:00      | Research log · 0–3 ideas · no orders. |
| market-open   | 14:45      | Execute approved ideas · first entries get 10% trailing stop, pyramid adds get fixed wavg break-even stop. |
| midday        | 18:00      | Sell-side logic in order (-7% cut, thesis-broken, +15/+20 tightens). |
| daily-summary | 21:05      | EOD snapshot · drain fallback log · Telegram. |
| weekly-review | Fri 21:10  | Grade A–F · propose strategy amendments if 2 weeks ≤ C. |

---

## Local setup

```bash
# 1. Clone
git clone git@github.com:YOUR_USERNAME/trading-routine.git
cd trading-routine

# 2. Create .env (never committed)
cp env.template .env
# Fill in ALPACA_API_KEY, ALPACA_SECRET_KEY, TAVILY_API_KEY,
# TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

# 3. Install prerequisites (macOS / Linux / Git Bash on Windows)
#    bash ≥4, jq, curl — already present on most systems.

# 4. Run the test suite (must be 100% green before any commit)
bash scripts/tests/run-all.sh
```

### Full local verification (opt-in live order round-trip)

```bash
TRADING_ROUTINE_LIVE_ORDERS=1 bash scripts/tests/run-all.sh
```

This places a 1-share buy + trailing stop + cancel + close cycle on the paper
account to validate the write path end-to-end. Only run when US market is open.

---

## Operating locally

Slash commands in Claude Code (CLI or IDE):

| Command | What it does |
|---|---|
| `/status` | Account snapshot — equity, positions, open stops, deployment %. |
| `/idea <SYM>` | Pull a quote, fetch the catalyst, dry-run the buy-side gate. |
| `/gate` | Pipe a JSON payload through `scripts/gate.sh`. |
| `/buy <SYM> <QTY>` | Disciplined manual buy (gate → buy → trailing stop → log → notify). |
| `/buy <SYM> --pyramid` | Add to an existing proven winner (≥ +15%). Cancels the old stop, buys ½-starter add, places fixed break-even stop at weighted-average cost. |
| `/close <SYM>` | Cancel stop → market close → log → notify. |
| `/research <query>` | Tavily search with `WebSearch` fallback on exit 3. |
| `/review` | Manual weekly-review preview (read-only; does not commit). |

---

## Deploying the cloud routines

See `docs/SETUP.md` for the full walkthrough. Summary:

1. In Claude Code cloud, create five routines matching `cloud-routines/*.md`.
2. Inject `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, `TAVILY_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` as routine env vars. **Never** allow a routine to create `.env`.
3. Set the schedule per the table above (Europe/London).
4. Grant the Claude GitHub App write access so routines can push to `main`.

---

## Going from paper to live

The go-live bar is pinned in `memory/TRADING-STRATEGY.md`. In short: ≥ 4
consecutive grade-B-or-better weeks on paper, zero material rule violations,
profit factor ≥ 1.5 over the same window. Flip `ALPACA_ENDPOINT` to
`https://api.alpaca.markets` after copying the paper `.env` keys across to
live Alpaca credentials. Everything else stays the same.

---

## Kill-switch

To stop every future routine in one click: **revoke the Claude GitHub App on
this repo** in GitHub Settings → Applications. The cron fires become no-ops
because the routines can no longer clone or push. Open positions and their
GTC stops remain active on Alpaca and must be managed manually.

---

## Project memory

`memory/` is the source of truth. It's split by role:

- `PROJECT-CONTEXT.md` — mission & platform invariants (edit rarely).
- `TRADING-STRATEGY.md` — the rulebook (weekly-review edits only).
- `TRADE-LOG.md` — every trade + EOD snapshots (append-only, newest first).
- `RESEARCH-LOG.md` — daily research (append-only, newest first).
- `WEEKLY-REVIEW.md` — weekly grade A–F + lessons (append-only).

Append-only means: add a new dated section at the top, never edit historical
entries. Corrections are new entries.
