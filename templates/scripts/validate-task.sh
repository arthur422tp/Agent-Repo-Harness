#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-task.sh [TASK_FILE]

Default:
  TASK_FILE  .agent/task.yml

Performs dependency-light structural checks through scripts/lib/read-yaml.py.
If ruby is available, also checks YAML syntax.
EOF
}

task_file="${1:-.agent/task.yml}"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

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

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"
python_bin=""

require_path() {
  local path="$1"
  local output

  if output="$("$python_bin" "$reader" "$task_file" "$path" 2>&1)"; then
    echo "OK: $task_file contains $path"
    return 0
  fi

  case "$output" in
    *"missing path:"*)
      fail "$task_file missing key: $path"
      ;;
    *)
      fail "$task_file could not read key: $path"
      printf '%s\n' "$output"
      ;;
  esac
}

read_value() {
  local path="$1"

  "$python_bin" "$reader" "$task_file" "$path" 2>&1
}

check_status_enum() {
  local value

  value="$(read_value "task.status")" || return 0
  case "$value" in
    not_started|in_progress|blocked|ready_for_review|complete)
      echo "OK: $task_file task.status is valid"
      ;;
    *)
      fail "$task_file task.status must be one of: not_started, in_progress, blocked, ready_for_review, complete"
      ;;
  esac
}

check_array_or_null() {
  local path="$1"
  local value

  value="$(read_value "$path")" || return 0
  case "$value" in
    null|\[*)
      echo "OK: $task_file $path is an array or null"
      ;;
    "{}")
      echo "OK: $task_file $path is an empty collection"
      ;;
    *)
      fail "$task_file $path must be an array or null"
      ;;
  esac
}

check_map() {
  local path="$1"
  local value

  value="$(read_value "$path")" || return 0
  case "$value" in
    \{*)
      echo "OK: $task_file $path is a map"
      ;;
    *)
      fail "$task_file $path must be a map"
      ;;
  esac
}

check_optional_boolean() {
  local path="$1"
  local value

  value="$("$python_bin" "$reader" "$task_file" "$path" --optional 2>&1)" || return 0
  if [ -z "$value" ]; then
    return 0
  fi

  case "$value" in
    true|false)
      echo "OK: $task_file $path is boolean"
      ;;
    *)
      fail "$task_file $path must be boolean"
      ;;
  esac
}

check_task_types() {
  check_status_enum
  check_array_or_null "task.allowed_paths"
  check_array_or_null "task.forbidden_paths"
  check_map "task.completion"

  for flag in \
    requires_tdd_evidence \
    requires_scope_check \
    requires_policy_check \
    requires_verification \
    requires_handoff_update \
    requires_acceptance_check \
    requires_review_evidence \
    requires_subagent_evidence \
    requires_doc_freshness_check
  do
    check_optional_boolean "task.completion.$flag"
  done
}

echo "== Task State Validation =="

if [ ! -f "$task_file" ]; then
  fail "missing $task_file"
else
  if [ ! -f "$reader" ]; then
    fail "YAML reader not found: $reader"
  elif ! python_bin="$(find_python)"; then
    fail "python is required for task validation"
  else
    if parse_output="$("$python_bin" "$reader" "$task_file" 2>&1)"; then
      echo "OK: YAML parsed by shared reader"
      require_path "task"
      require_path "task.status"
      require_path "task.goal"
      require_path "task.allowed_paths"
      require_path "task.forbidden_paths"
      require_path "task.completion"
      check_task_types
    else
      fail "$task_file could not be parsed"
      printf '%s\n' "$parse_output"
    fi
  fi

  if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0))' "$task_file" >/dev/null
    echo "OK: YAML syntax"
  else
    echo "WARN: ruby unavailable; skipped YAML syntax check"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "TASK_VALIDATION_RESULT=fail"
  exit 1
fi

echo "TASK_VALIDATION_RESULT=pass"
