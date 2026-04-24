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

extract_patterns() {
  awk '
    /^high_risk_patterns:/ { in_list=1; next }
    /^risk_files:/ { in_risk=1; next }
    in_risk && /^[[:space:]]*high:/ { in_list=1; next }
    in_list && /^[^[:space:]-]/ { in_list=0 }
    in_risk && /^[^[:space:]]/ && $0 !~ /^risk_files:/ { in_risk=0 }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      print line
    }
  ' "$policy_file"
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
$(extract_patterns)
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
