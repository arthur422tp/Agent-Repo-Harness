#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-task.sh [TASK_FILE]

Default:
  TASK_FILE  .agent/task.yml

Performs dependency-light structural checks. If ruby is available, also checks
YAML syntax.
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

require_key() {
  local key="$1"
  if ! grep -Eq "^[[:space:]]*$key:" "$task_file"; then
    fail "$task_file missing key: $key"
  else
    echo "OK: $task_file contains $key"
  fi
}

echo "== Task State Validation =="

if [ ! -f "$task_file" ]; then
  fail "missing $task_file"
else
  require_key "task"
  require_key "status"
  require_key "goal"
  require_key "allowed_paths"
  require_key "forbidden_paths"
  require_key "completion"

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
