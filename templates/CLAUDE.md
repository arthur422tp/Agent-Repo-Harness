# CLAUDE.md

This repository uses Agent-Repo-Harness with a Claude Code-compatible
entrypoint.

First steps:

1. Read `agent.md`.
2. Read `handoff.md`.
3. Read `.agent/task.yml` for task scope and completion requirements.
4. Read `.agent/policy.yml` only for policy rules that apply to files you
   expect to touch.
5. If task flags require them, fill `.agent/acceptance.yml` and
   `.agent/review.yml` before completion.
6. Run `scripts/agent-preflight.sh` before editing when available.

## Context Loading Policy

Start compact. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries before broad source inspection.

Use `scripts/collect-context.sh` for compact startup context. Use `scripts/collect-context.sh --full` only when debugging stale repo memory, policy drift, or handoff gaps.

For full rules, see `docs/agent/context-loading.md`.

Use the Claude Code project skills under `.claude/skills/` when they are
installed:

- `harness-entrypoint`: load the harness contract and current repo state.
- `policy-gate`: check high-risk files and approval requirements.
- `verification-gate`: run finish and verification checks before completion.
- `handoff-update`: update `handoff.md` after task state changes.
- `subagent-context-packet`: prepare compact context for delegated work.

Keep live prompts short. Put stable repo facts in `agent.md`, current task
state in `handoff.md` and `.agent/task.yml`, optional acceptance/review
evidence in `.agent/acceptance.yml` and `.agent/review.yml`, and reusable
workflow rules in skills.

Before final response, run `scripts/agent-finish.sh`. If a gate cannot run,
state the exact blocker and update `handoff.md`.

Agent-Repo-Harness does not provide sandboxing, full runtime orchestration, an
MCP server, or semantic correctness guarantees.
