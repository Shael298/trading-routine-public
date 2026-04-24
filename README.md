# Trading Routine

This is an autonomous swing-trading agent I built that runs on a schedule, follows a committed rulebook, and keeps me updated over Telegram. It is currently running on a paper Alpaca account while I build up a track record before going live.

Every single decision the agent makes gets committed to the private clone of this repo. If a routine did not push to `main`, it did not happen.

---

## What is in here

| Path | What it is |
|---|---|
| `CLAUDE.md` | The master rulebook that every Claude Code session reads on startup. |
| `memory/` | All the state: strategy, trade log, research log, weekly review, project context. |
| `scripts/` | Thin shell wrappers for Alpaca, Tavily, Telegram, and the buy-side gate. |
| `scripts/tests/` | A bash and jq test harness. `run-all.sh` is the only entry point. |
| `.claude/commands/` | Local slash commands for manual operation (`/status`, `/idea`, `/buy` and so on). |
| `cloud-routines/` | The six scheduled routine prompts that run on Claude Code cloud. |
| `docs/` | Setup instructions and deployment notes. |
| `env.template` | The schema for the local `.env` file. The real one is gitignored and never committed. |

---

## How each routine works

Every routine, whether local or cloud, runs the same five steps in order:

1. **Read memory** - loads `PROJECT-CONTEXT.md`, `TRADING-STRATEGY.md`, and the logs to understand what is open and what was decided yesterday.
2. **Gather data** - calls `scripts/alpaca.sh` for broker state and `scripts/tavily.sh` for research, with a `WebSearch` fallback if Tavily is down.
3. **Act** - for buys, pipes the idea through `scripts/gate.sh` first. Only proceeds if `approved: true` comes back. Every buy immediately gets a trailing stop placed in the same firing.
4. **Commit** - appends to the logs, then `git add -A && git commit && git push origin main`.
5. **Notify** - sends a Telegram message summarising what happened. If Telegram fails it writes to a fallback log and the next routine picks it up.

The discipline rules live in `CLAUDE.md`. The strategy (position sizing, hard rules, sell-side logic) lives in `memory/TRADING-STRATEGY.md`.

---

## Platform

- **Broker:** Alpaca paper account at `https://paper-api.alpaca.markets`.
- **Research:** Tavily (free tier). Falls back to Claude's `WebSearch` on exit code 3.
- **Notifications:** Telegram bot. The fallback log at `memory/notification_fallback.log` gets drained by the daily-summary routine.
- **Runtime:** Claude Code cloud routines (cron-triggered containers). All times are Europe/London.
- **Persistence:** This git repo. Every routine commits before it exits.

### Claude Code Routines

| Routine | Time (UK) | What it does |
|---|---|---|
| pre-market | 12:00 | Writes the research log entry: account snapshot, market context, 0 to 3 trade ideas. No orders placed. |
| market-open | 14:45 | Executes approved ideas. First entries get a 10% trailing stop. Pyramid adds get a fixed break-even stop at the weighted-average cost basis. |
| midday | 18:00 | Runs sell-side logic: cuts losses at -7%, tightens trails on winners at +15% and +20%, and checks if the thesis still holds. |
| earnings-risk-check | 19:30 | Scans every open position for earnings or other binary events within 5 trading days and flags them in the research log. No orders placed. |
| daily-summary | 21:05 | Takes an end-of-day snapshot, drains the Telegram fallback log, and sends a daily summary. |
| weekly-review | Fri 21:10 | Grades the week A to F and proposes strategy changes if two consecutive weeks score C or below. |

---

## Local setup

```bash
# 1. Clone
git clone https://github.com/Shael298/trading-routine-public.git
cd trading-routine-public

# 2. Create .env (never committed)
cp env.template .env
# Fill in ALPACA_API_KEY, ALPACA_SECRET_KEY, TAVILY_API_KEY,
# TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

# 3. Prerequisites: bash 4+, jq, curl (already present on most systems)

# 4. Run the test suite
bash scripts/tests/run-all.sh
```

### Full local verification (places a real paper order)

```bash
TRADING_ROUTINE_LIVE_ORDERS=1 bash scripts/tests/run-all.sh
```

This places a 1-share buy, a trailing stop, cancels it, and closes the position on the paper account to validate the full write path. Only run when the US market is open.

---

## Slash commands

These work inside Claude Code (CLI or IDE):

| Command | What it does |
|---|---|
| `/status` | Account snapshot: equity, positions, open stops, deployment %. |
| `/idea <SYM>` | Pulls a quote, fetches the catalyst, and dry-runs the buy-side gate. |
| `/gate` | Pipes a JSON payload through `scripts/gate.sh` directly. |
| `/buy <SYM> <QTY>` | Manual buy: gate check, buy, trailing stop, log entry, Telegram notify. |
| `/buy <SYM> --pyramid` | Pyramid add into an existing winner (requires +15% or more). Cancels the old stop, buys a half-size add, and places a fixed break-even stop. |
| `/close <SYM>` | Cancels the stop, market-closes the position, logs it, and notifies. |
| `/research <query>` | Tavily search with `WebSearch` fallback. |
| `/review` | Manual weekly-review preview. Read-only, does not commit. |

---

## Deploying the cloud routines

See `docs/SETUP.md` for the full walkthrough. The short version:

1. In Claude Code cloud, create six routines using the prompts in `cloud-routines/`.
2. Inject `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, `TAVILY_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, and `GITHUB_TOKEN` as environment variables on each routine. Never let a routine create a `.env` file.
3. Set the schedule per the table above (Europe/London timezone).
4. Grant the Claude GitHub App write access so routines can push to `main`.

---

## Going live

The go-live bar is defined in `memory/TRADING-STRATEGY.md`. In short: four or more consecutive grade-B weeks on paper, zero material rule violations, and a profit factor of 1.5 or better over that window. When that is met, flip `ALPACA_ENDPOINT` to `https://api.alpaca.markets` and swap in live Alpaca credentials. Everything else stays the same.

---

## Kill switch

To stop every future routine in one click, revoke the Claude GitHub App on this repo in GitHub Settings under Applications. The routines can no longer clone or push, so they become no-ops. Any open positions and their GTC stops stay active on Alpaca and need to be managed manually.

---

## Memory files

`memory/` is the single source of truth. Split by role:

- `PROJECT-CONTEXT.md` - mission and platform invariants. Rarely changes.
- `TRADING-STRATEGY.md` - the rulebook. Only the weekly-review routine can edit this.
- `TRADE-LOG.md` - every trade and end-of-day snapshot. Append-only, newest first.
- `RESEARCH-LOG.md` - daily research entries. Append-only, newest first.
- `WEEKLY-REVIEW.md` - weekly grade and lessons. Append-only, newest first.

Append-only means a new dated section gets added at the top every time. Historical entries are never edited. If something needs correcting, a new entry says so.
