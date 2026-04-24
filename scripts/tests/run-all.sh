#!/usr/bin/env bash
# Discover and run every tests/test-*.sh file. Aggregate PASS/FAIL counts.
# Exits 0 if all tests pass, 1 otherwise.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

export ROOT HERE
export TESTS_PASSED=0
export TESTS_FAILED=0

# Per-file counters are summed via file (subshells can't mutate parent vars).
RESULTS="$(mktemp)"
trap 'rm -f "$RESULTS"' EXIT

shopt -s nullglob
FILES=("$HERE"/test-*.sh)
shopt -u nullglob

if [ "${#FILES[@]}" -eq 0 ]; then
  printf '\033[33mNo tests found.\033[0m\n'
  exit 0
fi

OVERALL_PASS=0
OVERALL_FAIL=0

for f in "${FILES[@]}"; do
  name="$(basename "$f" .sh)"
  printf '\n\033[1m%s\033[0m\n' "$name"
  # Run each file in a subshell so state doesn't leak.
  (
    set -u
    TESTS_PASSED=0
    TESTS_FAILED=0
    CURRENT_TEST="$name"
    # shellcheck source=lib/assert.sh
    . "$HERE/lib/assert.sh"
    # shellcheck disable=SC1090
    . "$f"
    printf '%d %d\n' "$TESTS_PASSED" "$TESTS_FAILED" > "$RESULTS"
  )
  read -r p fcount < "$RESULTS" || { p=0; fcount=1; }
  OVERALL_PASS=$((OVERALL_PASS + p))
  OVERALL_FAIL=$((OVERALL_FAIL + fcount))
done

printf '\n\033[1mSummary:\033[0m %d passed, %d failed\n' "$OVERALL_PASS" "$OVERALL_FAIL"
[ "$OVERALL_FAIL" -eq 0 ]
