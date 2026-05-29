#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-handoff.sh [HANDOFF_FILE]

Default:
  HANDOFF_FILE  .agent/handoff.yml

Performs dependency-light structural checks through scripts/lib/read-yaml.py.
This validator is standalone and is not part of agent-finish.sh yet.
EOF
}

handoff_file="${1:-.agent/handoff.yml}"

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
parsed_file=""

cleanup() {
  if [ -n "$parsed_file" ] && [ -f "$parsed_file" ]; then
    rm -f "$parsed_file"
  fi
}

trap cleanup EXIT

echo "== Handoff Validation =="
echo "Handoff file: $handoff_file"

if [ ! -f "$handoff_file" ]; then
  fail "handoff file does not exist: $handoff_file"
fi

if ! python_bin="$(find_python)"; then
  fail "python is required for validation"
fi

if [ "$failures" -eq 0 ]; then
  parsed_file="$(mktemp "${TMPDIR:-/tmp}/handoff-validation.XXXXXX")"
  if ! "$python_bin" "$reader" "$handoff_file" >"$parsed_file" 2>&1; then
    fail "could not parse handoff file with scripts/lib/read-yaml.py"
    cat "$parsed_file"
  fi
fi

if [ "$failures" -eq 0 ]; then
  "$python_bin" - "$parsed_file" <<'PY' || failures=$((failures + 1))
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
failures = []

if not isinstance(data, dict):
    failures.append("handoff root must be a map")
else:
    for field in ("current_task", "current_state", "changed_files", "verification"):
        if field not in data:
            failures.append(f"missing required field: {field}")

    changed_files = data.get("changed_files")
    if "changed_files" in data and not isinstance(changed_files, list):
        failures.append("changed_files must be a list")

    verification = data.get("verification")
    if "verification" in data and not isinstance(verification, list):
        failures.append("verification must be a list")
    elif isinstance(verification, list):
        for index, item in enumerate(verification):
            if not isinstance(item, dict):
                failures.append(f"verification[{index}] must be a map")
                continue
            command = item.get("command")
            result = item.get("result")
            if not isinstance(command, str) or not command.strip():
                failures.append(f"verification[{index}].command must be non-empty")
            if not isinstance(result, str) or not result.strip():
                failures.append(f"verification[{index}].result must be non-empty")

for failure in failures:
    print(f"FAIL: {failure}")

sys.exit(1 if failures else 0)
PY
fi

if [ "$failures" -gt 0 ]; then
  echo "HANDOFF_RESULT=fail"
  exit 1
fi

echo "HANDOFF_RESULT=pass"
