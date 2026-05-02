#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-finish.sh [--strict|--best-effort]

Modes:
  --strict       Default. Run all completion gates in blocking mode.
  --best-effort  Run scope and policy gates in warning mode, and verification
                 in best-effort mode.
  -h, --help     Show this help text.
EOF
}

mode="strict"
mode_arg="--strict"

case "${1:-}" in
  "")
    ;;
  --strict)
    mode="strict"
    mode_arg="--strict"
    ;;
  --best-effort)
    mode="best-effort"
    mode_arg="--best-effort"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unsupported mode: ${1:-}"
    usage
    exit 2
    ;;
esac

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
run_dir=".agent/runs/$timestamp"
summary_file="$run_dir/finish-summary.md"
check_agent_md_result_file="$run_dir/check-agent-md-result.txt"
scope_result_file="$run_dir/scope-result.txt"
policy_result_file="$run_dir/policy-result.txt"
verify_result_file="$run_dir/verify-result.txt"
changed_files_file="$run_dir/changed-files.txt"
diff_stat_file="$run_dir/git-diff-stat.txt"
failures=0
last_status=0

agent_md_status=""
scope_status=""
policy_status=""
verify_status=""

mkdir -p "$run_dir"

write_git_evidence() {
  local changed_files
  local diff_stat

  {
    echo "# Changed files"
    echo
    if ! command -v git >/dev/null 2>&1; then
      echo "git is unavailable; changed files could not be collected."
    elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a git repository; changed files could not be collected."
    else
      changed_files="$(
        {
          git diff --name-only HEAD 2>/dev/null || true
          git ls-files --others --exclude-standard 2>/dev/null || true
        } | awk 'NF' | sort -u
      )"
      if [ -n "$changed_files" ]; then
        printf '%s\n' "$changed_files"
      else
        echo "No changed files detected."
      fi
    fi
  } >"$changed_files_file"

  {
    echo "# Git diff stat"
    echo
    if ! command -v git >/dev/null 2>&1; then
      echo "git is unavailable; diff stat could not be collected."
    elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a git repository; diff stat could not be collected."
    else
      diff_stat="$(git diff --stat HEAD 2>/dev/null || git diff --stat 2>/dev/null || true)"
      if [ -n "$diff_stat" ]; then
        printf '%s\n' "$diff_stat"
      else
        echo "No tracked diff detected."
      fi
    fi
  } >"$diff_stat_file"
}

write_summary() {
  local overall_result="$1"
  local next_action

  if [ "$overall_result" = "pass" ]; then
    next_action="Update handoff.md with the run directory path, changed files, verification result, and the next action for the human or next agent."
  else
    next_action="Review the failing result files, fix the reported issues, then rerun scripts/agent-finish.sh $mode_arg."
  fi

  {
    echo "# Agent Finish Summary"
    echo
    echo "- Timestamp: $timestamp"
    echo "- Mode: $mode"
    echo "- Command: scripts/agent-finish.sh $mode_arg"
    echo "- Run directory: $run_dir"
    echo "- Overall result: $overall_result"
    echo
    echo "## Gate Results"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| check-agent-md | $agent_md_status | $check_agent_md_result_file |"
    echo "| check-scope | $scope_status | $scope_result_file |"
    echo "| check-policy | $policy_status | $policy_result_file |"
    echo "| agent-verify | $verify_status | $verify_result_file |"
    echo
    echo "## Changed Files"
    echo
    echo "Evidence: $changed_files_file"
    echo
    echo '```text'
    cat "$changed_files_file"
    echo '```'
    echo
    echo "## Git Diff Stat"
    echo
    echo "Evidence: $diff_stat_file"
    echo
    echo '```text'
    cat "$diff_stat_file"
    echo '```'
    echo
    echo "## Next Recommended Action"
    echo
    echo "$next_action"
    echo
    echo "## Result"
    echo
    echo "AGENT_FINISH_RESULT=$overall_result"
  } >"$summary_file"
}

run_gate() {
  local label="$1"
  local result_file="$2"
  local output_file="$result_file.output"
  shift
  shift

  echo
  echo "RUN: $label"

  set +e
  "$@" >"$output_file" 2>&1
  last_status=$?
  set -e

  {
    echo "Check: $label"
    echo "Command: $*"
    echo "Exit status: $last_status"
    echo
    echo "Output:"
    cat "$output_file"
  } >"$result_file"

  cat "$output_file"
  rm -f "$output_file"

  if [ "$last_status" -ne 0 ]; then
    failures=$((failures + 1))
  fi
}

echo "== Agent Finish Gate =="
echo "Mode: $mode"
echo "Run directory: $run_dir"

if [ "$mode" = "strict" ]; then
  run_gate "check-agent-md" "$check_agent_md_result_file" bash scripts/check-agent-md.sh agent.md
  agent_md_status="$last_status"
  run_gate "check-scope" "$scope_result_file" bash scripts/check-scope.sh --strict
  scope_status="$last_status"
  run_gate "check-policy" "$policy_result_file" bash scripts/check-policy.sh --strict
  policy_status="$last_status"
  run_gate "agent-verify" "$verify_result_file" bash scripts/agent-verify.sh --strict
  verify_status="$last_status"
else
  run_gate "check-agent-md" "$check_agent_md_result_file" bash scripts/check-agent-md.sh agent.md
  agent_md_status="$last_status"
  run_gate "check-scope" "$scope_result_file" bash scripts/check-scope.sh --warn
  scope_status="$last_status"
  run_gate "check-policy" "$policy_result_file" bash scripts/check-policy.sh --warn
  policy_status="$last_status"
  run_gate "agent-verify" "$verify_result_file" bash scripts/agent-verify.sh --best-effort
  verify_status="$last_status"
fi

write_git_evidence

if [ "$failures" -gt 0 ]; then
  write_summary "fail"
  echo "AGENT_FINISH_RESULT=fail"
  echo "Agent finish gates failed."
  echo "Run directory: $run_dir"
  echo "Summary: $summary_file"
  exit 1
fi

write_summary "pass"

echo "AGENT_FINISH_RESULT=pass"
echo "Agent finish gates passed."
echo "Run directory: $run_dir"
echo "Summary: $summary_file"
