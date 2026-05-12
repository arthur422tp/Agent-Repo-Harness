#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-policy.sh [--warn|--strict] [POLICY_FILE]

Modes:
  --warn    Default. Print high-risk matches but exit 0.
  --strict  Exit 1 on high-risk matches unless approval is detected.
  -h, --help
            Show this help text.

Approval for strict mode:
  AGENT_APPROVED_HIGH_RISK=1
  .agent/approvals/high-risk-approved
EOF
}

mode="warn"
policy_file=".agent/policy.yml"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --warn)
      mode="warn"
      ;;
    --strict)
      mode="strict"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ "$policy_file" != ".agent/policy.yml" ]; then
        echo "ERROR: multiple policy files provided"
        usage
        exit 2
      fi
      policy_file="$1"
      ;;
  esac
  shift
done

if [ ! -f "$policy_file" ]; then
  echo "SKIP: policy file not found at $policy_file"
  exit 0
fi

list_changed_files() {
  {
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | awk 'NF' | sort -u
}

approval_detected=0
approval_source=""

detect_approval() {
  if [ "${AGENT_APPROVED_HIGH_RISK:-}" = "1" ]; then
    approval_detected=1
    approval_source="environment"
    return 0
  fi

  if [ -f ".agent/approvals/high-risk-approved" ]; then
    approval_detected=1
    approval_source="file"
    return 0
  fi
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

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for policy config reads"
  exit 1
fi

if ! parse_output="$("$python_bin" "$reader" "$policy_file" 2>&1)"; then
  echo "ERROR: could not parse $policy_file"
  printf '%s\n' "$parse_output"
  exit 1
fi

read_policy_value() {
  local path="$1"
  local output

  if output="$("$python_bin" "$reader" "$policy_file" "$path" --optional 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: could not read $path from $policy_file" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_policy_list() {
  local path="$1"
  local raw
  local output

  raw="$(read_policy_value "$path")"
  case "$raw" in
    ""|null|"{}")
      return 0
      ;;
  esac

  if output="$(printf '%s\n' "$raw" | "$python_bin" -c '
import json
import sys

value = json.load(sys.stdin)
if not isinstance(value, list):
    raise SystemExit("expected list")
for item in value:
    if item is None:
        continue
    print(item)
' 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: $policy_file $path must be a list, empty map, null, or missing" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_policy_list_into() {
  local target="$1"
  local path="$2"
  local tmp_file
  local output

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/agent-policy-patterns.XXXXXX")"
  if ! read_policy_list "$path" >"$tmp_file"; then
    rm -f "$tmp_file"
    exit 1
  fi
  output="$(cat "$tmp_file")"
  rm -f "$tmp_file"
  printf -v "$target" '%s' "$output"
}

policy_high_patterns=""
policy_legacy_patterns=""
read_policy_list_into policy_high_patterns risk_files.high
read_policy_list_into policy_legacy_patterns high_risk_patterns
policy_patterns="$(
  printf '%s\n%s\n' "$policy_high_patterns" "$policy_legacy_patterns" | awk 'NF'
)"

changed_files="$(list_changed_files)"

if [ -z "$changed_files" ]; then
  echo "No changed files detected."
  exit 0
fi

echo "== Policy Gate =="
echo "Policy file: $policy_file"
echo "Mode: $mode"

matched=0
while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [[ "$file" == $pattern ]]; then
      if [ "$matched" -eq 0 ]; then
        echo
        echo "Warnings:"
      fi
      matched=1
      echo "- $file matches policy pattern $pattern"
    fi
  done <<EOF
$changed_files
EOF
done <<EOF
$policy_patterns
EOF

if [ "$matched" -eq 0 ]; then
  echo "No policy warnings."
  exit 0
fi

echo
echo "High-risk changes detected."
detect_approval

if [ "$approval_detected" -eq 1 ]; then
  case "$approval_source" in
    environment)
      echo "High-risk approval detected from environment."
      ;;
    file)
      echo "High-risk approval detected from .agent/approvals/high-risk-approved."
      ;;
  esac
fi

if [ "$mode" = "strict" ]; then
  if [ "$approval_detected" -eq 1 ]; then
    echo "Strict policy gate passed with approval."
    exit 0
  fi

  echo "Strict policy gate failed."
  echo "Action: set AGENT_APPROVED_HIGH_RISK=1 or create .agent/approvals/high-risk-approved if this change is explicitly approved."
  exit 1
fi

echo "Review recommended before claiming completion."
