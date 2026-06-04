#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-failure-attribution.sh [TASK_FILE] [FAILURE_ATTRIBUTION_FILE]

Defaults:
  TASK_FILE                  .agent/task.yml
  FAILURE_ATTRIBUTION_FILE   .agent/failure-attribution.yml

Requires structured failure attribution only when TASK_FILE contains:
  task.completion.requires_failure_attribution: true
EOF
}

task_file=".agent/task.yml"
attribution_file=".agent/failure-attribution.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    attribution_file="${2:-$attribution_file}"
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

require_non_empty() {
  local path="$1"
  local label="$2"
  local value

  value="$(read_optional_value "$attribution_file" "$path")"
  if [ -z "$value" ]; then
    echo "ERROR: $label must be non-empty"
    failures=$((failures + 1))
  else
    echo "OK: $label"
  fi
}

echo "== Failure Attribution Gate =="
echo "Task file: $task_file"
echo "Failure attribution file: $attribution_file"

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for failure attribution checks"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

if [ ! -f "$task_file" ]; then
  echo "Failure attribution is not required."
  echo "FAILURE_ATTRIBUTION_RESULT=pass"
  exit 0
fi

required="$(read_optional_value "$task_file" "task.completion.requires_failure_attribution")"
if [ "$required" != "true" ]; then
  echo "Failure attribution is not required."
  echo "FAILURE_ATTRIBUTION_RESULT=pass"
  exit 0
fi

echo "Failure attribution is required."

if [ ! -f "$attribution_file" ]; then
  echo "ERROR: missing $attribution_file"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

status="$(read_optional_value "$attribution_file" "failure_attribution.status")"
case "$status" in
  complete|complete_with_concerns)
    echo "OK: failure attribution status"
    ;;
  *)
    echo "ERROR: failure_attribution.status must be complete or complete_with_concerns"
    failures=$((failures + 1))
    ;;
esac

require_non_empty "failure_attribution.root_cause" "root_cause"
require_non_empty "failure_attribution.evidence" "evidence"
require_non_empty "failure_attribution.repair" "repair"

if [ "$failures" -gt 0 ]; then
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

echo "OK: failure attribution"
echo "FAILURE_ATTRIBUTION_RESULT=pass"
