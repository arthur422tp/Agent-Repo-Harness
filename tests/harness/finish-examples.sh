#!/usr/bin/env bash
set -euo pipefail

echo "== Finish gate acceptance and review evidence =="
rm -rf "$finish_acceptance_review_root"
mkdir -p "$finish_acceptance_review_root/.agent" \
  "$finish_acceptance_review_root/scripts/lib"
git init -q "$finish_acceptance_review_root"
(
  cd "$finish_acceptance_review_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_tdd_evidence: false' \
    '    requires_acceptance_check: true' \
    '    requires_review_evidence: true' \
    > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "finish-evidence"' \
    '      description: "Finish records acceptance evidence."' \
    '      met: true' \
    '      evidence: ".agent/runs contains acceptance-result.txt."' \
    '      verification: "bash scripts/agent-finish.sh --best-effort"' \
    > .agent/acceptance.yml
  printf '%s\n' \
    'review:' \
    '  required: true' \
    '  status: approved_with_comments' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "Review recorded for finish evidence scenario."' \
    '  concerns:' \
    '    - id: "review-note"' \
    '      description: "Non-blocking comment."' \
    '      blocking: false' \
    > .agent/review.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent scripts
  git commit -q -m "Add harness files"
  finish_log="$finish_acceptance_review_root/agent-finish-acceptance-review.log"
  bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=pass"
  assert_run_evidence_files "$finish_acceptance_review_root"
  assert_finish_summary_contract "$finish_acceptance_review_root" "pass"
  assert_finish_json_contract "$finish_acceptance_review_root" "pass"
  assert_file_contains "$finish_acceptance_review_root" "acceptance-result.txt" "Acceptance check is required."
  assert_file_contains "$finish_acceptance_review_root" "acceptance-result.txt" "OK: criterion finish-evidence"
  assert_file_contains "$finish_acceptance_review_root" "review-result.txt" "Review evidence is required."
  assert_file_contains "$finish_acceptance_review_root" "review-result.txt" "OK: review evidence"
  assert_file_contains "$finish_acceptance_review_root" "subagent-evidence-result.txt" "Subagent evidence is not required."
)
pass "finish gate acceptance and review evidence"

