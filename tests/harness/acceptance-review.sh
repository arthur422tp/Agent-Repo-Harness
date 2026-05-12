#!/usr/bin/env bash
set -euo pipefail

echo "== Acceptance gate skip semantics =="
rm -rf "$acceptance_skip_root"
mkdir -p "$acceptance_skip_root/.agent" "$acceptance_skip_root/scripts/lib"
(
  cd "$acceptance_skip_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: false' \
    > .agent/task.yml
  acceptance_log="$acceptance_skip_root/acceptance-skip.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Acceptance check is not required."
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance skip semantics"

echo
echo "== Acceptance gate required complete =="
rm -rf "$acceptance_pass_root"
mkdir -p "$acceptance_pass_root/.agent" "$acceptance_pass_root/scripts/lib"
(
  cd "$acceptance_pass_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "example-criterion"' \
    '      description: "Expected behavior is covered."' \
    '      met: true' \
    '      evidence: "Implemented in src/example.js."' \
    '      verification: ""' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_pass_root/acceptance-pass.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Acceptance check is required."
  assert_contains "$acceptance_log" "OK: criterion example-criterion"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance required complete"

echo
echo "== Acceptance gate unmet criterion failure =="
rm -rf "$acceptance_unmet_root"
mkdir -p "$acceptance_unmet_root/.agent" "$acceptance_unmet_root/scripts/lib"
(
  cd "$acceptance_unmet_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "example-criterion"' \
    '      description: "Expected behavior is covered."' \
    '      met: false' \
    '      evidence: "Implemented in src/example.js."' \
    '      verification: "bash validate-harness.sh"' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_unmet_root/acceptance-unmet.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected acceptance failure for unmet criterion"
    exit 1
  fi
  assert_contains "$acceptance_log" "criterion example-criterion met must be true"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance unmet criterion failure"

echo
echo "== Acceptance gate missing evidence failure =="
rm -rf "$acceptance_missing_evidence_root"
mkdir -p "$acceptance_missing_evidence_root/.agent" "$acceptance_missing_evidence_root/scripts/lib"
(
  cd "$acceptance_missing_evidence_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "example-criterion"' \
    '      description: "Expected behavior is covered."' \
    '      met: true' \
    '      evidence: ""' \
    '      verification: ""' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_missing_evidence_root/acceptance-missing-evidence.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected acceptance failure for missing evidence"
    exit 1
  fi
  assert_contains "$acceptance_log" "criterion example-criterion evidence or verification must be non-empty"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance missing evidence failure"

echo
echo "== Review evidence gate skip semantics =="
rm -rf "$review_skip_root"
mkdir -p "$review_skip_root/.agent" "$review_skip_root/scripts/lib"
(
  cd "$review_skip_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_review_evidence: false' \
    > .agent/task.yml
  review_log="$review_skip_root/review-skip.log"
  bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1
  assert_contains "$review_log" "Review evidence is not required."
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=pass"
)
pass "review evidence skip semantics"

echo
echo "== Review evidence gate required approved =="
rm -rf "$review_pass_root"
mkdir -p "$review_pass_root/.agent" "$review_pass_root/scripts/lib"
(
  cd "$review_pass_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_review_evidence: true' \
    > .agent/task.yml
  printf '%s\n' \
    'review:' \
    '  required: true' \
    '  status: approved' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "PR review approved on 2026-05-12."' \
    '  concerns: []' \
    > .agent/review.yml
  review_log="$review_pass_root/review-pass.log"
  bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1
  assert_contains "$review_log" "Review evidence is required."
  assert_contains "$review_log" "OK: review evidence"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=pass"
)
pass "review evidence required approved"

echo
echo "== Review evidence gate blocking concern failure =="
rm -rf "$review_blocked_root"
mkdir -p "$review_blocked_root/.agent" "$review_blocked_root/scripts/lib"
(
  cd "$review_blocked_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_review_evidence: true' \
    > .agent/task.yml
  printf '%s\n' \
    'review:' \
    '  required: true' \
    '  status: changes_requested' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "PR review requested changes."' \
    '  concerns:' \
    '    - id: "review-1"' \
    '      description: "Fix the failing edge case."' \
    '      blocking: true' \
    > .agent/review.yml
  review_log="$review_blocked_root/review-blocked.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for blocking concern"
    exit 1
  fi
  assert_contains "$review_log" "review.status must not be changes_requested"
  assert_contains "$review_log" "blocking concern review-1"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence blocking concern failure"

echo
