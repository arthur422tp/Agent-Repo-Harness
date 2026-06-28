#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  repo_root="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  source "$repo_root/tests/harness/lib.sh"
fi

required_examples="
examples/docs-only-change
examples/bugfix-with-evidence-refs
examples/high-risk-policy-change
"

for example in $required_examples; do
  echo "== Example: $example =="
  assert_exists "$repo_root/$example/README.md"
  assert_exists "$repo_root/$example/.agent/task.yml"
  assert_exists "$repo_root/$example/.agent/harness.yml"
  assert_exists "$repo_root/$example/sample-run/finish-summary.json"
  assert_exists "$repo_root/$example/sample-run/verify-result.txt"
  assert_exists "$repo_root/$example/handoff.md"
  assert_contains "$repo_root/$example/README.md" "## Scenario"
  assert_contains "$repo_root/$example/README.md" "## Initial Task"
  assert_contains "$repo_root/$example/README.md" "## Profile Selected"
  assert_contains "$repo_root/$example/README.md" "## Commands Run"
  assert_contains "$repo_root/$example/README.md" "## Final Finish Result"
  assert_contains "$repo_root/$example/README.md" "## What The Agent May Claim"
  assert_contains "$repo_root/$example/README.md" "## What The Agent Must Not Claim"
done

echo
echo "== Strict evidence refs example =="
assert_exists "$repo_root/examples/bugfix-with-evidence-refs/.agent/acceptance.yml"
assert_contains "$repo_root/examples/bugfix-with-evidence-refs/.agent/acceptance.yml" "evidence_refs:"
assert_contains "$repo_root/examples/bugfix-with-evidence-refs/.agent/harness.yml" "strict_refs: true"

echo
echo "== High-risk policy example =="
assert_exists "$repo_root/examples/high-risk-policy-change/.agent/policy.yml"
assert_contains "$repo_root/examples/high-risk-policy-change/README.md" "Expected Failure"
assert_contains "$repo_root/examples/high-risk-policy-change/sample-run/policy-result.txt" "POLICY_RESULT=fail"

echo
echo "== Failed run repair example =="
assert_exists "$repo_root/examples/failed-run-repair/README.md"
assert_exists "$repo_root/examples/failed-run-repair/.agent/task.yml"
assert_exists "$repo_root/examples/failed-run-repair/.agent/harness.yml"
assert_exists "$repo_root/examples/failed-run-repair/.agent/acceptance.yml"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/finish-summary.json"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/acceptance-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/verify-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/finish-summary.json"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/acceptance-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/verify-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/handoff.md"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Scenario"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Initial Task"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Profile Selected"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Commands Run"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Expected Failure"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Failure Evidence"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Repair Step"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Rerun"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## Final Finish Result"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## What The Agent May Claim"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "## What The Agent Must Not Claim"
assert_contains "$repo_root/examples/failed-run-repair/sample-run-failed/acceptance-result.txt" "ACCEPTANCE_RESULT=fail"
assert_contains "$repo_root/examples/failed-run-repair/sample-run-passed/acceptance-result.txt" "ACCEPTANCE_RESULT=pass"

echo
echo "== Stability contract =="
assert_exists "$repo_root/docs/stability-contract.md"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-finish.sh"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-evidence-bind.sh"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/check-evidence-refs.py"
assert_contains "$repo_root/docs/stability-contract.md" "Agent-facing helper scripts are intended-stable in v0.x."
assert_contains "$repo_root/docs/stability-contract.md" "finish-summary.json"
assert_contains "$repo_root/docs/stability-contract.md" "Experimental Interfaces"
assert_contains "$repo_root/docs/stability-contract.md" "Deprecation Policy"
pass "productization examples and stability contract"
