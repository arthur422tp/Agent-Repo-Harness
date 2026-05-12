#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-acceptance.sh [TASK_FILE] [ACCEPTANCE_FILE]

Defaults:
  TASK_FILE         .agent/task.yml
  ACCEPTANCE_FILE   .agent/acceptance.yml

Requires structured acceptance evidence only when TASK_FILE contains:
  task.completion.requires_acceptance_check: true
EOF
}

task_file=".agent/task.yml"
acceptance_file=".agent/acceptance.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    acceptance_file="${2:-$acceptance_file}"
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
  echo "ERROR: python is required for acceptance validation"
  exit 1
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

echo "== Acceptance Gate =="
echo "Task file: $task_file"
echo "Acceptance file: $acceptance_file"

if [ ! -f "$reader" ]; then
  echo "FAIL: YAML reader not found: $reader"
  echo "ACCEPTANCE_RESULT=fail"
  exit 1
fi

python_bin="$(find_python)"

if [ ! -f "$task_file" ]; then
  echo "Acceptance check is not required."
  echo "ACCEPTANCE_RESULT=pass"
  exit 0
fi

requires_acceptance="$(read_optional_value "$task_file" "task.completion.requires_acceptance_check")"
if [ "$requires_acceptance" != "true" ]; then
  echo "Acceptance check is not required."
  echo "ACCEPTANCE_RESULT=pass"
  exit 0
fi

echo "Acceptance check is required."

if [ ! -f "$acceptance_file" ]; then
  echo "FAIL: missing $acceptance_file"
  echo "ACCEPTANCE_RESULT=fail"
  exit 1
fi

set +e
"$python_bin" - "$reader" "$acceptance_file" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True

reader_path = Path(sys.argv[1])
acceptance_path = Path(sys.argv[2])

spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

failures = 0


def fail(message):
    global failures
    print(f"FAIL: {message}")
    failures += 1


def nonempty(value):
    return isinstance(value, str) and value.strip() != ""


try:
    data = module.load_yaml_subset(acceptance_path)
except Exception as exc:
    print(f"FAIL: could not parse {acceptance_path}: {exc}")
    print("ACCEPTANCE_RESULT=fail")
    sys.exit(1)

acceptance = data.get("acceptance") if isinstance(data, dict) else None
criteria = acceptance.get("criteria") if isinstance(acceptance, dict) else None

if not isinstance(criteria, list) or not criteria:
    fail("acceptance.criteria must include at least one criterion")
else:
    seen_ids = set()
    for index, criterion in enumerate(criteria, 1):
        label = f"criterion #{index}"
        if not isinstance(criterion, dict):
            fail(f"{label} must be a map")
            continue

        criterion_id = criterion.get("id")
        if nonempty(criterion_id):
            label = f"criterion {criterion_id.strip()}"
            if criterion_id in seen_ids:
                fail(f"{label} id must be unique")
            seen_ids.add(criterion_id)
        else:
            fail(f"{label} id must be non-empty")

        if not nonempty(criterion.get("description")):
            fail(f"{label} description must be non-empty")
        if criterion.get("met") is not True:
            fail(f"{label} met must be true")
        if not (
            nonempty(criterion.get("evidence"))
            or nonempty(criterion.get("verification"))
        ):
            fail(f"{label} evidence or verification must be non-empty")

        if failures == 0 or (
            nonempty(criterion_id)
            and nonempty(criterion.get("description"))
            and criterion.get("met") is True
            and (
                nonempty(criterion.get("evidence"))
                or nonempty(criterion.get("verification"))
            )
        ):
            print(f"OK: {label}")

if failures:
    print("ACCEPTANCE_RESULT=fail")
    sys.exit(1)

print("ACCEPTANCE_RESULT=pass")
PY
status=$?
set -e

exit "$status"
