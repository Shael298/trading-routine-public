#!/usr/bin/env bash
# Minimal assertion primitives. Sourced by tests/*.sh.
# Each assertion prints PASS/FAIL and increments counters in the calling scope.

: "${TESTS_PASSED:=0}"
: "${TESTS_FAILED:=0}"
: "${CURRENT_TEST:=unknown}"

_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[32m✓\033[0m %s\n' "$1"
}

_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[31m✗\033[0m %s\n' "$1"
  printf '      %s\n' "$2"
}

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-values equal}"
  if [ "$expected" = "$actual" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected=<$expected> actual=<$actual>"
  fi
}

assert_ne() {
  local a="$1" b="$2" msg="${3:-values differ}"
  if [ "$a" != "$b" ]; then
    _pass "$msg"
  else
    _fail "$msg" "both=<$a>"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-contains substring}"
  case "$haystack" in
    *"$needle"*) _pass "$msg" ;;
    *) _fail "$msg" "needle=<$needle> not in haystack (len=${#haystack})" ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-does not contain substring}"
  case "$haystack" in
    *"$needle"*) _fail "$msg" "needle=<$needle> found in haystack" ;;
    *) _pass "$msg" ;;
  esac
}

assert_file_exists() {
  local path="$1" msg="${2:-file exists: $1}"
  if [ -f "$path" ]; then _pass "$msg"; else _fail "$msg" "missing: $path"; fi
}

assert_dir_exists() {
  local path="$1" msg="${2:-dir exists: $1}"
  if [ -d "$path" ]; then _pass "$msg"; else _fail "$msg" "missing: $path"; fi
}

assert_file_contains() {
  local path="$1" pattern="$2" msg="${3:-$1 matches /$2/}"
  if [ ! -f "$path" ]; then _fail "$msg" "file not found: $path"; return; fi
  if grep -Eq -- "$pattern" "$path"; then
    _pass "$msg"
  else
    _fail "$msg" "pattern not found: $pattern"
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-exit code == $expected}"
  if [ "$expected" = "$actual" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected=$expected actual=$actual"
  fi
}

assert_json_eq() {
  local json="$1" jq_expr="$2" expected="$3" msg="${4:-jq $jq_expr == $expected}"
  local actual
  actual=$(printf '%s' "$json" | jq -r "$jq_expr" 2>/dev/null) || {
    _fail "$msg" "jq failed on expr=$jq_expr"; return
  }
  if [ "$actual" = "$expected" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected=<$expected> actual=<$actual>"
  fi
}
