# AGENTS.md

This repository uses Agent-Repo-Harness.

Start here before editing:

1. Read `agent.md` for stable repository facts and local operating rules.
2. Read `handoff.md` for current task state.
3. Read `.agent/policy.yml` for high-risk areas and approval rules.
4. Read `.agent/task.yml` for task scope, allowed paths, forbidden paths, and
   completion requirements.
5. Run `scripts/agent-preflight.sh` before changing files when available.

During the task:

- Keep changes inside `.agent/task.yml` scope.
- Respect `allowed_paths`, `forbidden_paths`, `max_changed_files`, and
  `max_diff_lines`.
- Treat `agent.md` as stable repo memory, not a task plan.
- Treat `handoff.md` and `.agent/task.yml` as current task state.
- Use repo-owned scripts and adapter skills instead of long repeated prompts.
- If Superpowers is installed, preserve its workflow role and use the
  Superpowers-compatible skills in this repo.

Before claiming completion:

1. Run `scripts/agent-finish.sh`.
2. If verification cannot run, explain exactly why.
3. Update `handoff.md` with changed files, verification commands and results,
   remaining blockers, and the next recommended action.

This harness is not an agent runtime, sandbox, MCP server, or semantic
correctness guarantee. It provides repo-local context, scope, policy, and
verification conventions for coding agents.
