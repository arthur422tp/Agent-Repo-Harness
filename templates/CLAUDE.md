# CLAUDE.md

This repository uses Agent-Repo-Harness with a Claude Code-compatible
entrypoint.

First steps:

1. Read `agent.md`.
2. Read `handoff.md`.
3. Read `.agent/policy.yml`.
4. Read `.agent/task.yml`.
5. Run `scripts/agent-preflight.sh` before editing when available.

Use the Claude Code project skills under `.claude/skills/` when they are
installed:

- `harness-entrypoint`: load the harness contract and current repo state.
- `policy-gate`: check high-risk files and approval requirements.
- `verification-gate`: run finish and verification checks before completion.
- `handoff-update`: update `handoff.md` after task state changes.
- `subagent-context-packet`: prepare compact context for delegated work.

Keep live prompts short. Put stable repo facts in `agent.md`, current task
state in `handoff.md` and `.agent/task.yml`, and reusable workflow rules in
skills.

Before final response, run `scripts/agent-finish.sh`. If a gate cannot run,
state the exact blocker and update `handoff.md`.

Agent-Repo-Harness does not provide sandboxing, full runtime orchestration, an
MCP server, or semantic correctness guarantees.
