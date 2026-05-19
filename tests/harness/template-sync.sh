#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Template sync =="

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
pass "templates, examples, and installed entrypoints stay aligned"
