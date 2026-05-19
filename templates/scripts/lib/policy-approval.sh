#!/usr/bin/env bash
set -euo pipefail

structured_approval_file=".agent/approvals/high-risk-approved.yml"
legacy_approval_file=".agent/approvals/high-risk-approved"

fail_structured_approval() {
  echo "$1"
  return 1
}

detect_legacy_approval() {
  if [ "${AGENT_APPROVED_HIGH_RISK:-}" = "1" ]; then
    approval_detected=1
    approval_source="environment"
    return 0
  fi

  if [ -f "$legacy_approval_file" ]; then
    approval_detected=1
    approval_source="file"
    return 0
  fi

  approval_detected=0
  approval_source=""
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

detect_high_risk_approval() {
  structured_approval_detected=0

  if [ -f "$structured_approval_file" ]; then
    structured_approval_detected=1
    if validate_structured_approval; then
      approval_detected=1
      approval_source="structured"
      return 0
    fi

    approval_detected=0
    approval_source=""
    return 1
  fi

  detect_legacy_approval
}
