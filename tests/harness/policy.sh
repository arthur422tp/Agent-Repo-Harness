#!/usr/bin/env bash
set -euo pipefail

policy_structured_root="${policy_structured_root:-$tmp_root/policy-structured}"
policy_structured_no_approver_root="${policy_structured_no_approver_root:-$tmp_root/policy-structured-no-approver}"
policy_structured_no_reason_root="${policy_structured_no_reason_root:-$tmp_root/policy-structured-no-reason}"
policy_structured_no_paths_root="${policy_structured_no_paths_root:-$tmp_root/policy-structured-no-paths}"
policy_structured_uncovered_root="${policy_structured_uncovered_root:-$tmp_root/policy-structured-uncovered}"
policy_structured_precedence_root="${policy_structured_precedence_root:-$tmp_root/policy-structured-precedence}"
policy_structured_malformed_precedence_root="${policy_structured_malformed_precedence_root:-$tmp_root/policy-structured-malformed-precedence}"
policy_warn_structured_invalid_root="${policy_warn_structured_invalid_root:-$tmp_root/policy-warn-structured-invalid}"

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
  assert_contains "$strict_approved_log" "WARN: legacy high-risk approval from environment is accepted but structured approval is recommended."
  assert_contains "$strict_approved_log" "High-risk approval detected from environment."
  assert_contains "$strict_approved_log" "Strict policy gate passed with legacy approval."
)
pass "strict policy semantics"

echo
echo "== Strict policy structured approval =="
rm -rf "$policy_structured_root"
mkdir -p "$policy_structured_root/.agent/approvals" "$policy_structured_root/src/auth"
git init -q "$policy_structured_root"
(
  cd "$policy_structured_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  approved_at: "2026-05-12T00:00:00Z"' \
    '  task_id: "structured-approval-test"' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  structured_log="$policy_structured_root/policy-structured.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$structured_log" 2>&1
  assert_contains "$structured_log" "High-risk approval detected from .agent/approvals/high-risk-approved.yml."
  assert_contains "$structured_log" "Strict policy gate passed with structured approval."
)
pass "strict policy structured approval"

echo
echo "== Strict policy structured approval requires approved_by =="
rm -rf "$policy_structured_no_approver_root"
mkdir -p "$policy_structured_no_approver_root/.agent/approvals" "$policy_structured_no_approver_root/src/auth"
git init -q "$policy_structured_no_approver_root"
(
  cd "$policy_structured_no_approver_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: ""' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_approver_log="$policy_structured_no_approver_root/policy-structured-no-approver.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_approver_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty approved_by"
    exit 1
  fi
  assert_contains "$no_approver_log" "ERROR: structured high-risk approval requires approval.approved_by."
)
pass "strict policy structured approval requires approved_by"

echo
echo "== Strict policy structured approval requires reason =="
rm -rf "$policy_structured_no_reason_root"
mkdir -p "$policy_structured_no_reason_root/.agent/approvals" "$policy_structured_no_reason_root/src/auth"
git init -q "$policy_structured_no_reason_root"
(
  cd "$policy_structured_no_reason_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: ""' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_reason_log="$policy_structured_no_reason_root/policy-structured-no-reason.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_reason_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty reason"
    exit 1
  fi
  assert_contains "$no_reason_log" "ERROR: structured high-risk approval requires approval.reason."
)
pass "strict policy structured approval requires reason"

echo
echo "== Strict policy structured approval requires approved_paths =="
rm -rf "$policy_structured_no_paths_root"
mkdir -p "$policy_structured_no_paths_root/.agent/approvals" "$policy_structured_no_paths_root/src/auth"
git init -q "$policy_structured_no_paths_root"
(
  cd "$policy_structured_no_paths_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths: []' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_paths_log="$policy_structured_no_paths_root/policy-structured-no-paths.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_paths_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty approved_paths"
    exit 1
  fi
  assert_contains "$no_paths_log" "ERROR: structured high-risk approval requires non-empty approval.approved_paths."
)
pass "strict policy structured approval requires approved_paths"

