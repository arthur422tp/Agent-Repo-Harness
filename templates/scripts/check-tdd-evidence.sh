#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-tdd-evidence.sh [TASK_FILE] [TDD_EVIDENCE_FILE]

Defaults:
  TASK_FILE           .agent/task.yml
  TDD_EVIDENCE_FILE   .agent/tdd-evidence.yml

Requires lightweight structured TDD evidence only when TASK_FILE contains:
  requires_tdd_evidence: true
EOF
}

task_file=".agent/task.yml"
evidence_file=".agent/tdd-evidence.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    evidence_file="${2:-$evidence_file}"
    ;;
esac

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

trim_value() {
  sed \
    -e 's/[[:space:]]*#.*$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e 's/^"//' \
    -e 's/"$//'
}

requires_tdd_evidence() {
  [ -f "$task_file" ] && \
    grep -Eq '^[[:space:]]*requires_tdd_evidence:[[:space:]]*true([[:space:]]*#.*)?$' "$task_file"
}

extract_section_scalar() {
  local section="$1"
  local key="$2"

  awk -v section="$section" -v key="$key" '
    /^[^[:space:]][^:]*:/ {
      current=$0
      sub(/:.*/, "", current)
      in_section=(current == section)
      next
    }
    in_section && $0 ~ ("^[[:space:]]+" key ":[[:space:]]*") {
      line=$0
      sub("^[[:space:]]+" key ":[[:space:]]*", "", line)
      print line
      exit
    }
  ' "$evidence_file" | trim_value
}

extract_nonempty_test_entries() {
  awk '
    /^tests_added_or_changed:/ { in_list=1; next }
    /^[^[:space:]][^:]*:/ { in_list=0 }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^"/, "", line)
      gsub(/"$/, "", line)
      gsub(/^[[:space:]]+/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line != "") {
        print line
      }
    }
  ' "$evidence_file"
}

require_scalar() {
  local label="$1"
  local section="$2"
  local key="$3"
  local value

  value="$(extract_section_scalar "$section" "$key")"
  if [ -z "$value" ]; then
    fail "$label must be non-empty"
  else
    echo "OK: $label"
  fi
}

echo "== TDD Evidence Gate =="
echo "Task file: $task_file"
echo "Evidence file: $evidence_file"

if ! requires_tdd_evidence; then
  echo "TDD evidence is not required."
  echo "TDD_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "TDD evidence is required."

if [ ! -f "$evidence_file" ]; then
  fail "missing $evidence_file"
else
  require_scalar "red_phase.command" "red_phase" "command"
  require_scalar "red_phase.observed_failure" "red_phase" "observed_failure"
  require_scalar "green_phase.command" "green_phase" "command"
  require_scalar "green_phase.observed_pass" "green_phase" "observed_pass"

  if [ -z "$(extract_nonempty_test_entries)" ]; then
    fail "tests_added_or_changed must include at least one non-empty entry"
  else
    echo "OK: tests_added_or_changed"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "TDD_EVIDENCE_RESULT=fail"
  exit 1
fi

echo "TDD_EVIDENCE_RESULT=pass"
