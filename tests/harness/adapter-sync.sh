#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Adapter sync =="

for required_path in \
  adapters/codex/AGENTS.md \
  adapters/codex/codex-start-prompt.md \
  adapters/codex/codex-repair-prompt.md \
  adapters/codex/codex-verify-prompt.md \
  adapters/codex/codex-handoff-prompt.md \
  adapters/claude-code/CLAUDE.md \
  adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md \
  adapters/claude-code/.claude/skills/policy-gate/SKILL.md \
  adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md \
  adapters/claude-code/.claude/skills/verify-harness-completion/SKILL.md \
  adapters/claude-code/.claude/skills/verification-gate/SKILL.md \
  adapters/claude-code/.claude/skills/handoff-update/SKILL.md \
  adapters/claude-code/.claude/skills/subagent-context-packet/SKILL.md \
  adapters/hooks/README.md \
  adapters/hooks/git/pre-commit \
  adapters/hooks/git/pre-push
do
  assert_exists "$repo_root/$required_path"
done

for hook_path in \
  adapters/hooks/git/pre-commit \
  adapters/hooks/git/pre-push
do
  bash -n "$repo_root/$hook_path"
  if [ ! -x "$repo_root/$hook_path" ]; then
    echo "ERROR: expected hook adapter to be executable: $hook_path"
    exit 1
  fi
done
pass "Git hook adapters are valid"

assert_contains "$repo_root/adapters/codex/AGENTS.md" "## Context Loading Policy"
assert_contains "$repo_root/adapters/codex/AGENTS.md" 'applicable `.agent/policy.yml` entries'
assert_contains "$repo_root/adapters/codex/codex-start-prompt.md" "Use staged context loading"
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'finish-summary.md'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'failing gates'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'scope-result.txt'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'policy-result.txt'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'tdd-evidence-result.txt'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'review-result.txt'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'do not fabricate'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'explicit human approval'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'REPAIRED_AND_PASSED'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'REPAIRED_BUT_STILL_FAILING'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'BLOCKED_NEEDS_HUMAN'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'SCOPE_OR_POLICY_NEEDS_APPROVAL'
assert_contains "$repo_root/adapters/codex/codex-repair-prompt.md" 'exactly one of'
assert_contains "$repo_root/adapters/codex/codex-verify-prompt.md" 'agent-finish.sh --strict'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'handoff.md'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'finish-summary.md'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Repair outcome'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Latest run directory'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Failing gate before repair'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Fix applied'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Remaining blocker'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'Next action'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'REPAIRED_AND_PASSED'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'REPAIRED_BUT_STILL_FAILING'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'BLOCKED_NEEDS_HUMAN'
assert_contains "$repo_root/adapters/codex/codex-handoff-prompt.md" 'SCOPE_OR_POLICY_NEEDS_APPROVAL'
assert_contains "$repo_root/adapters/claude-code/CLAUDE.md" "## Context Loading Policy"
assert_contains "$repo_root/adapters/claude-code/CLAUDE.md" 'applicable `.agent/policy.yml` entries'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md" 'Read `.agent/task.yml` for active task scope.'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md" 'Read applicable `.agent/policy.yml` entries'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md" 'before broad source inspection.'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'finish-summary.md'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'failing gates'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'check-subagent-evidence'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'do not fabricate'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'explicit human approval'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'REPAIRED_AND_PASSED'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/repair-failed-harness-run/SKILL.md" 'BLOCKED_NEEDS_HUMAN'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/verify-harness-completion/SKILL.md" 'agent-finish.sh --strict'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/handoff-update/SKILL.md" 'finish-summary.md'
assert_contains "$repo_root/adapters/claude-code/.claude/skills/handoff-update/SKILL.md" 'Repair outcome'
assert_not_contains "$repo_root/adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md" 'Read `.agent/policy.yml` for high-risk areas and approvals.'
pass "adapter prompts and skills stay in sync"
