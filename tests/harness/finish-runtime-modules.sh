#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Finish runtime module contract =="

fail() {
  echo "ERROR: $1"
  exit 1
}

count_matches() {
  local pattern="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -c "$pattern" "$file"
    return
  fi

  grep -Ec -- "$pattern" "$file" || true
}

print_matches() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@"
    return
  fi

  if grep -En -- "$pattern" "$@"; then
    return 0
  fi

  return 1
}

assert_exists "$repo_root/templates/scripts/lib/harness-common.sh"
assert_exists "$repo_root/templates/scripts/lib/finish-summary.sh"
assert_exists "$repo_root/templates/scripts/lib/gate-registry.sh"
assert_exists "$repo_root/templates/scripts/lib/finish-runner.sh"
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
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'source "$script_dir/lib/finish-summary.sh"'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'run_gate() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'run_gate "check-'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'finish_run_registered_gates "$mode" "$run_dir"'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'source "$script_dir/lib/harness-common.sh"'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'have_cmd() {'
assert_not_contains "$repo_root/templates/scripts/agent-verify.sh" 'find_python() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_summary() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_json_summary() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_episode_summary() {'
assert_contains "$repo_root/templates/scripts/lib/finish-summary.sh" \
  'finish_write_markdown_summary() {'
assert_contains "$repo_root/templates/scripts/lib/finish-summary.sh" \
  'finish_write_json_summary() {'

registration_count="$(count_matches '^  finish_register_gate ' \
  "$repo_root/templates/scripts/lib/gate-registry.sh")"
[ "$registration_count" -eq 15 ] || \
  fail "expected 15 registered finish gates, got $registration_count"

if print_matches 'declare -A|local -n|mapfile' \
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

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  source "$repo_root/templates/scripts/lib/finish-summary.sh"
  run_dir="$tmp_root/finish-summary-failure"
  mkdir -p "$run_dir"
  timestamp=20260710-000000
  mode=strict
  mode_arg=--strict
  start_epoch=0
  elapsed_seconds=0
  resource_status=0
  finish_init_gate_registry
  for gate_index in "${!FINISH_GATE_STATUSES[@]}"; do
    FINISH_GATE_STATUSES[$gate_index]=0
  done
  summary_file="$run_dir/finish-summary.md"
  summary_json_file="$run_dir/finish-summary.json"
  changed_files_file="$run_dir/changed-files.txt"
  diff_stat_file="$run_dir/git-diff-stat.txt"
  resource_result_file="$run_dir/resource-envelope-result.txt"
  episode_summary_json_file="$run_dir/episode-summary.json"
  python_bin=false
  if finish_write_json_summary pass; then
    fail "JSON serializer failure was reported as success"
  fi
  [ ! -e "$summary_json_file" ] || fail "failed JSON write exposed final output"
)

(
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  finish_init_gate_registry
  finish_validate_gate_registry
  expected_gate_ids="check-agent-md check-scope check-policy check-tdd-evidence "
  expected_gate_ids+="check-acceptance check-review-evidence "
  expected_gate_ids+="check-architecture-evidence check-failure-attribution "
  expected_gate_ids+="check-interventions check-command-ledger "
  expected_gate_ids+="check-sandbox-evidence check-subagent-evidence "
  expected_gate_ids+="validate-episode agent-verify resource-envelope"
  [ "${FINISH_GATE_IDS[*]}" = "$expected_gate_ids" ] || \
    fail "registered gate order changed: ${FINISH_GATE_IDS[*]}"
)

(
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  finish_init_gate_registry
  FINISH_GATE_IDS+=("check-agent-md")
  if finish_validate_gate_registry >"$tmp_root/duplicate-id.log" 2>&1; then
    fail "duplicate gate ID unexpectedly validated"
  fi
  assert_contains "$tmp_root/duplicate-id.log" "duplicate gate ID: check-agent-md"
)

(
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  finish_init_gate_registry
  FINISH_GATE_RESULT_NAMES=("${FINISH_GATE_RESULT_NAMES[@]:0:14}")
  if finish_validate_gate_registry >"$tmp_root/length-mismatch.log" 2>&1; then
    fail "mismatched registry arrays unexpectedly validated"
  fi
  assert_contains "$tmp_root/length-mismatch.log" "registry array length mismatch"
)

runner_root="$tmp_root/finish-runner-modules"
mkdir -p "$runner_root/run"
printf '%s\n' '#!/usr/bin/env bash' 'echo pass-output' 'exit 0' \
  >"$runner_root/pass.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo fail-output' 'exit 7' \
  >"$runner_root/fail.sh"
chmod +x "$runner_root/pass.sh" "$runner_root/fail.sh"

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  source "$repo_root/templates/scripts/lib/finish-runner.sh"
  FINISH_GATE_IDS=()
  FINISH_GATE_KINDS=()
  FINISH_GATE_GROUPS=()
  FINISH_GATE_SCRIPTS=()
  FINISH_GATE_COMMON_ARGS=()
  FINISH_GATE_STRICT_ARGS=()
  FINISH_GATE_BEST_EFFORT_ARGS=()
  FINISH_GATE_RESULT_NAMES=()
  FINISH_GATE_TASK_FLAGS=()
  FINISH_GATE_STATUSES=()
  finish_register_gate pass command 'Core Guardrails' \
    "$runner_root/pass.sh" '' '' '' pass-result.txt ''
  finish_register_gate fail command 'Core Guardrails' \
    "$runner_root/fail.sh" '' '' '' fail-result.txt ''
  failures=0
  finish_run_registered_gates strict "$runner_root/run" || true
  [ "${FINISH_GATE_STATUSES[0]}" -eq 0 ] || fail "pass gate status changed"
  [ "${FINISH_GATE_STATUSES[1]}" -eq 7 ] || fail "fail gate status changed"
  [ "$failures" -eq 1 ] || fail "expected one runner failure"
  assert_contains "$runner_root/run/pass-result.txt" "pass-output"
  assert_contains "$runner_root/run/fail-result.txt" "fail-output"
)

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  source "$repo_root/templates/scripts/lib/finish-runner.sh"
  FINISH_GATE_IDS=()
  FINISH_GATE_KINDS=()
  FINISH_GATE_GROUPS=()
  FINISH_GATE_SCRIPTS=()
  FINISH_GATE_COMMON_ARGS=()
  FINISH_GATE_STRICT_ARGS=()
  FINISH_GATE_BEST_EFFORT_ARGS=()
  FINISH_GATE_RESULT_NAMES=()
  FINISH_GATE_TASK_FLAGS=()
  FINISH_GATE_STATUSES=()
  finish_register_gate write-failure command 'Core Guardrails' \
    "$runner_root/pass.sh" '' '' '' missing/result.txt ''
  failures=0
  if finish_run_registered_gates strict "$runner_root/run"; then
    fail "runner accepted an evidence write failure"
  fi
  [ "$failures" -eq 1 ] || fail "evidence write failure was not counted"
  [ "${FINISH_GATE_STATUSES[0]}" -ne 0 ] || \
    fail "evidence write failure was recorded as pass"
)

pass "finish runtime public contract is characterized"
