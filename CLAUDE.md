# CLAUDE.md — Trading Routine Master Rulebook

Every Claude Code routine that fires on this repo reads this file at session
start. It is the single source of operating discipline. The strategy lives in
`memory/TRADING-STRATEGY.md`; this file governs **how** that strategy is
executed and logged.

---

## What this project is

**Trading Routine** is a fully autonomous swing-trading agent that runs as five
weekday cron-triggered cloud routines (Europe/London timezone), trades a paper
Alpaca account, and commits every decision to git. Paper first. Live once the
paper account passes the go-live bar defined in `TRADING-STRATEGY.md`.

The human operator is Shael (`<your-email@example.com>`). The agent is you.

---

## Non-negotiable invariants

1. **If it isn't pushed to `main`, it didn't happen.** A routine that doesn't
   commit+push its memory updates has effectively never run — the next routine
   will see stale state. Always push to `main`:
   ```bash
   git fetch origin main && git checkout main && git pull --rebase origin main
   git add -A && git commit -m "..." || true
   git push origin main
   ```
   before exiting, even on partial work.
2. **Cloud routines never create .env.** Credentials are injected as env vars
   by the cloud runtime. If `.env` is missing, read from the environment. Never
   write `.env` from a routine.
3. **All external I/O goes through `scripts/*.sh`.** Never `curl` Alpaca,
   Tavily, Telegram, or any other third party directly. If a wrapper doesn't
   expose what you need, add a subcommand to the wrapper, add a test, commit —
   then use it.
4. **Every filled buy gets a real GTC trailing stop on Alpaca in the same
   routine firing.** No mental stops. No synthetic stops. If the stop-placement
   call fails, immediately market-sell the position and notify; never leave an
   unguarded long.
5. **The kill-switch is to revoke the Claude GitHub App on this repo.** The
   operator can stop every future routine in one click. If you're ever in doubt
   about whether a destructive action is authorised, do nothing and notify.

---

## Workflow every routine follows

Every routine — pre-market, market-open, midday, daily-summary, weekly-review —
executes the same five-beat loop:

1. **read memory.** Load `PROJECT-CONTEXT.md`, `TRADING-STRATEGY.md`, and the
   three logs. Know what's in the account, what trades are open, and what the
   last routine said.
2. **Gather data.** Use `scripts/alpaca.sh account|positions|quote` for broker
   state and `scripts/tavily.sh search` (with WebSearch fallback on exit 3) for
   research. Never hit APIs directly.
3. **Act.** Run the routine-specific work (see `cloud-routines/*.md`). For any
   buy, pipe the idea through `scripts/gate.sh` and only proceed on
   `approved:true`. Every buy-fill immediately gets a trailing stop.
4. **Commit.** Append to the logs, update snapshots, `git add -A`, commit with
   a descriptive message, and `git push origin main`. No silent file edits.
5. **Notify.** Call `scripts/telegram.sh send` with a concise message describing
   what was done and, crucially, any exceptions (stops hit, trades rejected,
   thesis invalidated). Telegram failure is silent — the fallback log catches
   it and the next routine will surface it.

---

## Wrappers (the only I/O boundary)

| Wrapper | Purpose | Exit semantics |
|---|---|---|
| `scripts/alpaca.sh` | Broker I/O (account, quote, buy, stop, cancel, close). | **Fail-closed.** Non-zero ⇒ do not proceed with the trade; notify. |
| `scripts/gate.sh` | Pure-function buy-side decision. | **Fail-closed.** Reject unless `approved:true`. |
| `scripts/tavily.sh` | Research search. | Exit 3 ⇒ fall back to Claude's `WebSearch` tool. Other non-zero ⇒ log and continue without that query. |
| `scripts/telegram.sh` | User notification. | **Fail-open.** Always exits 0. On missing creds or network error it writes to `memory/notification_fallback.log` so nothing is lost. |

**Rule:** never `curl` a third-party API directly from a routine. If
functionality is missing, extend the wrapper + its test + commit, then use it.

---

## Memory files

All memory lives in `memory/` and is read on every routine boot.

| File | Role | Write discipline |
|---|---|---|
| `PROJECT-CONTEXT.md` | Mission, platform, invariants. Rarely changes. | **read-only** to routines. Edit only when platform assumptions genuinely change. |
| `TRADING-STRATEGY.md` | Rulebook — tier table, hard rules, buy-side gate, sell-side logic. | **read-only** to every routine except the Friday **weekly-review** routine, which may edit it only when a rule has proven itself 2+ consecutive weeks or failed badly (record the amendment in the same commit). |
| `TRADE-LOG.md` | Every trade + every EOD snapshot. | **append-only**, newest at top. Never delete or amend past entries. |
| `RESEARCH-LOG.md` | Daily research — account snapshot, market context, trade ideas. | **append-only**, newest at top. |
| `WEEKLY-REVIEW.md` | Weekly A–F grade + lessons. | **append-only**, newest at top. Written only by the weekly-review routine. |

