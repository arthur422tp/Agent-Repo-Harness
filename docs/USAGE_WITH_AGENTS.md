# Usage With Agents

Agent-Repo-Harness is designed so users do not need to paste a long workflow
prompt every time. Keep live prompts short and move reusable rules into repo
files, scripts, skills, and adapters.

## Shared Pattern

Use repo files for durable context:

- `agent.md`: stable repo map and operating rules
- `handoff.md`: current task state
- `.agent/policy.yml`: high-risk files and approval rules
- `.agent/task.yml`: current task scope and completion requirements

Use scripts for gates:

```bash
scripts/agent-preflight.sh
scripts/check-policy.sh
scripts/check-scope.sh
scripts/agent-verify.sh
scripts/agent-finish.sh
```

`agent-finish.sh` records evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`.

Planned JSON evidence format, not implemented in this pass:

```json
{
  "timestamp": "20260501T120000Z",
  "mode": "strict",
  "command": "scripts/agent-finish.sh --strict",
  "result": "pass",
  "gates": [
    {
      "name": "check-scope",
      "exit_code": 0,
      "log": ".agent/runs/20260501T120000Z/check-scope.log"
    }
  ]
}
```

Until JSON output exists, treat `finish-summary.md` and per-gate logs as the
canonical evidence files.

## Codex

Install `AGENTS.md` in the repository root. A reusable template is available at
`templates/AGENTS.md`, and a Codex-specific adapter is available at
`adapters/codex/AGENTS.md`.

Recommended start prompt:

```text
You are working in this repository using Agent-Repo-Harness.
First read `AGENTS.md`, then follow its instructions.
Before editing, inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.
Respect task boundaries.
Before claiming completion, run `scripts/agent-finish.sh`.
If verification cannot be run, explain exactly why and update `handoff.md`.
```

See [codex-usage.md](codex-usage.md).

## Claude Code

Install `CLAUDE.md` in the repository root. A reusable template is available at
`templates/CLAUDE.md`, and a Claude Code adapter is available at
`adapters/claude-code/CLAUDE.md`.

For Claude Code project skills, copy or install:

```text
adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md
adapters/claude-code/.claude/skills/policy-gate/SKILL.md
adapters/claude-code/.claude/skills/verification-gate/SKILL.md
adapters/claude-code/.claude/skills/handoff-update/SKILL.md
adapters/claude-code/.claude/skills/subagent-context-packet/SKILL.md
```

Use those skills for repeated workflow instead of putting a long instruction
block in every prompt.

## Superpowers

Existing Superpowers-compatible skills remain supported:

- `harness-entrypoint`
- `repo-context-bootstrap`
- `repo-map-maintenance`
- `handoff-update`
- `subagent-context-packet`
- `policy-gate`
- `verification-gate`
- `discoveries-memory`
- `domain-risk-review`

Superpowers remains the workflow discipline layer for planning, TDD,
subagent-driven development, review, and finishing branches. Agent-Repo-Harness
adds repo-local context, task boundaries, policy gates, and verification gates.

Short prompt:

```text
Use $harness-entrypoint for this task.
Use $policy-gate if you touch high-risk files.
Use $verification-gate before completion.
Use $handoff-update if task state changes.

Task:
[task here]
```

## Generic Agents

Generic coding agents can use the harness without adapter-specific skill
support:

1. Read `AGENTS.md`.
2. Inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.
3. Run `scripts/agent-preflight.sh`.
4. Modify only files allowed by `.agent/task.yml`.
5. Run `scripts/agent-finish.sh` before reporting completion.
6. Update `handoff.md`.

## Avoid This

Do not repeat the full harness workflow in every task prompt. Do not put a
current implementation plan in `agent.md`. Do not treat the harness as a
sandbox, runtime orchestrator, MCP server, or semantic correctness guarantee.
