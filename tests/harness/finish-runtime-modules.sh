#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Finish runtime module contract =="

assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'Usage: agent-finish.sh [--strict|--best-effort]'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=pass'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=fail'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'Usage: agent-verify.sh [--strict|--best-effort]'

if rg -n 'declare -A|local -n|mapfile' \
  "$repo_root/templates/scripts/agent-finish.sh" \
  "$repo_root/templates/scripts/agent-verify.sh"
then
  fail "finish runtime uses Bash features newer than the supported baseline"
fi

pass "finish runtime public contract is characterized"
