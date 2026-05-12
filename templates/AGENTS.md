# AGENTS.md

This repository uses Agent-Repo-Harness.

Start here before editing:

1. Read `agent.md` for stable repository facts and local operating rules.
2. Read `handoff.md` for current task state.
3. Read `.agent/task.yml` for task scope, allowed paths, forbidden paths, and
   completion requirements.
4. Read `.agent/policy.yml` only for policy rules that apply to files you
   expect to touch.
5. If task flags require them, fill `.agent/acceptance.yml` and
   `.agent/review.yml` before completion.
6. Run `scripts/agent-preflight.sh` before changing files when available.

## Context Loading Policy

Start compact. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries before broad source inspection.

Use `scripts/collect-context.sh` for compact startup context. Use `scripts/collect-context.sh --full` only when debugging stale repo memory, policy drift, or handoff gaps.

For full rules, see `docs/agent/context-loading.md`.

During the task:

- Keep changes inside `.agent/task.yml` scope.
- Respect `allowed_paths`, `forbidden_paths`, `max_changed_files`, and
  `max_diff_lines`.
- Treat `agent.md` as stable repo memory, not a task plan.
- Treat `handoff.md` and `.agent/task.yml` as current task state.
- Treat `.agent/acceptance.yml` and `.agent/review.yml` as optional completion
  evidence when the current task requires them.
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
