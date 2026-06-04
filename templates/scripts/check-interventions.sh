#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-interventions.sh [TASK_FILE] [INTERVENTIONS_FILE]

Defaults:
  TASK_FILE            .agent/task.yml
  INTERVENTIONS_FILE   .agent/interventions.yml

Requires structured intervention evidence only when TASK_FILE contains:
  task.completion.requires_intervention_record: true
EOF
}

task_file=".agent/task.yml"
interventions_file=".agent/interventions.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    interventions_file="${2:-$interventions_file}"
    ;;
esac

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"
failures=0

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

echo "== Intervention Record Gate =="
echo "Task file: $task_file"
echo "Intervention file: $interventions_file"

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for intervention checks"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

if [ ! -f "$task_file" ]; then
  echo "Intervention record is not required."
  echo "INTERVENTIONS_RESULT=pass"
  exit 0
fi

required="$(read_optional_value "$task_file" "task.completion.requires_intervention_record")"
if [ "$required" != "true" ]; then
  echo "Intervention record is not required."
  echo "INTERVENTIONS_RESULT=pass"
  exit 0
fi

echo "Intervention record is required."

if [ ! -f "$interventions_file" ]; then
  echo "ERROR: missing $interventions_file"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

entries_json="$(read_optional_value "$interventions_file" "interventions.entries")"
if [ -z "$entries_json" ] || [ "$entries_json" = "null" ]; then
  echo "ERROR: interventions.entries must contain at least one entry"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

set +e
INTERVENTIONS_JSON="$entries_json" "$python_bin" - <<'PY'
import json
import os
import sys

entries = json.loads(os.environ["INTERVENTIONS_JSON"])
if not isinstance(entries, list) or not entries:
    print("ERROR: interventions.entries must contain at least one entry")
    sys.exit(1)

allowed = {
    "approval",
    "scope_change",
    "blocker_resolution",
    "manual_verification",
    "runtime_override",
}
failures = 0
for index, entry in enumerate(entries):
    entry_failures = 0
    if not isinstance(entry, dict):
        print(f"ERROR: entries[{index}] must be a map")
        failures += 1
        continue
    for key in ("timestamp", "actor", "type", "summary"):
        if not str(entry.get(key, "")).strip():
            print(f"ERROR: entries[{index}].{key} must be non-empty")
            failures += 1
            entry_failures += 1
    intervention_type = entry.get("type")
    if intervention_type and intervention_type not in allowed:
        print(f"ERROR: entries[{index}].type has unsupported value: {intervention_type}")
        failures += 1
        entry_failures += 1
    if entry_failures == 0:
        print(f"OK: intervention {index}")

sys.exit(1 if failures else 0)
PY
status=$?
set -e

if [ "$status" -ne 0 ]; then
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

echo "INTERVENTIONS_RESULT=pass"
