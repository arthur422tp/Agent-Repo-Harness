# AGENTS.md

Use this file as the Codex entrypoint for a repository that has
Agent-Repo-Harness installed.

## Context Loading Policy

Use staged context loading before editing:

1. Read root `AGENTS.md`.
2. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and only the policy entries in `.agent/policy.yml` that apply to the expected files.
3. Prefer `scripts/collect-context.sh` for startup context.
4. Use `rg` and targeted file ranges to expand context for the active task.

Do not load large directories, generated outputs, historical plans, or unrelated docs unless the task specifically depends on them.

## Required Startup

Before editing, inspect:

- `agent.md`
- `handoff.md`
- `.agent/task.yml`
- applicable `.agent/policy.yml` entries, as described in the Context Loading Policy

Then run:

```bash
scripts/agent-preflight.sh
```

If the script is missing or cannot run, report the exact reason before making
changes.

## Task Boundaries

When starting a task in a repo that has `scripts/agent-task-profile.sh`, prefer
that helper to generate `.agent/task.yml`. Do not manually widen allowed paths
or enable high-risk gates to make unrelated edits pass.

Follow `.agent/task.yml`:

- only edit paths allowed by `allowed_paths`
- avoid paths listed in `forbidden_paths`
- respect `max_changed_files`
- respect `max_diff_lines`

If the requested work requires crossing the task boundary, stop and ask for the
task file to be updated or for explicit approval.

## Completion

If `.agent/task.yml` requires sandbox verification, run
`scripts/agent-sandbox-run.sh` before final finish and preserve
`.agent/sandbox-runs/<timestamp>/` evidence.

Before claiming completion, run:

```bash
scripts/agent-finish.sh
```

Then update `handoff.md` with:

- changed files
- verification commands and results
- remaining blockers
- next recommended action

Agent-Repo-Harness is a repo-local control layer. It is not a full agent
runtime, MCP server, sandbox, or proof of semantic correctness.
