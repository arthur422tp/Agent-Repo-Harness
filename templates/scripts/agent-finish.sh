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
summary_json_file="$run_dir/finish-summary.json"
start_epoch="$(date -u +%s)"
elapsed_seconds=0
resource_status="0"
resource_result_file="$run_dir/resource-envelope-result.txt"
check_agent_md_result_file="$run_dir/check-agent-md-result.txt"
scope_result_file="$run_dir/scope-result.txt"
policy_result_file="$run_dir/policy-result.txt"
tdd_evidence_result_file="$run_dir/tdd-evidence-result.txt"
acceptance_result_file="$run_dir/acceptance-result.txt"
review_result_file="$run_dir/review-result.txt"
subagent_evidence_result_file="$run_dir/subagent-evidence-result.txt"
verify_result_file="$run_dir/verify-result.txt"
changed_files_file="$run_dir/changed-files.txt"
diff_stat_file="$run_dir/git-diff-stat.txt"
failures=0
last_status=0

agent_md_status=""
scope_status=""
policy_status=""
tdd_evidence_status=""
acceptance_status=""
review_status=""
subagent_evidence_status=""
verify_status=""

mkdir -p "$run_dir"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_python() {
  if have_cmd python3; then
    printf '%s\n' "python3"
    return 0
  fi
  if have_cmd python; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

python_bin=""
if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for finish evidence writes"
  exit 1
fi

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
        } | awk '
          NF &&
          $0 !~ /^\.agent\/runs\// &&
          $0 !~ /^agent-finish-.*\.log$/
        ' | sort -u
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
    echo "| check-tdd-evidence | $tdd_evidence_status | $tdd_evidence_result_file |"
    echo "| check-acceptance | $acceptance_status | $acceptance_result_file |"
    echo "| check-review-evidence | $review_status | $review_result_file |"
    echo "| check-subagent-evidence | $subagent_evidence_status | $subagent_evidence_result_file |"
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

