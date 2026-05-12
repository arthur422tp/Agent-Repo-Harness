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

Start compact: read summaries and task boundaries before raw source.

Default startup budget:

1. Read this file.
2. Read `agent.md` for stable facts, but treat linked deeper docs as optional until needed.
3. Read `handoff.md` for current task state.
4. Read `.agent/task.yml` for allowed paths, forbidden paths, and completion requirements.
5. Read `.agent/policy.yml` only for policy rules that apply to files you expect to touch.
6. Run `scripts/collect-context.sh` when available instead of pasting large context into the prompt.

Expand only for files directly relevant to the current task. Prefer `rg`, file lists, symbol search, and targeted `sed -n` ranges over reading whole directories or long files. Load broad docs, generated files, lockfiles, logs, and historical plans only when they answer a concrete question.

When context grows, summarize what was learned in `handoff.md` or `docs/agent/discoveries.md` and continue from that summary instead of reloading the same raw files.

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
