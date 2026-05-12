#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-review-evidence.sh [TASK_FILE] [REVIEW_FILE]

Defaults:
  TASK_FILE     .agent/task.yml
  REVIEW_FILE   .agent/review.yml

Requires structured review evidence only when TASK_FILE contains:
  task.completion.requires_review_evidence: true
EOF
}

task_file=".agent/task.yml"
review_file=".agent/review.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    review_file="${2:-$review_file}"
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
  echo "ERROR: python is required for review evidence validation"
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

echo "== Review Evidence Gate =="
echo "Task file: $task_file"
echo "Review file: $review_file"

if [ ! -f "$reader" ]; then
  echo "FAIL: YAML reader not found: $reader"
  echo "REVIEW_EVIDENCE_RESULT=fail"
  exit 1
fi

python_bin="$(find_python)"

if [ ! -f "$task_file" ]; then
  echo "Review evidence is not required."
  echo "REVIEW_EVIDENCE_RESULT=pass"
  exit 0
fi

requires_review="$(read_optional_value "$task_file" "task.completion.requires_review_evidence")"
if [ "$requires_review" != "true" ]; then
  echo "Review evidence is not required."
  echo "REVIEW_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "Review evidence is required."

if [ ! -f "$review_file" ]; then
  echo "FAIL: missing $review_file"
  echo "REVIEW_EVIDENCE_RESULT=fail"
  exit 1
fi

set +e
"$python_bin" - "$reader" "$review_file" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True

reader_path = Path(sys.argv[1])
review_path = Path(sys.argv[2])

spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

allowed_statuses = {
    "not_requested",
    "approved",
    "approved_with_comments",
    "changes_requested",
    "blocked",
}
blocking_statuses = {"not_requested", "changes_requested", "blocked"}
failures = 0


def fail(message):
    global failures
    print(f"FAIL: {message}")
    failures += 1


def nonempty(value):
    return isinstance(value, str) and value.strip() != ""


try:
    data = module.load_yaml_subset(review_path)
except Exception as exc:
    print(f"FAIL: could not parse {review_path}: {exc}")
    print("REVIEW_EVIDENCE_RESULT=fail")
    sys.exit(1)

review = data.get("review") if isinstance(data, dict) else None
if not isinstance(review, dict):
    fail("review must be a map")
else:
    if review.get("required") is not True:
        fail("review.required must be true when review evidence is required")

    status = review.get("status")
    if status not in allowed_statuses:
        fail("review.status must be one of: not_requested, approved, approved_with_comments, changes_requested, blocked")
    elif status in blocking_statuses:
        fail(f"review.status must not be {status}")

    if not nonempty(review.get("reviewer")):
        fail("review.reviewer must be non-empty")
    if not nonempty(review.get("evidence")):
        fail("review.evidence must be non-empty")

    concerns = review.get("concerns")
    if not isinstance(concerns, list):
        fail("review.concerns must be a list")
    else:
        for index, concern in enumerate(concerns, 1):
            if isinstance(concern, dict):
                concern_id = concern.get("id") or f"#{index}"
                if concern.get("blocking") is True:
                    fail(f"blocking concern {concern_id}")
            elif isinstance(concern, str):
                continue
            else:
                fail(f"review.concerns item #{index} must be a map or string")

if failures:
    print("REVIEW_EVIDENCE_RESULT=fail")
    sys.exit(1)

print("OK: review evidence")
print("REVIEW_EVIDENCE_RESULT=pass")
PY
status=$?
set -e

exit "$status"