write_json_summary() {
  local overall_result="$1"
  local end_epoch

  end_epoch="$(date -u +%s)"
  elapsed_seconds=$((end_epoch - start_epoch))

  SUMMARY_JSON_FILE="$summary_json_file" \
  AGENT_FINISH_TIMESTAMP="$timestamp" \
  AGENT_FINISH_MODE="$mode" \
  AGENT_FINISH_MODE_ARG="$mode_arg" \
  AGENT_FINISH_RUN_DIR="$run_dir" \
  AGENT_FINISH_OVERALL_RESULT="$overall_result" \
  AGENT_FINISH_ELAPSED_SECONDS="$elapsed_seconds" \
  AGENT_FINISH_RESOURCE_STATUS="${resource_status:-0}" \
  AGENT_FINISH_CHECK_AGENT_MD_STATUS="${agent_md_status:-0}" \
  AGENT_FINISH_SCOPE_STATUS="${scope_status:-0}" \
  AGENT_FINISH_POLICY_STATUS="${policy_status:-0}" \
  AGENT_FINISH_TDD_EVIDENCE_STATUS="${tdd_evidence_status:-0}" \
  AGENT_FINISH_ACCEPTANCE_STATUS="${acceptance_status:-0}" \
  AGENT_FINISH_REVIEW_STATUS="${review_status:-0}" \
  AGENT_FINISH_SUBAGENT_EVIDENCE_STATUS="${subagent_evidence_status:-0}" \
  AGENT_FINISH_VERIFY_STATUS="${verify_status:-0}" \
  AGENT_FINISH_CHECK_AGENT_MD_EVIDENCE="$check_agent_md_result_file" \
  AGENT_FINISH_SCOPE_EVIDENCE="$scope_result_file" \
  AGENT_FINISH_POLICY_EVIDENCE="$policy_result_file" \
  AGENT_FINISH_TDD_EVIDENCE="$tdd_evidence_result_file" \
  AGENT_FINISH_ACCEPTANCE_EVIDENCE="$acceptance_result_file" \
  AGENT_FINISH_REVIEW_EVIDENCE="$review_result_file" \
  AGENT_FINISH_SUBAGENT_EVIDENCE="$subagent_evidence_result_file" \
  AGENT_FINISH_VERIFY_EVIDENCE="$verify_result_file" \
  AGENT_FINISH_RESOURCE_EVIDENCE="$resource_result_file" \
  AGENT_FINISH_MARKDOWN_SUMMARY="$summary_file" \
  AGENT_FINISH_CHANGED_FILES="$changed_files_file" \
  AGENT_FINISH_DIFF_STAT="$diff_stat_file" \
  "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

env = os.environ

data = {
    "timestamp": env["AGENT_FINISH_TIMESTAMP"],
    "mode": env["AGENT_FINISH_MODE"],
    "command": f"scripts/agent-finish.sh {env['AGENT_FINISH_MODE_ARG']}",
    "run_dir": env["AGENT_FINISH_RUN_DIR"],
    "overall_result": env["AGENT_FINISH_OVERALL_RESULT"],
    "elapsed_seconds": int(env["AGENT_FINISH_ELAPSED_SECONDS"]),
    "resource_envelope_status": int(env["AGENT_FINISH_RESOURCE_STATUS"]),
    "gates": [
        {
            "name": "check-agent-md",
            "exit_status": int(env["AGENT_FINISH_CHECK_AGENT_MD_STATUS"]),
            "evidence": env["AGENT_FINISH_CHECK_AGENT_MD_EVIDENCE"],
        },
        {
            "name": "check-scope",
            "exit_status": int(env["AGENT_FINISH_SCOPE_STATUS"]),
            "evidence": env["AGENT_FINISH_SCOPE_EVIDENCE"],
        },
        {
            "name": "check-policy",
            "exit_status": int(env["AGENT_FINISH_POLICY_STATUS"]),
            "evidence": env["AGENT_FINISH_POLICY_EVIDENCE"],
        },
        {
            "name": "check-tdd-evidence",
            "exit_status": int(env["AGENT_FINISH_TDD_EVIDENCE_STATUS"]),
            "evidence": env["AGENT_FINISH_TDD_EVIDENCE"],
        },
        {
            "name": "check-acceptance",
            "exit_status": int(env["AGENT_FINISH_ACCEPTANCE_STATUS"]),
            "evidence": env["AGENT_FINISH_ACCEPTANCE_EVIDENCE"],
        },
        {
            "name": "check-review-evidence",
            "exit_status": int(env["AGENT_FINISH_REVIEW_STATUS"]),
            "evidence": env["AGENT_FINISH_REVIEW_EVIDENCE"],
        },
        {
            "name": "check-subagent-evidence",
            "exit_status": int(env["AGENT_FINISH_SUBAGENT_EVIDENCE_STATUS"]),
            "evidence": env["AGENT_FINISH_SUBAGENT_EVIDENCE"],
        },
        {
            "name": "agent-verify",
            "exit_status": int(env["AGENT_FINISH_VERIFY_STATUS"]),
            "evidence": env["AGENT_FINISH_VERIFY_EVIDENCE"],
        },
        {
            "name": "resource-envelope",
            "exit_status": int(env["AGENT_FINISH_RESOURCE_STATUS"]),
            "evidence": env["AGENT_FINISH_RESOURCE_EVIDENCE"],
        },
    ],
    "evidence": {
        "markdown_summary": env["AGENT_FINISH_MARKDOWN_SUMMARY"],
        "changed_files": env["AGENT_FINISH_CHANGED_FILES"],
        "diff_stat": env["AGENT_FINISH_DIFF_STAT"],
    },
}

Path(env["SUMMARY_JSON_FILE"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
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
  run_gate "check-tdd-evidence" "$tdd_evidence_result_file" bash scripts/check-tdd-evidence.sh
  tdd_evidence_status="$last_status"
  run_gate "check-acceptance" "$acceptance_result_file" bash scripts/check-acceptance.sh
  acceptance_status="$last_status"
  run_gate "check-review-evidence" "$review_result_file" bash scripts/check-review-evidence.sh
  review_status="$last_status"
  run_gate "check-subagent-evidence" "$subagent_evidence_result_file" bash scripts/check-subagent-evidence.sh
  subagent_evidence_status="$last_status"
  run_gate "agent-verify" "$verify_result_file" bash scripts/agent-verify.sh --strict
  verify_status="$last_status"
else
  run_gate "check-agent-md" "$check_agent_md_result_file" bash scripts/check-agent-md.sh agent.md
  agent_md_status="$last_status"
  run_gate "check-scope" "$scope_result_file" bash scripts/check-scope.sh --warn
  scope_status="$last_status"
  run_gate "check-policy" "$policy_result_file" bash scripts/check-policy.sh --warn
  policy_status="$last_status"
  run_gate "check-tdd-evidence" "$tdd_evidence_result_file" bash scripts/check-tdd-evidence.sh
  tdd_evidence_status="$last_status"
  run_gate "check-acceptance" "$acceptance_result_file" bash scripts/check-acceptance.sh
  acceptance_status="$last_status"
  run_gate "check-review-evidence" "$review_result_file" bash scripts/check-review-evidence.sh
  review_status="$last_status"
  run_gate "check-subagent-evidence" "$subagent_evidence_result_file" bash scripts/check-subagent-evidence.sh
  subagent_evidence_status="$last_status"
  run_gate "agent-verify" "$verify_result_file" bash scripts/agent-verify.sh --best-effort
  verify_status="$last_status"
fi

write_git_evidence

if [ "$failures" -gt 0 ]; then
  write_summary "fail"
  write_json_summary "fail"
  echo "AGENT_FINISH_RESULT=fail"
  echo "Agent finish gates failed."
  echo "Run directory: $run_dir"
  echo "Summary: $summary_file"
  exit 1
fi

write_summary "pass"
write_json_summary "pass"

echo "AGENT_FINISH_RESULT=pass"
echo "Agent finish gates passed."
echo "Run directory: $run_dir"
echo "Summary: $summary_file"
