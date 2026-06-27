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
echo "== Acceptance gate default text evidence remains valid =="
rm -rf "$acceptance_pass_root-default-text"
mkdir -p "$acceptance_pass_root-default-text/.agent" "$acceptance_pass_root-default-text/scripts/lib"
(
  cd "$acceptance_pass_root-default-text"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Manual evidence is still accepted by default."' \
    '      met: true' \
    '      evidence: "Ran the verification gate."' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_pass_root-default-text/acceptance-default-text.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Acceptance check is required."
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance default text evidence remains valid"

echo
echo "== Acceptance gate strict refs reject text-only evidence =="
rm -rf "$acceptance_strict_text_only_root"
mkdir -p "$acceptance_strict_text_only_root/.agent" "$acceptance_strict_text_only_root/scripts/lib"
(
  cd "$acceptance_strict_text_only_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Text-only evidence is not enough."' \
    '      met: true' \
    '      evidence: "Manual check."' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_strict_text_only_root/acceptance-strict-text.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for text-only evidence"
    exit 1
  fi
  assert_contains "$acceptance_log" "Strict evidence refs are enabled."
  assert_contains "$acceptance_log" "requires evidence_refs because evidence.strict_refs is true"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs reject text-only evidence"

echo
echo "== Acceptance gate strict refs pass with finish summary =="
rm -rf "$acceptance_strict_finish_root"
mkdir -p "$acceptance_strict_finish_root/.agent/runs/20260627-091500" \
  "$acceptance_strict_finish_root/scripts/lib"
(
  cd "$acceptance_strict_finish_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": [
    {
      "name": "agent-verify",
      "exit_status": 0,
      "evidence": ".agent/runs/20260627-091500/verify-result.txt"
    }
  ]
}
JSON
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/20260627-091500/finish-summary.json"' \
    '          overall_result: "pass"' \
    '          gate: "agent-verify"' \
    '          expected_exit_status: 0' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_strict_finish_root/acceptance-strict-finish.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Strict evidence refs are enabled."
  assert_contains "$acceptance_log" "OK: finish_summary_json overall_result is pass"
  assert_contains "$acceptance_log" "OK: gate agent-verify exit_status is 0"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance strict refs pass with finish summary"

echo
echo "== Acceptance gate strict refs wrong gate status failure =="
rm -rf "$acceptance_wrong_gate_root"
mkdir -p "$acceptance_wrong_gate_root/.agent/runs/20260627-091500" \
  "$acceptance_wrong_gate_root/scripts/lib"
(
  cd "$acceptance_wrong_gate_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": [
    {
      "name": "agent-verify",
      "exit_status": 1
    }
  ]
}
JSON
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/20260627-091500/finish-summary.json"' \
    '          overall_result: "pass"' \
    '          gate: "agent-verify"' \
    '          expected_exit_status: 0' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_wrong_gate_root/acceptance-wrong-gate.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for wrong gate status"
    exit 1
  fi
  assert_contains "$acceptance_log" "gate agent-verify exit_status expected 0 got 1"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs wrong gate status failure"

echo
echo "== Acceptance gate strict refs missing path failure =="
rm -rf "$acceptance_invalid_ref_path_root"
mkdir -p "$acceptance_invalid_ref_path_root/.agent" "$acceptance_invalid_ref_path_root/scripts/lib"
(
  cd "$acceptance_invalid_ref_path_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Missing artifact fails."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/missing/finish-summary.json"' \
    '          overall_result: "pass"' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_invalid_ref_path_root/acceptance-missing-path.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for missing evidence ref path"
    exit 1
  fi
  assert_contains "$acceptance_log" "path does not exist"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs missing path failure"

echo
echo "== Acceptance gate strict refs path traversal failure =="
rm -rf "$acceptance_traversal_ref_root"
mkdir -p "$acceptance_traversal_ref_root/.agent" "$acceptance_traversal_ref_root/scripts/lib"
(
  cd "$acceptance_traversal_ref_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Traversal fails."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: "../secret.txt"' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_traversal_ref_root/acceptance-traversal.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for path traversal"
    exit 1
  fi
  assert_contains "$acceptance_log" "path must not contain path traversal"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs path traversal failure"

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
  assert_contains "$acceptance_log" "criterion example-criterion evidence, verification, or evidence_refs must be non-empty"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance missing evidence failure"

echo
echo "== Evidence refs command output valid =="
rm -rf "$acceptance_command_output_ref_root"
mkdir -p "$acceptance_command_output_ref_root/.agent/runs/20260627-091500" \
  "$acceptance_command_output_ref_root/scripts/lib"
(
  cd "$acceptance_command_output_ref_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'HARNESS_VERIFY_RESULT=pass' \
    'HARNESS_FAILURES=0' \
    > .agent/runs/20260627-091500/verify-result.txt
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: ".agent/runs/20260627-091500/verify-result.txt"' \
    '          must_contain:' \
    '            - "HARNESS_VERIFY_RESULT=pass"' \
    '          must_not_contain:' \
    '            - "FAIL:"' \
    > .agent/acceptance.yml
  evidence_refs_log="$acceptance_command_output_ref_root/evidence-refs.log"
  python3 "$repo_root/templates/scripts/check-evidence-refs.py" .agent/acceptance.yml >"$evidence_refs_log" 2>&1
  assert_contains "$evidence_refs_log" "== Evidence Refs Gate =="
  assert_contains "$evidence_refs_log" "OK: evidence ref acceptance.criteria[1].evidence_refs[1] path exists"
  assert_contains "$evidence_refs_log" "OK: command_output contains HARNESS_VERIFY_RESULT=pass"
  assert_contains "$evidence_refs_log" "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence refs command output valid"

echo
echo "== Evidence refs command output missing content failure =="
rm -rf "$acceptance_command_output_missing_root"
mkdir -p "$acceptance_command_output_missing_root/.agent/runs/20260627-091500" \
  "$acceptance_command_output_missing_root/scripts/lib"
(
  cd "$acceptance_command_output_missing_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'HARNESS_VERIFY_RESULT=fail' \
    > .agent/runs/20260627-091500/verify-result.txt
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: ".agent/runs/20260627-091500/verify-result.txt"' \
    '          must_contain:' \
    '            - "HARNESS_VERIFY_RESULT=pass"' \
    > .agent/acceptance.yml
  evidence_refs_log="$acceptance_command_output_missing_root/evidence-refs.log"
  if python3 "$repo_root/templates/scripts/check-evidence-refs.py" .agent/acceptance.yml >"$evidence_refs_log" 2>&1; then
    echo "ERROR: expected evidence refs failure for missing content"
    exit 1
  fi
  assert_contains "$evidence_refs_log" "missing required content"
  assert_contains "$evidence_refs_log" "EVIDENCE_REFS_RESULT=fail"
)
pass "evidence refs command output missing content failure"

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
echo "== Review evidence gate required false failure =="
rm -rf "$review_required_false_root"
mkdir -p "$review_required_false_root/.agent" "$review_required_false_root/scripts/lib"
(
  cd "$review_required_false_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_review_evidence: true' \
    > .agent/task.yml
  printf '%s\n' \
    'review:' \
    '  required: false' \
    '  status: approved' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "PR review approved on 2026-05-12."' \
    '  concerns: []' \
    > .agent/review.yml
  review_log="$review_required_false_root/review-required-false.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for review.required false"
    exit 1
  fi
  assert_contains "$review_log" "review.required must be true when review evidence is required"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence required false failure"

echo
echo "== Review evidence gate missing required failure =="
rm -rf "$review_required_missing_root"
mkdir -p "$review_required_missing_root/.agent" "$review_required_missing_root/scripts/lib"
(
  cd "$review_required_missing_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_review_evidence: true' \
    > .agent/task.yml
  printf '%s\n' \
    'review:' \
    '  status: approved' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "PR review approved on 2026-05-12."' \
    '  concerns: []' \
    > .agent/review.yml
  review_log="$review_required_missing_root/review-required-missing.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for missing review.required"
    exit 1
  fi
  assert_contains "$review_log" "review.required must be true when review evidence is required"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence missing required failure"

echo
echo "== Review evidence gate missing concerns failure =="
rm -rf "$review_missing_concerns_root"
mkdir -p "$review_missing_concerns_root/.agent" "$review_missing_concerns_root/scripts/lib"
(
  cd "$review_missing_concerns_root"
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
    > .agent/review.yml
  review_log="$review_missing_concerns_root/review-missing-concerns.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for missing review.concerns"
    exit 1
  fi
  assert_contains "$review_log" "review.concerns must be a list"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence missing concerns failure"

echo
echo "== Review evidence gate null concerns failure =="
rm -rf "$review_null_concerns_root"
mkdir -p "$review_null_concerns_root/.agent" "$review_null_concerns_root/scripts/lib"
(
  cd "$review_null_concerns_root"
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
    '  concerns: null' \
    > .agent/review.yml
  review_log="$review_null_concerns_root/review-null-concerns.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for null review.concerns"
    exit 1
  fi
  assert_contains "$review_log" "review.concerns must be a list"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence null concerns failure"

echo
echo "== Review evidence gate scalar concerns failure =="
rm -rf "$review_scalar_concerns_root"
mkdir -p "$review_scalar_concerns_root/.agent" "$review_scalar_concerns_root/scripts/lib"
(
  cd "$review_scalar_concerns_root"
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
    '  concerns: "none"' \
    > .agent/review.yml
  review_log="$review_scalar_concerns_root/review-scalar-concerns.log"
  if bash "$repo_root/templates/scripts/check-review-evidence.sh" >"$review_log" 2>&1; then
    echo "ERROR: expected review evidence failure for scalar review.concerns"
    exit 1
  fi
  assert_contains "$review_log" "review.concerns must be a list"
  assert_contains "$review_log" "REVIEW_EVIDENCE_RESULT=fail"
)
pass "review evidence scalar concerns failure"

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
