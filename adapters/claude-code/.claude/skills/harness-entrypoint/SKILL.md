---
name: harness-entrypoint
description: Load Agent-Repo-Harness context for Claude Code before repository edits.
---

# Harness Entrypoint

Use this skill before editing a repository that has Agent-Repo-Harness
installed.

## Steps

1. Read `CLAUDE.md` or `AGENTS.md` if present.
2. Read `agent.md` for stable repo facts.
3. Read `handoff.md` for current task state.
4. Read `.agent/policy.yml` for high-risk areas and approvals.
5. Read `.agent/task.yml` for active task scope.
6. Run `scripts/agent-preflight.sh` if it exists.

Keep reusable workflow in skills and keep task-specific instructions in the
live prompt. Do not convert `agent.md` into a task plan.

## Output

Briefly state:

- task goal
- active scope boundaries
- policy risks noticed
- verification command expected before completion
