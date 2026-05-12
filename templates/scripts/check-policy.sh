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
  Preferred:
    .agent/approvals/high-risk-approved.yml
  Legacy compatibility:
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

read_yaml_value() {
  local yaml_file="$1"
  local path="$2"
  local output

  if output="$("$python_bin" "$reader" "$yaml_file" "$path" --optional 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: could not read $path from $yaml_file" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_yaml_list() {
  local yaml_file="$1"
  local path="$2"
  local raw
  local output

  raw="$(read_yaml_value "$yaml_file" "$path")"
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

  echo "ERROR: $yaml_file $path must be a list, empty map, null, or missing" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_policy_value() {
  read_yaml_value "$policy_file" "$1"
}

read_policy_list() {
  read_yaml_list "$policy_file" "$1"
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

structured_approval_file=".agent/approvals/high-risk-approved.yml"

fail_structured_approval() {
  echo "$1"
  return 1
}

read_approval_scalar_required() {
  local path="$1"
  local label="$2"
  local value

  value="$(read_yaml_value "$structured_approval_file" "$path")"
  if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "{}" ]; then
    fail_structured_approval "ERROR: structured high-risk approval requires $label."
    return 1
  fi
  return 0
}

read_approval_paths() {
  local output

  if ! output="$(read_yaml_list "$structured_approval_file" "approval.approved_paths" 2>&1)"; then
    printf '%s\n' "$output"
    return 1
  fi
  if [ -z "$output" ]; then
    fail_structured_approval "ERROR: structured high-risk approval requires non-empty approval.approved_paths."
    return 1
  fi
  printf '%s\n' "$output"
}

validate_structured_approval() {
  local approval_paths
  local high_risk_file
  local approved_pattern
  local covered

  if ! "$python_bin" "$reader" "$structured_approval_file" >/dev/null 2>&1; then
    echo "ERROR: could not parse $structured_approval_file"
    "$python_bin" "$reader" "$structured_approval_file" || true
    return 1
  fi

  read_approval_scalar_required "approval.approved_by" "approval.approved_by" || return 1
  read_approval_scalar_required "approval.reason" "approval.reason" || return 1

  if ! approval_paths="$(read_approval_paths)"; then
    printf '%s\n' "$approval_paths"
    return 1
  fi

  while IFS= read -r approved_pattern; do
    if [ -z "$approved_pattern" ] || [ "$approved_pattern" = "null" ] || [ "$approved_pattern" = "{}" ]; then
      fail_structured_approval "ERROR: structured high-risk approval contains an empty approved path."
      return 1
    fi
  done <<EOF
$approval_paths
EOF

  while IFS= read -r high_risk_file; do
    [ -n "$high_risk_file" ] || continue
    covered=0
    while IFS= read -r approved_pattern; do
      [ -n "$approved_pattern" ] || continue
      if [[ "$high_risk_file" == $approved_pattern ]]; then
        covered=1
        break
      fi
    done <<EOF
$approval_paths
EOF
    if [ "$covered" -ne 1 ]; then
      fail_structured_approval "ERROR: structured high-risk approval does not cover $high_risk_file."
      return 1
    fi
  done <"$matched_files_file"

  return 0
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

matched_files_file="$(mktemp "${TMPDIR:-/tmp}/agent-policy-matched.XXXXXX")"
cleanup() {
  rm -f "$matched_files_file" "$matched_files_file.sorted"
}
trap cleanup EXIT

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
      printf '%s\n' "$file" >>"$matched_files_file"
    fi
  done <<EOF
$changed_files
EOF
done <<EOF
$policy_patterns
EOF

if [ -s "$matched_files_file" ]; then
  sort -u "$matched_files_file" >"$matched_files_file.sorted"
  mv "$matched_files_file.sorted" "$matched_files_file"
fi

if [ "$matched" -eq 0 ]; then
  echo "No policy warnings."
  exit 0
fi

echo
echo "High-risk changes detected."

if [ "$mode" != "strict" ]; then
  echo "Review recommended before claiming completion."
  exit 0
fi

structured_approval_detected=0

if [ -f "$structured_approval_file" ]; then
  structured_approval_detected=1
  if validate_structured_approval; then
    approval_detected=1
    approval_source="structured"
  else
    approval_detected=0
    approval_source=""
  fi
else
  detect_approval
fi

if [ "$approval_detected" -eq 1 ]; then
  case "$approval_source" in
    structured)
      echo "High-risk approval detected from .agent/approvals/high-risk-approved.yml."
      ;;
    environment)
      echo "WARN: legacy high-risk approval from environment is accepted but structured approval is recommended."
      echo "High-risk approval detected from environment."
      ;;
    file)
      echo "WARN: legacy high-risk approval file is accepted but structured approval is recommended."
      echo "High-risk approval detected from .agent/approvals/high-risk-approved."
      ;;
  esac
fi

if [ "$approval_detected" -eq 1 ]; then
  case "$approval_source" in
    structured)
      echo "Strict policy gate passed with structured approval."
      ;;
    environment|file)
      echo "Strict policy gate passed with legacy approval."
      ;;
  esac
  exit 0
fi

echo "Strict policy gate failed."
if [ "$structured_approval_detected" -eq 1 ]; then
  printf '%s%s\n' \
    "Action: fix .agent/approvals/high-risk-approved.yml or remove it and use " \
    "a legacy approval only for compatibility."
else
  printf '%s%s\n' \
    "Action: create .agent/approvals/high-risk-approved.yml after explicit human approval, " \
    "or use AGENT_APPROVED_HIGH_RISK=1 / .agent/approvals/high-risk-approved for legacy compatibility."
fi
exit 1