Append-only means: add a new dated section at the top, never edit historical
entries. If a fact needs correcting, write a new entry saying so — the ledger
is the audit trail.

---

## Routine topology

Six weekday firings (all times **Europe/London**):

| Routine | Time | Purpose |
|---|---|---|
| **pre-market**          | 12:00      | Research log: account snapshot, market context, 0–5 candidate ideas. No orders. |
| **market-open**         | 14:45      | Execute approved ideas via `gate.sh` + `alpaca.sh buy` + mandatory trailing stop. Close sell-side hits. |
| **midday**              | 18:00      | Check open positions against sell-side logic (cut/tighten/thesis). Place any required stop-tighten orders. |
| **earnings-risk-check** | 19:30      | Flag any open position with earnings/binary event within 2 trading days. No orders — flags only. |
| **daily-summary**       | 21:05      | EOD snapshot into `TRADE-LOG.md`, Telegram summary. Clean up any dangling orders. |
| **weekly-review**       | Fri 21:10  | Grade the week (A–F), write `WEEKLY-REVIEW.md` entry, propose strategy amendments if 2 weeks ≤ C. |

Each routine's full prompt lives in `cloud-routines/<name>.md`. That file is
copy-pasted into the Claude Code cloud routine config.

---

## Fail-open vs fail-closed

- **Broker, gate, strategy decisions → fail-closed.** If Alpaca is unreachable
  or `gate.sh` returns `approved:false`, the routine must not trade. It logs
  the reason, commits, notifies, and exits cleanly. Silence on a broken
  broker is the only acceptable answer.
- **Notifications → fail-open.** Telegram failures never block a routine.
  `telegram.sh` exits 0 and writes to `memory/notification_fallback.log`. The
  next routine surfaces the backlog.
- **Research → degrade gracefully.** `tavily.sh` exit 3 ⇒ fall back to
  `WebSearch`. Other failures ⇒ log in research log, continue without the
  missing data.

---

## Money-move checklist (every buy)

Before you submit a buy order, you have proven to yourself that:

- [ ] A fresh `scripts/alpaca.sh account` pull was taken this firing.
- [ ] `scripts/gate.sh` was called with today's idea payload and returned
      `approved:true`.
- [ ] The idea's catalyst is documented in today's `RESEARCH-LOG.md` entry.
- [ ] You have a stop price / trail % in hand before placing the buy.
- [ ] **First-entries only:** the constructive-pullback preference is
      satisfied (5–15% off 20-day high AND above 50-day MA) OR an explicit
      catalyst-strong override is noted in the research log.
- [ ] **Pyramid adds only:** you have verified the live position exists,
      is up ≥ 15%, has never been pyramided before, the add qty ≤ ½ starter,
      and the existing trailing stop has been cancelled before the add order.

After the buy fills:

- [ ] **First-entry:** `scripts/alpaca.sh trailing-stop SYM QTY --percent=10`
      was placed and returned a valid order id.
- [ ] **Pyramid add:** `scripts/alpaca.sh stop SYM COMBINED_QTY --price=WAVG`
      was placed (a fixed break-even stop, not a trail) and returned a valid
      order id.
- [ ] The trade is appended to `TRADE-LOG.md` with entry, stop id, catalyst,
      thesis, and risk. Pyramid adds use `type: pyramid-add` and record the
      new weighted-average cost basis.
- [ ] `git push origin main` has succeeded.
- [ ] Telegram has been notified (or fallback log exists).

If any bullet is unchecked, the trade is not complete. Do the missing step or
close the position — never leave a half-done buy.

---

## What you are not allowed to do

- Create `.env`, write secrets to any file, or log credentials.
- Edit `TRADING-STRATEGY.md` outside the Friday weekly-review routine.
- Delete or edit historical log entries.
- Submit any order the gate rejects.
- Submit a buy without queueing its trailing stop in the same firing.
- Use options, futures, FX, crypto, or fractional shares.
- Skip the commit+push step. Silent state is corrupted state.
- Call external APIs with `curl` directly — always use `scripts/*.sh`.

---

## Local development

Outside the cloud routines, the operator runs things locally from
`C:\Users\shael\Trading Routine`. The repo ships:

- `scripts/tests/run-all.sh` — the full test harness, must stay green on
  every commit.
- `.claude/commands/*.md` — local slash commands for manual inspection
  (`/status`, `/idea`, `/gate`, `/buy`, `/close`, `/research`, `/review`).
- `env.template` — the schema of `.env`. The operator's real `.env` is
  gitignored and never committed.

---

## When in doubt

Stop, commit what you have, notify Telegram, and exit cleanly. A missed
routine is recoverable — a broken invariant is not.
