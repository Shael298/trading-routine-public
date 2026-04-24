#!/usr/bin/env bash
# Self-check: the assertion primitives themselves must behave correctly.
# assert.sh has already been sourced by run-all.sh.

assert_eq "abc" "abc" "assert_eq passes when equal"
assert_ne "abc" "xyz" "assert_ne passes when different"
assert_contains "hello world" "world" "assert_contains finds substring"
assert_not_contains "hello world" "zzz" "assert_not_contains confirms absence"
assert_file_exists "$HERE/run-all.sh" "run-all.sh exists"
assert_dir_exists "$HERE/lib" "lib/ dir exists"
assert_file_contains "$HERE/lib/assert.sh" "^assert_eq" "assert.sh defines assert_eq"
assert_exit_code 0 0 "assert_exit_code matches on zero"
assert_dir_exists "$ROOT/memory" "ROOT resolves to repo root (memory/ present)"

# jq round-trip
assert_json_eq '{"a":{"b":42}}' '.a.b' '42' "assert_json_eq traverses nested keys"
