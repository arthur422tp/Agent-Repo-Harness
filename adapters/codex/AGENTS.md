# AGENTS.md

Use this file as the Codex entrypoint for a repository that has
Agent-Repo-Harness installed.

## Required Startup

Before editing, inspect:

- `agent.md`
- `handoff.md`
- `.agent/policy.yml`
- `.agent/task.yml`

Then run:

```bash
scripts/agent-preflight.sh
```

If the script is missing or cannot run, report the exact reason before making
changes.

## Task Boundaries

Follow `.agent/task.yml`:

- only edit paths allowed by `allowed_paths`
- avoid paths listed in `forbidden_paths`
- respect `max_changed_files`
- respect `max_diff_lines`

If the requested work requires crossing the task boundary, stop and ask for the
task file to be updated or for explicit approval.

## Completion

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
