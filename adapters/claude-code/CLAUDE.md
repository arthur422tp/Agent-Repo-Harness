# CLAUDE.md

Use this file as the Claude Code project entrypoint for a repository that has
Agent-Repo-Harness installed.

## Context Loading Policy

Use staged context loading before editing:

1. Read root `AGENTS.md`.
2. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and only the policy entries in `.agent/policy.yml` that apply to the expected files.
3. Prefer `scripts/collect-context.sh` for startup context.
4. Use `rg` and targeted file ranges to expand context for the active task.

Do not load large directories, generated outputs, historical plans, or unrelated docs unless the task specifically depends on them.

## Required Startup

Read these files before editing:

- `agent.md`
- `handoff.md`
- `.agent/policy.yml`
- `.agent/task.yml`

Run:

```bash
scripts/agent-preflight.sh
```

Use the project skills in `.claude/skills/` for reusable workflow instead of
pasting long instructions into each prompt.

## Boundaries

Respect the active task in `.agent/task.yml`, especially `allowed_paths`,
`forbidden_paths`, `max_changed_files`, and `max_diff_lines`.

## Completion

Before final response:

```bash
scripts/agent-finish.sh
```

Update `handoff.md` with changed files, verification evidence, blockers, and
the next recommended action. If verification cannot run, explain why.

This harness remains lightweight. It does not provide sandboxing, an agent
runtime, an MCP server, or semantic correctness guarantees.
