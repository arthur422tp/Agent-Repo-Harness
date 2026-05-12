#!/usr/bin/env bash
set -euo pipefail

echo "== Strict policy semantics =="
rm -rf "$policy_strict_root"
mkdir -p "$policy_strict_root/.agent" "$policy_strict_root/src/auth"
git init -q "$policy_strict_root"
(
  cd "$policy_strict_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' 'line one' > src/auth/login.js
  strict_log="$policy_strict_root/policy-strict.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$strict_log" 2>&1; then
    echo "ERROR: expected strict policy failure without approval"
    exit 1
  fi
  assert_contains "$strict_log" "Strict policy gate failed."

  strict_approved_log="$policy_strict_root/policy-strict-approved.log"
  AGENT_APPROVED_HIGH_RISK=1 bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$strict_approved_log" 2>&1
  assert_contains "$strict_approved_log" "High-risk approval detected from environment."
  assert_contains "$strict_approved_log" "Strict policy gate passed with approval."
)
pass "strict policy semantics"

echo
echo "== Policy gate warn-mode high-risk match =="
rm -rf "$policy_warn_root"
mkdir -p "$policy_warn_root/.agent" "$policy_warn_root/src/auth"
git init -q "$policy_warn_root"
(
  cd "$policy_warn_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' 'line one' > src/auth/login.js
  warn_log="$policy_warn_root/policy-warn.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --warn .agent/policy.yml >"$warn_log" 2>&1
  assert_contains "$warn_log" "Warnings:"
  assert_contains "$warn_log" "src/auth/login.js matches policy pattern src/auth/**"
  assert_contains "$warn_log" "Review recommended before claiming completion."
)
pass "policy warn-mode high-risk match"

echo
echo "== Strict policy file approval =="
rm -rf "$policy_file_approval_root"
mkdir -p "$policy_file_approval_root/.agent/approvals" "$policy_file_approval_root/src/auth"
git init -q "$policy_file_approval_root"
(
  cd "$policy_file_approval_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' 'approved' > .agent/approvals/high-risk-approved
  printf '%s\n' 'line one' > src/auth/login.js
  approved_log="$policy_file_approval_root/policy-file-approval.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$approved_log" 2>&1
  assert_contains "$approved_log" "High-risk approval detected from .agent/approvals/high-risk-approved."
  assert_contains "$approved_log" "Strict policy gate passed with approval."
)
pass "strict policy file approval"

echo
echo "== Policy legacy high_risk_patterns compatibility =="
rm -rf "$policy_legacy_root"
mkdir -p "$policy_legacy_root/.agent" "$policy_legacy_root/src/legacy"
git init -q "$policy_legacy_root"
(
  cd "$policy_legacy_root"
  printf '%s\n' \
    'high_risk_patterns:' \
    '  - "src/legacy/**"' \
    > .agent/policy.yml
  printf '%s\n' 'line one' > src/legacy/adapter.js
  legacy_log="$policy_legacy_root/policy-legacy.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --warn .agent/policy.yml >"$legacy_log" 2>&1
  assert_contains "$legacy_log" "src/legacy/adapter.js matches policy pattern src/legacy/**"
  assert_contains "$legacy_log" "Review recommended before claiming completion."
)
pass "policy legacy high_risk_patterns compatibility"

echo
echo "== Policy gate malformed YAML failure =="
rm -rf "$policy_malformed_root"
mkdir -p "$policy_malformed_root/.agent" "$policy_malformed_root/src/auth"
git init -q "$policy_malformed_root"
(
  cd "$policy_malformed_root"
  printf 'risk_files:\n\thigh:\n\t  - "src/auth/**"\n' > .agent/policy.yml
  printf '%s\n' 'line one' > src/auth/login.js
  policy_log="$policy_malformed_root/policy-malformed.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --warn .agent/policy.yml >"$policy_log" 2>&1; then
    echo "ERROR: expected policy failure for malformed YAML"
    exit 1
  fi
  assert_contains "$policy_log" "ERROR:"
  assert_contains "$policy_log" "tabs are not supported for indentation"
)
pass "policy malformed YAML failure"

echo
