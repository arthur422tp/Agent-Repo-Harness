#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Template sync =="

assert_files_match() {
  local expected="$1"
  local actual="$2"

  if ! cmp -s "$expected" "$actual"; then
    echo "ERROR: expected files to match"
    echo "Expected: $expected"
    echo "Actual: $actual"
    exit 1
  fi
}

assert_contains "$repo_root/templates/AGENTS.md" 'Read `.agent/task.yml` for task scope'
assert_contains "$repo_root/templates/AGENTS.md" 'Read `.agent/policy.yml` only for policy rules that apply'
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/context-loading.md"
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/policy-approval.md"
assert_not_contains "$repo_root/templates/AGENTS.md" "## Context Loading Policy"
assert_not_contains "$repo_root/templates/AGENTS.md" 'Read `.agent/policy.yml` for high-risk areas and approval rules.'
assert_contains "$repo_root/templates/CLAUDE.md" 'Read `.agent/task.yml` for task scope'
assert_contains "$repo_root/templates/CLAUDE.md" 'Read `.agent/policy.yml` only for policy rules that apply'
assert_contains "$repo_root/templates/CLAUDE.md" "docs/agent/context-loading.md"
assert_contains "$repo_root/templates/CLAUDE.md" "docs/agent/policy-approval.md"
assert_not_contains "$repo_root/templates/CLAUDE.md" "## Context Loading Policy"
assert_not_contains "$repo_root/templates/CLAUDE.md" '3. Read `.agent/policy.yml`.'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_tdd_evidence: false'
assert_not_contains "$repo_root/templates/.agent/task.yml" 'requires_tdd_evidence: true'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_architecture_evidence: false'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_failure_attribution: false'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_intervention_record: false'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_sandbox_verification: false'
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_command_ledger: false'
assert_contains "$repo_root/templates/.agent/task.yml" 'expects_handoff_update: true'
assert_contains "$repo_root/templates/.agent/task.yml" 'agent-finish.sh does not enforce'
assert_not_contains "$repo_root/templates/.agent/task.yml" 'requires_handoff_update'
assert_contains "$repo_root/templates/.agent/harness.yml" 'runtime:'
assert_contains "$repo_root/templates/.agent/harness.yml" 'resource_limits:'
assert_contains "$repo_root/templates/.agent/harness.yml" 'max_finish_seconds: 0'
assert_contains "$repo_root/templates/.agent/harness.yml" 'max_changed_files: 0'
assert_contains "$repo_root/templates/.agent/harness.yml" 'audit:'
assert_contains "$repo_root/templates/.agent/harness.yml" 'command: scripts/agent-audit.sh'
assert_contains "$repo_root/templates/.agent/harness.yml" 'evidence_dir: .agent/audits'
assert_contains "$repo_root/templates/.agent/harness.yml" '    - doc-links'
assert_contains "$repo_root/templates/.agent/harness.yml" '    - git-status'
assert_contains "$repo_root/templates/.agent/harness.yml" '    - harness-config'
assert_contains "$repo_root/templates/.agent/harness.yml" 'sandbox:'
assert_contains "$repo_root/templates/.agent/harness.yml" 'enabled: false'
assert_contains "$repo_root/templates/.agent/harness.yml" 'runner: docker'
assert_contains "$repo_root/templates/.agent/harness.yml" 'mode: verification'
assert_contains "$repo_root/templates/.agent/harness.yml" 'command: "bash scripts/agent-finish.sh --strict"'
assert_contains "$repo_root/templates/.agent/harness.yml" 'network: "disabled"'
assert_contains "$repo_root/templates/.agent/harness.yml" 'timeout_seconds: 600'
assert_contains "$repo_root/examples/strict-tdd-task.yml" 'requires_tdd_evidence: true'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'expects_handoff_update: true'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'requires_architecture_evidence: false'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'requires_sandbox_verification: false'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'requires_command_ledger: false'
assert_not_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'requires_handoff_update'
assert_contains "$repo_root/templates/.agent/architecture.yml" 'status: not_reviewed'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/architecture.yml" 'status: not_reviewed'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'runtime:'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'resource_limits:'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'max_finish_seconds: 0'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'max_changed_files: 0'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'audit:'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'command: scripts/agent-audit.sh'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'evidence_dir: .agent/audits'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" '    - doc-links'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" '    - git-status'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" '    - harness-config'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'sandbox:'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'enabled: false'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'runner: docker'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'mode: verification'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'command: "bash scripts/agent-finish.sh --strict"'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'network: "disabled"'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" 'timeout_seconds: 600'
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/agent-audit.sh"
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/agent-sandbox-run.sh"
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh"
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/agent-run.sh"
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/check-command-ledger.sh"
assert_files_match \
  "$repo_root/templates/scripts/agent-sandbox-run.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/agent-sandbox-run.sh"
assert_files_match \
  "$repo_root/templates/scripts/check-sandbox-evidence.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh"
assert_files_match \
  "$repo_root/templates/scripts/agent-run.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/agent-run.sh"
assert_files_match \
  "$repo_root/templates/scripts/check-command-ledger.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/check-command-ledger.sh"

assert_contains "$repo_root/examples/universal-minimal-repo/AGENTS.md" 'Read `.agent/task.yml` for scope'
assert_contains "$repo_root/examples/universal-minimal-repo/AGENTS.md" 'applicable `.agent/policy.yml`'
assert_not_contains "$repo_root/examples/universal-minimal-repo/AGENTS.md" 'Read `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`'
assert_contains "$repo_root/examples/universal-minimal-repo/CLAUDE.md" 'Read `.agent/task.yml` for scope'
assert_contains "$repo_root/examples/universal-minimal-repo/CLAUDE.md" 'applicable `.agent/policy.yml`'
assert_not_contains "$repo_root/examples/universal-minimal-repo/CLAUDE.md" 'Follow `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.'
assert_contains "$repo_root/skills/harness-entrypoint/SKILL.md" '`.agent/task.yml`'
assert_contains "$repo_root/skills/harness-entrypoint/SKILL.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/skills/harness-entrypoint/SKILL.md" '   - `.agent/policy.yml`'
assert_contains "$repo_root/skills/repo-context-bootstrap/SKILL.md" "Build compact context before broad source inspection."

assert_contains "$target_root/AGENTS.md" 'Read `.agent/task.yml` for task scope'
assert_contains "$target_root/AGENTS.md" 'Read `.agent/policy.yml` only for policy rules that apply'
assert_contains "$target_root/AGENTS.md" "docs/agent/context-loading.md"
assert_contains "$target_root/AGENTS.md" "docs/agent/policy-approval.md"
assert_not_contains "$target_root/AGENTS.md" "## Context Loading Policy"
assert_not_contains "$target_root/AGENTS.md" 'Read `.agent/policy.yml` for high-risk areas and approval rules.'
assert_contains "$target_root/CLAUDE.md" 'Read `.agent/task.yml` for task scope'
assert_contains "$target_root/CLAUDE.md" 'Read `.agent/policy.yml` only for policy rules that apply'
assert_contains "$target_root/CLAUDE.md" "docs/agent/context-loading.md"
assert_contains "$target_root/CLAUDE.md" "docs/agent/policy-approval.md"
assert_not_contains "$target_root/CLAUDE.md" "## Context Loading Policy"
assert_not_contains "$target_root/CLAUDE.md" '3. Read `.agent/policy.yml`.'
assert_contains "$target_root/.agent/architecture.yml" 'status: not_reviewed'
pass "templates, examples, and installed entrypoints stay aligned"
