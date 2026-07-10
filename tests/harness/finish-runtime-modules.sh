#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Finish runtime module contract =="

fail() {
  echo "ERROR: $1"
  exit 1
}

assert_exists "$repo_root/templates/scripts/lib/harness-common.sh"
assert_exists "$repo_root/templates/scripts/lib/finish-summary.sh"
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

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/finish-summary.sh"
  run_dir="$tmp_root/finish-summary-failure"
  mkdir -p "$run_dir"
  timestamp=20260710-000000
  mode=strict
  mode_arg=--strict
  start_epoch=0
  elapsed_seconds=0
  resource_status=0
  agent_md_status=0
  scope_status=0
  policy_status=0
  tdd_evidence_status=0
  acceptance_status=0
  review_status=0
  architecture_status=0
  failure_attribution_status=0
  interventions_status=0
  command_ledger_status=0
  sandbox_evidence_status=0
  subagent_evidence_status=0
  episode_status=0
  verify_status=0
  summary_file="$run_dir/finish-summary.md"
  summary_json_file="$run_dir/finish-summary.json"
  changed_files_file="$run_dir/changed-files.txt"
  diff_stat_file="$run_dir/git-diff-stat.txt"
  resource_result_file="$run_dir/resource-envelope-result.txt"
  check_agent_md_result_file="$run_dir/check-agent-md-result.txt"
  scope_result_file="$run_dir/scope-result.txt"
  policy_result_file="$run_dir/policy-result.txt"
  tdd_evidence_result_file="$run_dir/tdd-evidence-result.txt"
  acceptance_result_file="$run_dir/acceptance-result.txt"
  review_result_file="$run_dir/review-result.txt"
  architecture_result_file="$run_dir/architecture-evidence-result.txt"
  failure_attribution_result_file="$run_dir/failure-attribution-result.txt"
  interventions_result_file="$run_dir/interventions-result.txt"
  command_ledger_result_file="$run_dir/command-ledger-result.txt"
  sandbox_evidence_result_file="$run_dir/sandbox-evidence-result.txt"
  subagent_evidence_result_file="$run_dir/subagent-evidence-result.txt"
  episode_result_file="$run_dir/episode-result.txt"
  verify_result_file="$run_dir/verify-result.txt"
  episode_summary_json_file="$run_dir/episode-summary.json"
  python_bin=false
  if finish_write_json_summary pass; then
    fail "JSON serializer failure was reported as success"
  fi
  [ ! -e "$summary_json_file" ] || fail "failed JSON write exposed final output"
)

pass "finish runtime public contract is characterized"
