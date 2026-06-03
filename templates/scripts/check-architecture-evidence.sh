#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-architecture-evidence.sh [TASK_FILE] [ARCHITECTURE_FILE]

Defaults:
  TASK_FILE          .agent/task.yml
  ARCHITECTURE_FILE  .agent/architecture.yml

Requires structured architecture evidence only when TASK_FILE contains:
  task.completion.requires_architecture_evidence: true
EOF
}

task_file=".agent/task.yml"
architecture_file=".agent/architecture.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    architecture_file="${2:-$architecture_file}"
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

echo "== Architecture Evidence Gate =="
echo "Task file: $task_file"
echo "Architecture file: $architecture_file"

if [ ! -f "$task_file" ]; then
  echo "Architecture evidence is not required."
  echo "ARCHITECTURE_EVIDENCE_RESULT=pass"
  exit 0
fi

if [ ! -f "$reader" ]; then
  echo "FAIL: YAML reader not found: $reader"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "FAIL: python is required for architecture evidence validation"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

requires_architecture="$(read_optional_value "$task_file" "task.completion.requires_architecture_evidence")"
if [ "$requires_architecture" != "true" ]; then
  echo "Architecture evidence is not required."
  echo "ARCHITECTURE_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "Architecture evidence is required."

if [ ! -f "$architecture_file" ]; then
  echo "FAIL: missing $architecture_file"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

set +e
"$python_bin" - "$reader" "$architecture_file" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True

reader_path = Path(sys.argv[1])
architecture_path = Path(sys.argv[2])

spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

allowed_top_statuses = {"not_reviewed", "upheld", "upheld_with_concerns", "violated"}
passing_top_statuses = {"upheld", "upheld_with_concerns"}
passing_invariant_statuses = {"upheld", "upheld_with_concerns", "not_applicable"}
allowed_invariant_statuses = passing_invariant_statuses | {"not_reviewed", "violated"}
failures = 0


def fail(message):
    global failures
    print(f"FAIL: {message}")
    failures += 1


def nonempty(value):
    return isinstance(value, str) and value.strip() != ""


try:
    data = module.load_yaml_subset(architecture_path)
except Exception as exc:
    print(f"FAIL: could not parse {architecture_path}: {exc}")
    print("ARCHITECTURE_EVIDENCE_RESULT=fail")
    sys.exit(1)

architecture = data.get("architecture") if isinstance(data, dict) else None
if not isinstance(architecture, dict):
    fail("architecture must be a map")
else:
    status = architecture.get("status")
    if status not in allowed_top_statuses:
        fail("architecture.status must be one of: not_reviewed, upheld, upheld_with_concerns, violated")
    elif status not in passing_top_statuses:
        fail("architecture.status must be upheld or upheld_with_concerns")

    if not nonempty(architecture.get("reviewer")):
        fail("architecture.reviewer must be non-empty")
    if not nonempty(architecture.get("evidence")):
        fail("architecture.evidence must be non-empty")

    invariants = architecture.get("invariants")
    if not isinstance(invariants, list) or not invariants:
        fail("architecture.invariants must contain at least one invariant")
    else:
        for index, invariant in enumerate(invariants, 1):
            if not isinstance(invariant, dict):
                fail(f"architecture.invariants[{index}] must be a map")
                continue

            ident = invariant.get("id")
            label = ident if nonempty(ident) else f"#{index}"

            if not nonempty(ident):
                fail(f"architecture.invariants[{index}].id must be non-empty")
            if not nonempty(invariant.get("description")):
                fail(f"invariant {label} description must be non-empty")

            invariant_status = invariant.get("status")
            if invariant_status not in allowed_invariant_statuses:
                fail(
                    f"invariant {label} status must be one of: not_reviewed, upheld, upheld_with_concerns, violated, not_applicable"
                )
            elif invariant_status not in passing_invariant_statuses:
                fail(f"invariant {label} status must be upheld, upheld_with_concerns, or not_applicable")

            if not nonempty(invariant.get("evidence")):
                fail(f"invariant {label} evidence must be non-empty")

            if (
                nonempty(ident)
                and nonempty(invariant.get("description"))
                and invariant_status in passing_invariant_statuses
                and nonempty(invariant.get("evidence"))
            ):
                print(f"OK: invariant {ident}")

if failures:
    print("ARCHITECTURE_EVIDENCE_RESULT=fail")
    sys.exit(1)

print("ARCHITECTURE_EVIDENCE_RESULT=pass")
PY
status=$?
set -e

exit "$status"
