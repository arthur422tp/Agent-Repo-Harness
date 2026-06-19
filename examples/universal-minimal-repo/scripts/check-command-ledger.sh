#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-command-ledger.sh [TASK_FILE] [COMMAND_RUNS_DIR]

Defaults:
  TASK_FILE         .agent/task.yml
  COMMAND_RUNS_DIR  .agent/command-runs

Requires command ledger evidence only when TASK_FILE contains:
  task.completion.requires_command_ledger: true
EOF
}

task_file=".agent/task.yml"
command_runs_dir=".agent/command-runs"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    command_runs_dir="${2:-$command_runs_dir}"
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

fail() {
  echo "FAIL: $1"
  echo "COMMAND_LEDGER_RESULT=fail"
  exit 1
}

echo "== Command Ledger Gate =="
echo "Task file: $task_file"
echo "Command runs directory: $command_runs_dir"

if [ ! -f "$task_file" ]; then
  echo "Command ledger evidence is not required."
  echo "COMMAND_LEDGER_RESULT=pass"
  exit 0
fi

if [ ! -f "$reader" ]; then
  fail "YAML reader not found: $reader"
fi

if ! python_bin="$(find_python)"; then
  fail "python is required for command ledger validation"
fi

set +e
requires_command_ledger="$("$python_bin" "$reader" "$task_file" \
  "task.completion.requires_command_ledger" --optional 2>&1)"
reader_status=$?
set -e
if [ "$reader_status" -ne 0 ]; then
  printf '%s\n' "$requires_command_ledger" >&2
  fail "could not read task completion flag from $task_file"
fi

if [ "$requires_command_ledger" != "true" ]; then
  echo "Command ledger evidence is not required."
  echo "COMMAND_LEDGER_RESULT=pass"
  exit 0
fi

echo "Command ledger evidence is required."

set +e
"$python_bin" - "$command_runs_dir" <<'PY'
import json
import sys
from pathlib import Path

command_runs_dir = Path(sys.argv[1])
summary_paths = sorted(command_runs_dir.glob("*/command-summary.json"))
required_top_keys = {
    "timestamp",
    "command",
    "cwd",
    "exit_status",
    "overall_result",
    "evidence",
}
required_evidence_keys = ("command", "cwd", "stdout", "stderr", "exit_status")
failures = 0


def fail(message):
    global failures
    print(f"FAIL: {message}")
    failures += 1


if not summary_paths:
    fail("no command ledger evidence found")

for summary_path in summary_paths:
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"could not parse {summary_path}: {exc}")
        continue

    summary_failures = failures
    if not isinstance(data, dict):
        fail(f"command summary must be a map: {summary_path}")
        continue

    missing_keys = sorted(required_top_keys - set(data))
    if missing_keys:
        fail(f"command summary missing required keys {', '.join(missing_keys)}: {summary_path}")

    for key in ("timestamp", "command", "cwd"):
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            fail(f"command summary {key} must be a non-empty string: {summary_path}")

    exit_status = data.get("exit_status")
    if isinstance(exit_status, bool) or not isinstance(exit_status, int):
        fail(f"command summary exit_status must be an integer: {summary_path}")

    if data.get("overall_result") not in {"pass", "fail"}:
        fail(f"command summary overall_result must be pass or fail: {summary_path}")

    evidence = data.get("evidence")
    if not isinstance(evidence, dict):
        fail(f"command summary evidence must be a map: {summary_path}")
    else:
        for key in required_evidence_keys:
            evidence_path = evidence.get(key)
            if not isinstance(evidence_path, str) or not evidence_path.strip():
                fail(f"command summary evidence.{key} must be a non-empty string: {summary_path}")
            elif not Path(evidence_path).is_file():
                fail(f"missing evidence file {evidence_path}: {summary_path}")

    if failures == summary_failures:
        print(f"OK: command summary {summary_path}")

if failures:
    print("COMMAND_LEDGER_RESULT=fail")
    sys.exit(1)

print("COMMAND_LEDGER_RESULT=pass")
PY
status=$?
set -e

exit "$status"