echo
echo "== Finish gate strict scope failure =="
rm -rf "$finish_strict_root"
mkdir -p "$finish_strict_root/.agent" "$finish_strict_root/scripts/lib" "$finish_strict_root/src/billing"
git init -q "$finish_strict_root"
(
  cd "$finish_strict_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  forbidden_paths:' \
    '    - "src/billing/**"' \
    > .agent/task.yml
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent/task.yml .agent/policy.yml scripts
  git commit -q -m "Add harness files"
  printf '%s\n' 'line one' > src/billing/invoice.js
  finish_log="$finish_strict_root/agent-finish-strict-failure.log"
  if bash scripts/agent-finish.sh --strict >"$finish_log" 2>&1; then
    echo "ERROR: expected finish gate strict failure"
    exit 1
  fi
  assert_contains "$finish_log" "Scope check failed."
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=fail"
  finish_summary_count="$(find "$finish_strict_root/.agent/runs" -type f -name "finish-summary.md" | wc -l | tr -d '[:space:]')"
  if [ "$finish_summary_count" -lt 1 ]; then
    echo "ERROR: expected failing finish gate to create finish-summary.md"
    exit 1
  fi
  assert_contains "$finish_log" "Run directory: .agent/runs/"
  assert_run_evidence_files "$finish_strict_root"
  assert_finish_summary_contract "$finish_strict_root" "fail"
  assert_finish_json_contract "$finish_strict_root" "fail"
  assert_file_contains "$finish_strict_root" "check-agent-md-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "check-agent-md-result.txt" "Output:"
  assert_file_contains "$finish_strict_root" "scope-result.txt" "Exit status: 1"
  assert_file_contains "$finish_strict_root" "scope-result.txt" "Output:"
  assert_file_contains "$finish_strict_root" "policy-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "policy-result.txt" "Output:"
  assert_file_contains "$finish_strict_root" "tdd-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "tdd-evidence-result.txt" "Output:"
  assert_file_contains "$finish_strict_root" "acceptance-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "acceptance-result.txt" "Acceptance check is not required."
  assert_file_contains "$finish_strict_root" "review-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "review-result.txt" "Review evidence is not required."
  assert_file_contains "$finish_strict_root" "subagent-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "subagent-evidence-result.txt" "Subagent evidence is not required."
  assert_file_contains "$finish_strict_root" "verify-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "verify-result.txt" "Output:"
  assert_file_contains "$finish_strict_root" "changed-files.txt" "src/billing/invoice.js"
  assert_file_contains "$finish_strict_root" "git-diff-stat.txt" "# Git diff stat"
)
pass "finish gate strict scope failure"

echo
echo "== Finish gate strict TDD evidence failure =="
rm -rf "$tdd_required_failure_root"
mkdir -p "$tdd_required_failure_root/.agent" "$tdd_required_failure_root/scripts/lib"
git init -q "$tdd_required_failure_root"
(
  cd "$tdd_required_failure_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/.agent/tdd-evidence.yml" .agent/tdd-evidence.yml
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_tdd_evidence: true' \
    > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent/task.yml .agent/policy.yml .agent/tdd-evidence.yml scripts
  git commit -q -m "Add harness files"
  finish_log="$tdd_required_failure_root/agent-finish-tdd-failure.log"
  if bash scripts/agent-finish.sh --strict >"$finish_log" 2>&1; then
    echo "ERROR: expected finish gate TDD evidence failure"
    exit 1
  fi
  assert_contains "$finish_log" "TDD evidence is required."
  assert_contains "$finish_log" "TDD_EVIDENCE_RESULT=fail"
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=fail"
  assert_run_evidence_files "$tdd_required_failure_root"
  assert_finish_summary_contract "$tdd_required_failure_root" "fail"
  assert_finish_json_contract "$tdd_required_failure_root" "fail"
  assert_file_contains "$tdd_required_failure_root" "tdd-evidence-result.txt" "Exit status: 1"
  assert_file_contains "$tdd_required_failure_root" "tdd-evidence-result.txt" "red_phase.command must be non-empty"
  assert_file_contains "$tdd_required_failure_root" "acceptance-result.txt" "Acceptance check is not required."
  assert_file_contains "$tdd_required_failure_root" "review-result.txt" "Review evidence is not required."
  assert_file_contains "$tdd_required_failure_root" "subagent-evidence-result.txt" "Subagent evidence is not required."
  assert_file_contains "$tdd_required_failure_root" "verify-result.txt" "Exit status: 0"
)
pass "finish gate strict TDD evidence failure"

echo
echo "== Finish gate strict subagent evidence failure =="
subagent_required_failure_root="$tmp_root/subagent-required-failure"
rm -rf "$subagent_required_failure_root"
mkdir -p "$subagent_required_failure_root/.agent" "$subagent_required_failure_root/scripts/lib"
git init -q "$subagent_required_failure_root"
(
  cd "$subagent_required_failure_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/.agent/subagent-packet.yml" .agent/subagent-packet.yml
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/validate-subagent-packet.sh" scripts/validate-subagent-packet.sh
  cp "$repo_root/templates/scripts/validate-subagent-run.sh" scripts/validate-subagent-run.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_subagent_evidence: true' \
    > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent/task.yml .agent/policy.yml .agent/subagent-packet.yml scripts
  git commit -q -m "Add harness files"
  finish_log="$subagent_required_failure_root/agent-finish-subagent-failure.log"
  if bash scripts/agent-finish.sh --strict >"$finish_log" 2>&1; then
    echo "ERROR: expected finish gate subagent evidence failure"
    exit 1
  fi
  assert_contains "$finish_log" "Subagent evidence is required."
  assert_contains "$finish_log" "SUBAGENT_EVIDENCE_RESULT=fail"
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=fail"
  assert_run_evidence_files "$subagent_required_failure_root"
  assert_finish_summary_contract "$subagent_required_failure_root" "fail"
  assert_finish_json_contract "$subagent_required_failure_root" "fail"
  assert_file_contains "$subagent_required_failure_root" "subagent-evidence-result.txt" "Exit status: 1"
  assert_file_contains "$subagent_required_failure_root" "subagent-evidence-result.txt" "no valid subagent run evidence found"
)
pass "finish gate strict subagent evidence failure"

echo
echo "== Finish gate without git repository =="
rm -rf "$finish_nongit_root"
mkdir -p "$finish_nongit_root/.agent" "$finish_nongit_root/scripts/lib"
(
  cd "$finish_nongit_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  finish_log="$finish_nongit_root/agent-finish-nongit.log"
  bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$finish_nongit_root" "tdd-evidence-result.txt" "TDD evidence is not required."
  assert_file_contains "$finish_nongit_root" "acceptance-result.txt" "Acceptance check is not required."
  assert_file_contains "$finish_nongit_root" "review-result.txt" "Review evidence is not required."
  assert_file_contains "$finish_nongit_root" "subagent-evidence-result.txt" "Subagent evidence is not required."
  assert_file_contains "$finish_nongit_root" "changed-files.txt" "Not inside a git repository"
  assert_file_contains "$finish_nongit_root" "git-diff-stat.txt" "Not inside a git repository"
  assert_finish_json_contract "$finish_nongit_root" "pass"
)
pass "finish gate without git repository"

echo
echo "== Universal minimal example smoke =="
example_root="$tmp_root/universal-minimal-repo"
cp -R examples/universal-minimal-repo "$example_root"
(
  cd "$example_root"
  bash scripts/agent-preflight.sh
  bash scripts/validate-config.sh
  bash scripts/validate-task.sh
  bash scripts/check-policy.sh
  bash scripts/check-scope.sh
  bash scripts/agent-verify.sh
  example_finish_log="$tmp_root/universal-minimal-finish.log"
  bash scripts/agent-finish.sh >"$example_finish_log" 2>&1
  assert_contains "$example_finish_log" "AGENT_FINISH_RESULT=pass"
  assert_contains "$example_finish_log" "Summary: .agent/runs/"
)
pass "universal minimal example smoke"

echo
echo "PASS: validation completed"
