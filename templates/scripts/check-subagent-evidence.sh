#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-subagent-evidence.sh [TASK_FILE] [SUBAGENT_RUNS_DIR]

Defaults:
  TASK_FILE          .agent/task.yml
  SUBAGENT_RUNS_DIR  .agent/subagent-runs

Requires validated subagent run evidence only when TASK_FILE contains:
  task.completion.requires_subagent_evidence: true
EOF
}

task_file=".agent/task.yml"
subagent_runs_dir=".agent/subagent-runs"
validator="scripts/validate-subagent-run.sh"
failures=0
validated_runs=0

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    subagent_runs_dir="${2:-$subagent_runs_dir}"
    ;;
esac

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

requires_subagent_evidence() {
  [ -f "$task_file" ] && \
    grep -Eq '^[[:space:]]*requires_subagent_evidence:[[:space:]]*true([[:space:]]*#.*)?$' "$task_file"
}

echo "== Subagent Evidence Gate =="
echo "Task file: $task_file"
echo "Subagent runs directory: $subagent_runs_dir"

if ! requires_subagent_evidence; then
  echo "SKIP: Subagent evidence is not required."
  echo "SUBAGENT_EVIDENCE_RESULT=skip"
  exit 0
fi

echo "Subagent evidence is required."

if [ ! -d "$subagent_runs_dir" ]; then
  fail "no valid subagent run evidence found in $subagent_runs_dir (directory is missing)"
elif [ ! -f "$validator" ]; then
  fail "missing validator: $validator"
else
  while IFS= read -r run_dir; do
    if [ ! -f "$run_dir/packet.yml" ] || \
      [ ! -f "$run_dir/result.md" ] || \
      [ ! -f "$run_dir/status.txt" ]
    then
      continue
    fi

    echo "CHECK: $run_dir"
    if bash "$validator" "$run_dir"; then
      validated_runs=$((validated_runs + 1))
      echo "OK: validated subagent run: $run_dir"
    else
      echo "WARN: invalid subagent run: $run_dir"
    fi
  done < <(find "$subagent_runs_dir" -mindepth 1 -maxdepth 1 -type d | sort)

  if [ "$validated_runs" -lt 1 ]; then
    fail "no valid subagent run evidence found in $subagent_runs_dir"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "SUBAGENT_EVIDENCE_RESULT=fail"
  exit 1
fi

echo "SUBAGENT_EVIDENCE_RESULT=pass"
