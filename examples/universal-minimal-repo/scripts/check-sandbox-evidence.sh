#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-sandbox-evidence.sh [TASK_FILE] [SANDBOX_RUNS_DIR]

Defaults:
  TASK_FILE          .agent/task.yml
  SANDBOX_RUNS_DIR   .agent/sandbox-runs

Requires passing sandbox evidence only when TASK_FILE contains:
  task.completion.requires_sandbox_verification: true
EOF
}

task_file=".agent/task.yml"
sandbox_runs_dir=".agent/sandbox-runs"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    sandbox_runs_dir="${2:-$sandbox_runs_dir}"
    ;;
esac

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

read_optional_value() {
  local file="$1"
  local path="$2"
  local output
  local status

  set +e
  output="$("$python_bin" "$reader" "$file" "$path" --optional 2>&1)"
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&2
    return "$status"
  fi
  printf '%s\n' "$output"
}

echo "== Sandbox Evidence Gate =="
echo "Task file: $task_file"
echo "Sandbox runs directory: $sandbox_runs_dir"

if [ ! -f "$task_file" ]; then
  echo "Sandbox verification is not required."
  echo "SANDBOX_EVIDENCE_RESULT=pass"
  exit 0
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for sandbox evidence checks"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

if ! required="$(read_optional_value "$task_file" "task.completion.requires_sandbox_verification")"; then
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

if [ "$required" != "true" ]; then
  echo "Sandbox verification is not required."
  echo "SANDBOX_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "Sandbox verification is required."

if [ ! -d "$sandbox_runs_dir" ]; then
  echo "ERROR: missing sandbox runs directory: $sandbox_runs_dir"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

summary_file="$(find "$sandbox_runs_dir" -type f -name sandbox-summary.json | sort | tail -n 1)"
if [ -z "$summary_file" ]; then
  echo "ERROR: no sandbox-summary.json files found under $sandbox_runs_dir"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

set +e
"$python_bin" - "$summary_file" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
try:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"ERROR: failed to parse sandbox summary: {exc}")
    sys.exit(1)

if data.get("overall_result") != "pass" or int(data.get("exit_status", 1)) != 0:
    print("ERROR: newest sandbox run did not pass")
    print(f"Summary: {summary_path}")
    sys.exit(1)

print("OK: sandbox verification evidence")
print(f"Summary: {summary_path}")
PY
status=$?
set -e

if [ "$status" -ne 0 ]; then
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

echo "SANDBOX_EVIDENCE_RESULT=pass"