echo
echo "== Strict policy structured approval must cover changed file =="
rm -rf "$policy_structured_uncovered_root"
mkdir -p "$policy_structured_uncovered_root/.agent/approvals" "$policy_structured_uncovered_root/src/auth"
git init -q "$policy_structured_uncovered_root"
(
  cd "$policy_structured_uncovered_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: "User explicitly approved a different high-risk change."' \
    '  approved_paths:' \
    '    - "src/payments/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  uncovered_log="$policy_structured_uncovered_root/policy-structured-uncovered.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$uncovered_log" 2>&1; then
    echo "ERROR: expected structured approval failure for uncovered high-risk file"
    exit 1
  fi
  assert_contains "$uncovered_log" "ERROR: structured high-risk approval does not cover src/auth/login.js."
)
pass "strict policy structured approval must cover changed file"

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
echo "== Policy warn mode ignores invalid structured approval =="
rm -rf "$policy_warn_structured_invalid_root"
mkdir -p "$policy_warn_structured_invalid_root/.agent/approvals" "$policy_warn_structured_invalid_root/src/auth"
git init -q "$policy_warn_structured_invalid_root"
(
  cd "$policy_warn_structured_invalid_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: ""' \
    '  reason: ""' \
    '  approved_paths: []' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  warn_invalid_log="$policy_warn_structured_invalid_root/policy-warn-structured-invalid.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --warn .agent/policy.yml >"$warn_invalid_log" 2>&1
  assert_contains "$warn_invalid_log" "src/auth/login.js matches policy pattern src/auth/**"
  assert_contains "$warn_invalid_log" "Review recommended before claiming completion."
  assert_not_contains "$warn_invalid_log" "ERROR: structured high-risk approval"
)
pass "policy warn mode ignores invalid structured approval"

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
  assert_contains "$approved_log" "WARN: legacy high-risk approval file is accepted but structured approval is recommended."
  assert_contains "$approved_log" "High-risk approval detected from .agent/approvals/high-risk-approved."
  assert_contains "$approved_log" "Strict policy gate passed with legacy approval."
)
pass "strict policy file approval"

echo
echo "== Strict policy structured approval blocks legacy fallback when invalid =="
rm -rf "$policy_structured_precedence_root"
mkdir -p "$policy_structured_precedence_root/.agent/approvals" "$policy_structured_precedence_root/src/auth"
git init -q "$policy_structured_precedence_root"
(
  cd "$policy_structured_precedence_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: ""' \
    '  reason: "Invalid structured approval should block legacy fallback."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'approved' > .agent/approvals/high-risk-approved
  printf '%s\n' 'line one' > src/auth/login.js
  precedence_log="$policy_structured_precedence_root/policy-structured-precedence.log"
  if AGENT_APPROVED_HIGH_RISK=1 bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$precedence_log" 2>&1; then
    echo "ERROR: expected invalid structured approval to block legacy fallback"
    exit 1
  fi
  assert_contains "$precedence_log" "ERROR: structured high-risk approval requires approval.approved_by."
)
pass "strict policy structured approval blocks legacy fallback when invalid"

echo
echo "== Strict policy malformed structured approval blocks legacy fallback =="
rm -rf "$policy_structured_malformed_precedence_root"
mkdir -p "$policy_structured_malformed_precedence_root/.agent/approvals" "$policy_structured_malformed_precedence_root/src/auth"
git init -q "$policy_structured_malformed_precedence_root"
(
  cd "$policy_structured_malformed_precedence_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf 'approval:\n\tapproved_by: "human"\n' > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'approved' > .agent/approvals/high-risk-approved
  printf '%s\n' 'line one' > src/auth/login.js
  malformed_precedence_log="$policy_structured_malformed_precedence_root/policy-structured-malformed-precedence.log"
  if AGENT_APPROVED_HIGH_RISK=1 bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$malformed_precedence_log" 2>&1; then
    echo "ERROR: expected malformed structured approval to block legacy fallback"
    exit 1
  fi
  assert_contains "$malformed_precedence_log" "ERROR: could not parse .agent/approvals/high-risk-approved.yml"
)
pass "strict policy malformed structured approval blocks legacy fallback"

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
