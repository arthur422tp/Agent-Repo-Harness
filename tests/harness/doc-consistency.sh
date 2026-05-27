#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Doc consistency =="

echo
echo "== Repository doc links =="
bash templates/scripts/check-doc-links.sh "$repo_root"
pass "repository doc links"

assert_contains "$repo_root/README.md" "## Context Loading Policy"
assert_contains "$repo_root/README.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/README.md" 'inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`'
assert_contains "$repo_root/README.md" 'TDD evidence is opt-in per task.'
assert_not_contains "$repo_root/README.md" 'the installed default task requires TDD evidence'
assert_contains "$repo_root/README.md" "## Platform Support"
assert_contains "$repo_root/README.md" "Unix-like shell environments"
assert_contains "$repo_root/README.md" "WSL"
assert_contains "$repo_root/README.md" "## Verification Strategy"
assert_contains "$repo_root/README.md" '.agent/harness.yml'
assert_contains "$repo_root/README.md" "## Guardrails, Not A Sandbox"
assert_contains "$repo_root/README.md" "process guardrails"
assert_contains "$repo_root/README.md" "not security boundaries"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "## Context Loading Policy"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'Before editing, inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.'
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'Inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.'
assert_contains "$repo_root/docs/codex-usage.md" "staged context loading"
assert_contains "$repo_root/docs/codex-usage.md" "repair outcome"
assert_contains "$repo_root/docs/superpowers-integration.md" "staged context loading"

assert_contains "$target_root/docs/agent/context-loading.md" "# Context Loading Policy"
assert_contains "$target_root/docs/agent/context-loading.md" "Start compact."
assert_contains "$target_root/docs/agent/context-loading.md" "Expand only to files directly relevant to the current task."
assert_contains "$target_root/agent.md" "## Context Loading"
assert_contains "$target_root/agent.md" "Keep this file compact enough to read at task start."
pass "documentation stays aligned with staged context loading"
