# Setup & Runbook

Everything the operator needs to (a) stand the bot up from scratch and (b) recover when something breaks.

---

## 1. External account setup

### Alpaca (broker)

1. Create a free account at <https://alpaca.markets>.
2. Switch to the **paper** dashboard: <https://app.alpaca.markets/paper/dashboard/overview>.
3. Generate API keys in "API Keys" (left sidebar). Copy `Key ID` → `ALPACA_API_KEY` and `Secret Key` → `ALPACA_SECRET_KEY`.
4. Confirm endpoints:
   - Trading: `https://paper-api.alpaca.markets` (already in `env.template`).
   - Data:    `https://data.alpaca.markets` (already in `env.template`).
5. Reset paper-account equity to $1,000 via dashboard if it's not already (Account → Reset). If the reset minimum is higher than $1,000, set `VIRTUAL_EQUITY=1000` in `.env` so the gate treats the account as $1k for tier sizing.

### Tavily (research)

1. Sign up at <https://app.tavily.com> — free tier is 1,000 searches/month.
2. Copy the API key into `TAVILY_API_KEY`.
3. If you hit the quota, `scripts/tavily.sh` exits 3 and routines fall back to Claude's built-in `WebSearch` — no action needed.

### Telegram (notifications)

1. Talk to `@BotFather` on Telegram → `/newbot` → follow the prompts. Copy the token into `TELEGRAM_BOT_TOKEN`.
2. Talk to `@userinfobot` to get your numeric chat id → `TELEGRAM_CHAT_ID`.
3. Send the bot any message (e.g. `/start`) so it's allowed to DM you.

---

## 2. Local `.env`

`env.template` is the schema. Copy and fill:

```bash
cp env.template .env
# Edit .env — never commit. `.gitignore` excludes it and the test
# suite enforces that check.
```

`.env` layout:

```
ALPACA_API_KEY=...
ALPACA_SECRET_KEY=...
ALPACA_ENDPOINT=https://paper-api.alpaca.markets
ALPACA_DATA_ENDPOINT=https://data.alpaca.markets
TAVILY_API_KEY=...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
# Optional:
# VIRTUAL_EQUITY=1000
```

Verify:

```bash
bash scripts/tests/run-all.sh
```

Should print `Summary: N passed, 0 failed`. If `.env` is present the live-read tests against Alpaca/Tavily will run; they skip cleanly without credentials.

---

## 3. Cloud routine setup (Claude Code)

1. Open Claude Code → **Routines** → **New routine** (six total).
2. For each routine:
   - **Name:** `pre-market` / `market-open` / `midday` / `earnings-risk-check` / `daily-summary` / `weekly-review`.
   - **Schedule (Europe/London):**
     - `pre-market`:          `0 12 * * 1-5`
     - `market-open`:         `45 14 * * 1-5`
     - `midday`:              `0 18 * * 1-5`
     - `earnings-risk-check`: `30 19 * * 1-5`
     - `daily-summary`:       `5 21 * * 1-5`
     - `weekly-review`:       `10 21 * * 5`
   - **Prompt:** copy the contents of `cloud-routines/<name>.md` verbatim.
   - **Environment variables:** inject every key from `.env` individually. Do **not** paste the entire `.env` file. The routine reads directly from `$ALPACA_API_KEY` etc. and must never create a `.env` file at runtime.
3. **GitHub App access:** grant the Claude GitHub App write permission on this repo (GitHub → Settings → Applications). Routines clone, commit, and push.
4. **Dry-run:** trigger `pre-market` manually from the Claude Code UI. Verify: commit lands on `main`, Telegram message arrives.

---

## 4. Going live

Do **not** flip to live until all of:

- ≥ 4 consecutive grade-B-or-better weeks on paper (see `memory/WEEKLY-REVIEW.md`).
- Zero material rule violations across the 4-week window.
- Profit factor ≥ 1.5 over the same window.
- Profit-factor and win-rate trendlines are flat-or-up, not propped by one outlier.

To flip:

1. Open a live Alpaca account and generate live API keys (separate from paper).
2. Replace `ALPACA_API_KEY`, `ALPACA_SECRET_KEY` in every routine's env vars with the live keys.
3. Change `ALPACA_ENDPOINT` to `https://api.alpaca.markets` (drop `paper-`).
4. Leave `ALPACA_DATA_ENDPOINT` unchanged.
5. Seed the live account at roughly the same equity as paper was at go-live (~£1,000).
6. Watch the first three routine firings closely.

---

## 5. Runbook (when things break)

### Telegram silent

- Check `memory/notification_fallback.log`. If it has entries, the bot saw the problem and kept going. Daily-summary will drain it.
- Test manually: `bash scripts/telegram.sh send "test"`. Exit code 0 and `{"ok":true,...}` response ⇒ creds fine.
- If creds are fine but the bot doesn't DM you: send `/start` to the bot again and retry.

### Alpaca 401/403

- Regenerate API keys at Alpaca paper dashboard, update env vars in every cloud routine, retry.
- Keys are valid but positions endpoint empty: you're on the wrong endpoint. Confirm `ALPACA_ENDPOINT=https://paper-api.alpaca.markets`.

### Tavily out of quota

- `scripts/tavily.sh search` returns exit 3. Routines automatically fall back to `WebSearch`. No action required unless you want to upgrade the plan.

### A position has no stop

1. Run `bash scripts/alpaca.sh orders --status=open` and confirm nothing references the symbol.
2. Place one immediately: `bash scripts/alpaca.sh trailing-stop <SYM> <QTY> --percent=10`.
3. Note the incident in `memory/TRADE-LOG.md` under the existing entry ("stop-gap: placed at HH:MM UK because …").
4. Commit + push.

### Git push rejected by routine

- The routine's clone is stale. Trigger the routine manually once to sync. Subsequent scheduled firings will be fine.
- If the routine repeatedly can't push, the GitHub App token was revoked. Re-grant it.

### Bot is doing something I don't like

Revoke the Claude GitHub App on this repo (GitHub → Settings → Applications). Every future cron firing no-ops. Open positions and their GTC stops remain active on Alpaca — manage them manually until you re-install.

---

## 6. Updating the strategy

`memory/TRADING-STRATEGY.md` is edited **only** by the Friday weekly-review routine, and only when the grading trend justifies it (2 weeks ≤ C, or a single catastrophic week). Any manual edit should:

1. Happen in the same commit as an entry in `memory/WEEKLY-REVIEW.md` explaining the change.
2. Update the "Last reviewed" date at the top of `TRADING-STRATEGY.md`.
3. Pass the full test suite (`bash scripts/tests/run-all.sh`).

---

## 7. What the tests prove (and don't)

`scripts/tests/run-all.sh` validates:

- Repo hygiene (`.env` ignored, LF line endings, memory files exist with the required sections).
- Wrapper scripts behave correctly on missing creds (fail-closed for Alpaca/gate, fail-open for Telegram, exit-3 for Tavily).
- `gate.sh` evaluates all 13 fixtured cases correctly across Tier 1/2/3.
- `CLAUDE.md`, `.claude/commands/*.md`, `cloud-routines/*.md` all contain the invariant phrases — so a future edit can't silently delete them.
- Optional: live round-trip on paper Alpaca (buy → stop → cancel → close) behind `TRADING_ROUTINE_LIVE_ORDERS=1`.

They do **not** validate:

- That a trade idea is a good idea. That's the operator's (and the strategy's) job.
- That the US market is open. Routines must check `alpaca.sh account.trading_blocked` and equivalent.
- That you've deposited money into live Alpaca if you flipped. You have to do that yourself.
