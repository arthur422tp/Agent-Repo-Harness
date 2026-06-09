#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Resource envelope disabled by default =="
resource_disabled_root="$tmp_root/resource-disabled"
rm -rf "$resource_disabled_root"
mkdir -p "$resource_disabled_root/.agent" "$resource_disabled_root/scripts/lib"
git init -q "$resource_disabled_root"
(
  cd "$resource_disabled_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/.agent/harness.yml" .agent/harness.yml
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_tdd_evidence: false' > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent scripts
  git commit -q -m "Add harness files"
  finish_log="$resource_disabled_root/agent-finish-resource-disabled.log"
  bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$resource_disabled_root" "resource-envelope-result.txt" "Resource envelope is disabled."
  assert_finish_json_contract "$resource_disabled_root" "pass"
)
pass "resource envelope disabled by default"

echo
echo "== Resource envelope fails changed-file limit =="
resource_changed_files_root="$tmp_root/resource-changed-files"
rm -rf "$resource_changed_files_root"
mkdir -p "$resource_changed_files_root/.agent" "$resource_changed_files_root/scripts/lib" "$resource_changed_files_root/src"
git init -q "$resource_changed_files_root"
(
  cd "$resource_changed_files_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'name: Resource Test' \
    'version: 1' \
    'mode: lightweight' \
    'paths:' \
    '  agent_map: agent.md' \
    '  handoff: handoff.md' \
    '  task_state: .agent/task.yml' \
    'scripts:' \
    '  preflight: scripts/agent-preflight.sh' \
    '  finish: scripts/agent-finish.sh' \
    '  verify: scripts/agent-verify.sh' \
    '  check_policy: scripts/check-policy.sh' \
    '  check_scope: scripts/check-scope.sh' \
    'verification:' \
    '  final_gate_command: scripts/agent-finish.sh' \
    'runtime:' \
    '  resource_limits:' \
    '    max_finish_seconds: 0' \
    '    max_changed_files: 1' \
    > .agent/harness.yml
  printf '%s\n' 'task:' '  completion:' '    requires_tdd_evidence: false' > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent scripts
  git commit -q -m "Add harness files"
  printf '%s\n' one > src/one.txt
  printf '%s\n' two > src/two.txt
  finish_log="$resource_changed_files_root/agent-finish-resource-changed-files.log"
  if bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1; then
    echo "ERROR: expected resource envelope failure"
    exit 1
  fi
  assert_contains "$finish_log" "Resource envelope failed."
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=fail"
  assert_file_contains "$resource_changed_files_root" "resource-envelope-result.txt" "changed files 2 exceeds limit 1"
  assert_finish_json_contract "$resource_changed_files_root" "fail"
)
pass "resource envelope fails changed-file limit"
