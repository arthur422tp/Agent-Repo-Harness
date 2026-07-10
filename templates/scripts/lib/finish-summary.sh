#!/usr/bin/env bash
set -euo pipefail

finish_write_markdown_summary() {
  local overall_result="$1"
  local next_action
  local temp_summary

  if [ "$overall_result" = "pass" ]; then
    next_action="Update handoff.md with the run directory path, changed files, verification result, and the next action for the human or next agent."
  else
    next_action="Review the failing result files, fix the reported issues, then rerun scripts/agent-finish.sh $mode_arg."
  fi

  temp_summary="$(harness_make_temp_file "$run_dir" finish-summary-md)"
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
    echo "### Core Guardrails"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| check-agent-md | $agent_md_status | $check_agent_md_result_file |"
    echo "| check-scope | $scope_status | $scope_result_file |"
    echo "| check-policy | $policy_status | $policy_result_file |"
    echo
    echo "### Optional Evidence"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| check-tdd-evidence | $tdd_evidence_status | $tdd_evidence_result_file |"
    echo "| check-acceptance | $acceptance_status | $acceptance_result_file |"
    echo "| check-review-evidence | $review_status | $review_result_file |"
    echo "| check-architecture-evidence | $architecture_status | $architecture_result_file |"
    echo "| check-failure-attribution | $failure_attribution_status | $failure_attribution_result_file |"
    echo "| check-interventions | $interventions_status | $interventions_result_file |"
    echo "| check-command-ledger | $command_ledger_status | $command_ledger_result_file |"
    echo "| check-sandbox-evidence | $sandbox_evidence_status | $sandbox_evidence_result_file |"
    echo "| check-subagent-evidence | $subagent_evidence_status | $subagent_evidence_result_file |"
    echo
    echo "### Verification And Limits"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| validate-episode | $episode_status | $episode_result_file |"
    echo "| agent-verify | $verify_status | $verify_result_file |"
    echo "| resource-envelope | $resource_status | $resource_result_file |"
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
  } >"$temp_summary"
  harness_atomic_replace "$temp_summary" "$summary_file"
}

