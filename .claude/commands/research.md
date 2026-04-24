---
description: Run a research query via Tavily; fall back to WebSearch on exit 3. Returns a summary with source links.
allowed-tools: Bash, WebSearch
---

Argument: `$ARGUMENTS` — free-text search query (e.g. "semiconductor catalysts earnings week" or "NVDA guidance revision").

**Steps:**

1. Run `bash scripts/tavily.sh search --max-results=5 "$ARGUMENTS"`.
2. **If exit code = 3** (auth/network/missing key), fall back: invoke the `WebSearch` tool with the same query.
3. **If exit code = 4** (API rejected payload), retry once with `--depth=basic` and `--max-results=3`.
4. Parse the response:
   - If Tavily: use `.answer` for the one-line summary and `.results[] | {title, url, content}` for sources.
   - If WebSearch: pick the top 3 results and summarise in one paragraph.
5. Output to the operator:
   - **TL;DR** — one sentence
   - **Key facts** — 3–5 bullets, each with a source link
   - **Relevance to the book** — one line on why this matters (or "nothing actionable" if it doesn't).

No orders. No commits. If this query produced a tradable idea, tell the operator to run `/idea <SYM>` next.
