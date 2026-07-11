#!/usr/bin/env bash
set -euo pipefail

finish_gate_status_value() {
  local index="$1"

  if [ -n "${FINISH_GATE_STATUSES[$index]:-}" ]; then
    printf '%s\n' "${FINISH_GATE_STATUSES[$index]}"
  else
    printf '%s\n' 0
  fi
}

finish_gate_evidence_path() {
  local index="$1"

  printf '%s\n' "$run_dir/${FINISH_GATE_RESULT_NAMES[$index]}"
}

finish_write_markdown_summary() {
  local overall_result="$1"
  local next_action
  local temp_summary
  local group
  local index
  local gate_status
  local gate_evidence

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
    for group in \
      "Core Guardrails" \
      "Optional Evidence" \
      "Verification And Limits"
    do
      echo "### $group"
      echo
      echo "| Check | Exit status | Evidence |"
      echo "| --- | ---: | --- |"
      for index in "${!FINISH_GATE_IDS[@]}"; do
        [ "${FINISH_GATE_GROUPS[$index]}" = "$group" ] || continue
        gate_status="$(finish_gate_status_value "$index")"
        gate_evidence="$(finish_gate_evidence_path "$index")"
        echo "| ${FINISH_GATE_IDS[$index]} | $gate_status | $gate_evidence |"
      done
      echo
    done
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
  local index
  local gate_names=""
  local gate_statuses=""
  local gate_evidence=""
  local status_value

  end_epoch="$(date -u +%s)"
  elapsed_seconds=$((end_epoch - start_epoch))
  temp_summary_json="$(harness_make_temp_file "$run_dir" finish-summary-json)"

  for index in "${!FINISH_GATE_IDS[@]}"; do
    status_value="$(finish_gate_status_value "$index")"
    gate_names="${gate_names}${gate_names:+
}${FINISH_GATE_IDS[$index]}"
    gate_statuses="${gate_statuses}${gate_statuses:+
}$status_value"
    gate_evidence="${gate_evidence}${gate_evidence:+
}$(finish_gate_evidence_path "$index")"
  done

  if ! SUMMARY_JSON_FILE="$temp_summary_json" \
    AGENT_FINISH_TIMESTAMP="$timestamp" \
    AGENT_FINISH_MODE="$mode" \
    AGENT_FINISH_MODE_ARG="$mode_arg" \
    AGENT_FINISH_RUN_DIR="$run_dir" \
    AGENT_FINISH_OVERALL_RESULT="$overall_result" \
    AGENT_FINISH_ELAPSED_SECONDS="$elapsed_seconds" \
    AGENT_FINISH_RESOURCE_STATUS="${resource_status:-0}" \
    AGENT_FINISH_GATE_NAMES="$gate_names" \
    AGENT_FINISH_GATE_STATUSES="$gate_statuses" \
    AGENT_FINISH_GATE_EVIDENCE="$gate_evidence" \
    AGENT_FINISH_MARKDOWN_SUMMARY="$summary_file" \
    AGENT_FINISH_CHANGED_FILES="$changed_files_file" \
    AGENT_FINISH_DIFF_STAT="$diff_stat_file" \
    "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

env = os.environ
gate_names = env["AGENT_FINISH_GATE_NAMES"].splitlines()
gate_statuses = env["AGENT_FINISH_GATE_STATUSES"].splitlines()
gate_evidence = env["AGENT_FINISH_GATE_EVIDENCE"].splitlines()

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
            "name": name,
            "exit_status": int(status),
            "evidence": evidence,
        }
        for name, status, evidence in zip(gate_names, gate_statuses, gate_evidence)
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