finish_write_json_summary() {
  local overall_result="$1"
  local end_epoch
  local temp_summary_json

  end_epoch="$(date -u +%s)"
  elapsed_seconds=$((end_epoch - start_epoch))
  temp_summary_json="$(harness_make_temp_file "$run_dir" finish-summary-json)"

  if ! SUMMARY_JSON_FILE="$temp_summary_json" \
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
    AGENT_FINISH_ARCHITECTURE_STATUS="${architecture_status:-0}" \
    AGENT_FINISH_FAILURE_ATTRIBUTION_STATUS="${failure_attribution_status:-0}" \
    AGENT_FINISH_INTERVENTIONS_STATUS="${interventions_status:-0}" \
    AGENT_FINISH_COMMAND_LEDGER_STATUS="${command_ledger_status:-0}" \
    AGENT_FINISH_SANDBOX_EVIDENCE_STATUS="${sandbox_evidence_status:-0}" \
    AGENT_FINISH_SUBAGENT_EVIDENCE_STATUS="${subagent_evidence_status:-0}" \
    AGENT_FINISH_EPISODE_STATUS="${episode_status:-0}" \
    AGENT_FINISH_VERIFY_STATUS="${verify_status:-0}" \
    AGENT_FINISH_CHECK_AGENT_MD_EVIDENCE="$check_agent_md_result_file" \
    AGENT_FINISH_SCOPE_EVIDENCE="$scope_result_file" \
    AGENT_FINISH_POLICY_EVIDENCE="$policy_result_file" \
    AGENT_FINISH_TDD_EVIDENCE="$tdd_evidence_result_file" \
    AGENT_FINISH_ACCEPTANCE_EVIDENCE="$acceptance_result_file" \
    AGENT_FINISH_REVIEW_EVIDENCE="$review_result_file" \
    AGENT_FINISH_ARCHITECTURE_EVIDENCE="$architecture_result_file" \
    AGENT_FINISH_FAILURE_ATTRIBUTION_EVIDENCE="$failure_attribution_result_file" \
    AGENT_FINISH_INTERVENTIONS_EVIDENCE="$interventions_result_file" \
    AGENT_FINISH_COMMAND_LEDGER_EVIDENCE="$command_ledger_result_file" \
    AGENT_FINISH_SANDBOX_EVIDENCE="$sandbox_evidence_result_file" \
    AGENT_FINISH_SUBAGENT_EVIDENCE="$subagent_evidence_result_file" \
    AGENT_FINISH_EPISODE_EVIDENCE="$episode_result_file" \
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
            "name": "check-architecture-evidence",
            "exit_status": int(env["AGENT_FINISH_ARCHITECTURE_STATUS"]),
            "evidence": env["AGENT_FINISH_ARCHITECTURE_EVIDENCE"],
        },
        {
            "name": "check-failure-attribution",
            "exit_status": int(env["AGENT_FINISH_FAILURE_ATTRIBUTION_STATUS"]),
            "evidence": env["AGENT_FINISH_FAILURE_ATTRIBUTION_EVIDENCE"],
        },
        {
            "name": "check-interventions",
            "exit_status": int(env["AGENT_FINISH_INTERVENTIONS_STATUS"]),
            "evidence": env["AGENT_FINISH_INTERVENTIONS_EVIDENCE"],
        },
        {
            "name": "check-command-ledger",
            "exit_status": int(env["AGENT_FINISH_COMMAND_LEDGER_STATUS"]),
            "evidence": env["AGENT_FINISH_COMMAND_LEDGER_EVIDENCE"],
        },
        {
            "name": "check-sandbox-evidence",
            "exit_status": int(env["AGENT_FINISH_SANDBOX_EVIDENCE_STATUS"]),
            "evidence": env["AGENT_FINISH_SANDBOX_EVIDENCE"],
        },
        {
            "name": "check-subagent-evidence",
            "exit_status": int(env["AGENT_FINISH_SUBAGENT_EVIDENCE_STATUS"]),
            "evidence": env["AGENT_FINISH_SUBAGENT_EVIDENCE"],
        },
        {
            "name": "validate-episode",
            "exit_status": int(env["AGENT_FINISH_EPISODE_STATUS"]),
            "evidence": env["AGENT_FINISH_EPISODE_EVIDENCE"],
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
  then
    return 1
  fi
  harness_atomic_replace "$temp_summary_json" "$summary_json_file"
}

finish_write_episode_summary() {
  local overall_result="$1"
  local temp_episode_summary

  temp_episode_summary="$(harness_make_temp_file "$run_dir" episode-summary-json)"
  if ! EPISODE_SUMMARY_JSON_FILE="$temp_episode_summary" \
    AGENT_FINISH_TIMESTAMP="$timestamp" \
    AGENT_FINISH_MODE="$mode" \
    AGENT_FINISH_RUN_DIR="$run_dir" \
    AGENT_FINISH_OVERALL_RESULT="$overall_result" \
    AGENT_FINISH_SUMMARY_JSON="$summary_json_file" \
    "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

data = {
    "timestamp": os.environ["AGENT_FINISH_TIMESTAMP"],
    "mode": os.environ["AGENT_FINISH_MODE"],
    "run_dir": os.environ["AGENT_FINISH_RUN_DIR"],
    "overall_result": os.environ["AGENT_FINISH_OVERALL_RESULT"],
    "finish_summary_json": os.environ["AGENT_FINISH_SUMMARY_JSON"],
    "contracts": {
        "task": ".agent/task.yml",
        "episode": ".agent/episode.yml",
        "policy": ".agent/policy.yml",
        "harness": ".agent/harness.yml"
    },
    "evidence": {
        "finish_summary": "finish-summary.md",
        "changed_files": "changed-files.txt",
        "diff_stat": "git-diff-stat.txt"
    }
}

Path(os.environ["EPISODE_SUMMARY_JSON_FILE"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  then
    return 1
  fi
  harness_atomic_replace "$temp_episode_summary" "$episode_summary_json_file"
}
