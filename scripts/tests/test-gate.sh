#!/usr/bin/env bash
# gate.sh — pure-function buy-side gate.
# Reads trade idea JSON on stdin, writes decision JSON on stdout.
# Tested via fixtures/gate-cases.json. Every case in the fixture contributes
# one pass/fail for "approved" match and another for the reasons[] constraint.

GATE="$ROOT/scripts/gate.sh"
FIX="$ROOT/scripts/tests/fixtures/gate-cases.json"

assert_file_exists "$GATE" "gate.sh exists"
[ -x "$GATE" ] && _pass "gate.sh executable" || _fail "gate.sh executable" "chmod +x missing"
assert_file_exists "$FIX" "gate-cases fixture exists"

if [ ! -x "$GATE" ] || [ ! -f "$FIX" ]; then
  _fail "gate cases: skipping" "gate.sh or fixture missing"
  return 0 2>/dev/null || exit 0
fi

# Iterate cases.
n=$(jq 'length' "$FIX")
i=0
while [ "$i" -lt "$n" ]; do
  name=$(jq -r ".[$i].name" "$FIX")
  input=$(jq -c ".[$i].input" "$FIX")
  expected_approved=$(jq -r ".[$i].approved" "$FIX")

  out=$(printf '%s' "$input" | "$GATE" 2>/dev/null) || out=""
  if [ -z "$out" ]; then
    _fail "gate[$i] $name: produced output" "no stdout"
    i=$((i+1)); continue
  fi

  actual_approved=$(printf '%s' "$out" | jq -r '.approved' 2>/dev/null)
  if [ "$actual_approved" = "$expected_approved" ]; then
    _pass "gate[$i] $name: approved=$expected_approved"
  else
    _fail "gate[$i] $name: approved=$expected_approved" "got=$actual_approved out=$out"
  fi

  # Optional reasons[] subset check.
  has_sub=$(jq -r ".[$i] | has(\"reasons_contains\")" "$FIX")
  if [ "$has_sub" = "true" ]; then
    need_json=$(jq -c ".[$i].reasons_contains" "$FIX")
    miss=$(jq -n --argjson got "$(printf '%s' "$out" | jq '.reasons')" --argjson need "$need_json" \
      '[$need[] | select(. as $r | ($got // []) | index($r) == null)]' 2>/dev/null)
    if [ "$miss" = "[]" ]; then
      _pass "gate[$i] $name: reasons contain all expected tags"
    else
      _fail "gate[$i] $name: reasons contain all expected tags" "missing=$miss actual=$(printf '%s' "$out" | jq -c '.reasons')"
    fi
  fi

  # If approved, reasons must be empty.
  has_exact=$(jq -r ".[$i] | has(\"reasons\")" "$FIX")
  if [ "$has_exact" = "true" ] && [ "$expected_approved" = "true" ]; then
    actual_reasons=$(printf '%s' "$out" | jq -c '.reasons')
    if [ "$actual_reasons" = "[]" ]; then
      _pass "gate[$i] $name: approved ⇒ reasons=[]"
    else
      _fail "gate[$i] $name: approved ⇒ reasons=[]" "got=$actual_reasons"
    fi
  fi

  i=$((i+1))
done

# Malformed input handling.
bad_out=$(printf '%s' 'not json' | "$GATE" 2>/dev/null) ; rc=$?
if [ "$rc" -ne 0 ]; then
  _pass "malformed stdin → non-zero exit"
else
  _fail "malformed stdin → non-zero exit" "rc=0 out=$bad_out"
fi
