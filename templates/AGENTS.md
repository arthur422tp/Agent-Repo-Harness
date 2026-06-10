# AGENTS.md

This repository uses Agent-Repo-Harness.

Start here before editing:

1. Read `docs/agent/context-loading.md` for the canonical context loading
   policy.
2. Read `.agent/task.yml` for task scope and completion requirements.
3. Read `.agent/policy.yml` only for policy rules that apply to files you
   expect to touch.
   For high-risk approval rules, see `docs/agent/policy-approval.md`.
4. If task flags require them, fill `.agent/acceptance.yml` and
   `.agent/review.yml` before completion.
5. If task flags require them, fill `.agent/failure-attribution.yml` and
   `.agent/interventions.yml` with concrete evidence before completion. See
   `docs/agent/failure-attribution.md` and `docs/agent/interventions.md`.
6. Run `scripts/agent-preflight.sh` before changing files when available.

During the task:

- Keep changes inside `.agent/task.yml` scope.
- Keep `.agent/episode.yml` status and objective aligned with the current
  task. See `docs/agent/episode-package.md`.
- Respect `allowed_paths`, `forbidden_paths`, `max_changed_files`, and
  `max_diff_lines`.
- Treat `agent.md` as stable repo memory, not a task plan.
- Treat `handoff.md` and `.agent/task.yml` as current task state.
- Treat `.agent/acceptance.yml` and `.agent/review.yml` as optional completion
  evidence when the current task requires them.
- Treat `.agent/failure-attribution.yml` and `.agent/interventions.yml` as
  optional completion evidence when the current task requires them.
- If `.agent/task.yml` requires sandbox verification, run the sandbox runner
  before final finish and preserve `.agent/sandbox-runs/<timestamp>/` evidence.
- Use `scripts/agent-audit.sh` for maintenance audits when needed, but do not
  use it as a substitute for `scripts/agent-finish.sh`. See
  `docs/agent/entropy-audit.md`.
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
