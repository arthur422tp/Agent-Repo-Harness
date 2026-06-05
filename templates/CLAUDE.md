# CLAUDE.md

This repository uses Agent-Repo-Harness with a Claude Code-compatible
entrypoint.

First steps:

1. Read `docs/agent/context-loading.md` for the canonical context loading
   policy.
2. Read `.agent/task.yml` for task scope and completion requirements.
3. Read `.agent/policy.yml` only for policy rules that apply to files you
   expect to touch.
   For high-risk approval rules, see `docs/agent/policy-approval.md`.
4. If task flags require them, fill `.agent/acceptance.yml` and
   `.agent/review.yml` before completion.
5. If task flags require them, fill `.agent/failure-attribution.yml` and
   `.agent/interventions.yml` with concrete evidence before completion.
6. Keep `.agent/episode.yml` aligned with the current objective and status.
7. Run `scripts/agent-preflight.sh` before editing when available.

Use the Claude Code project skills under `.claude/skills/` when they are
installed:

- `harness-entrypoint`: load the harness contract and current repo state.
- `policy-gate`: check high-risk files and approval requirements.
- `verification-gate`: run finish and verification checks before completion.
- `handoff-update`: update `handoff.md` after task state changes.
- `subagent-context-packet`: prepare compact context for delegated work.

Keep live prompts short. Put stable repo facts in `agent.md`, current task
state in `handoff.md` and `.agent/task.yml`, optional episode metadata in
`.agent/episode.yml`, optional evidence in `.agent/acceptance.yml`,
`.agent/review.yml`, `.agent/failure-attribution.yml`, and
`.agent/interventions.yml`, and reusable workflow rules in skills.

Lifecycle docs:

- `docs/agent/episode-package.md`
- `docs/agent/failure-attribution.md`
- `docs/agent/interventions.md`
- `docs/agent/entropy-audit.md`

Before final response, run `scripts/agent-finish.sh`. If a gate cannot run,
state the exact blocker and update `handoff.md`.

Use `scripts/agent-audit.sh` for maintenance audits when needed; it does not
replace `scripts/agent-finish.sh`.

Agent-Repo-Harness does not provide sandboxing, full runtime orchestration, an
MCP server, or semantic correctness guarantees.
