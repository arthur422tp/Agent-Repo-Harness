#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Finish runtime module contract =="

assert_exists "$repo_root/templates/scripts/lib/harness-common.sh"
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'Usage: agent-finish.sh [--strict|--best-effort]'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=pass'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=fail'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'Usage: agent-verify.sh [--strict|--best-effort]'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'source "$script_dir/lib/harness-common.sh"'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'source "$script_dir/lib/harness-common.sh"'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'have_cmd() {'
assert_not_contains "$repo_root/templates/scripts/agent-verify.sh" 'find_python() {'

if rg -n 'declare -A|local -n|mapfile' \
  "$repo_root/templates/scripts/agent-finish.sh" \
  "$repo_root/templates/scripts/agent-verify.sh"
then
  fail "finish runtime uses Bash features newer than the supported baseline"
fi

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  atomic_root="$tmp_root/harness-common-atomic"
  mkdir -p "$atomic_root"
  temporary="$(harness_make_temp_file "$atomic_root" summary)"
  printf '%s\n' complete >"$temporary"
  harness_atomic_replace "$temporary" "$atomic_root/final.txt"
  assert_contains "$atomic_root/final.txt" complete
  [ ! -e "$temporary" ] || fail "atomic replacement left its temporary file"

  temporary="$(harness_make_temp_file "$atomic_root" failure)"
  printf '%s\n' incomplete >"$temporary"
  if harness_atomic_replace "$temporary" "$atomic_root/missing/final.txt"; then
    fail "atomic replacement accepted a missing destination directory"
  fi
  [ ! -e "$atomic_root/missing/final.txt" ] || \
    fail "atomic replacement exposed partial final content"
)

pass "finish runtime public contract is characterized"
