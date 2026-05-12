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
