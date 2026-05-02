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
- `.agent/tdd-evidence.yml`: red/green/refactor evidence for tasks that
  explicitly require TDD evidence
- `.agent/subagent-packet.yml`: optional controller-agent to subagent handoff
  context for delegated work
- `.agent/subagent-runs/`: optional controller-agent evidence from delegated
  subagent runs

Use scripts for gates:

```bash
scripts/agent-preflight.sh
scripts/validate-subagent-packet.sh
scripts/validate-subagent-run.sh
scripts/check-policy.sh
scripts/check-scope.sh
scripts/check-tdd-evidence.sh
scripts/agent-verify.sh
scripts/agent-finish.sh
```

`agent-finish.sh` records evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`, per-gate result files, `tdd-evidence-result.txt`,
`changed-files.txt`, and `git-diff-stat.txt`.

TDD evidence is required only when `.agent/task.yml` contains
`completion.requires_tdd_evidence: true`. When enabled, agents should fill
`.agent/tdd-evidence.yml` with the red command/failure, green command/pass, and
the tests added or changed before running `scripts/agent-finish.sh`.

Subagent packets are intended for controller-agent to subagent handoffs. A
controller can fill `.agent/subagent-packet.yml` with the task id, subagent
role, allowed paths, relevant files, required verification, and expected status
enum, then run `scripts/validate-subagent-packet.sh` before spawning or
prompting the subagent. Packets are not mandatory for all tasks and are not part
of the `agent-finish.sh` completion gate yet.

## Subagent Run Evidence

When a controller delegates work, it can copy the packet into a new directory
before or after the delegated run:

```text
.agent/subagent-runs/<timestamp>-<role>-<task_id>/
  packet.yml
  result.md
  status.txt
```

`result.md` records what the subagent did, including files inspected, files
changed, verification run, findings, concerns, and recommended next action.
`status.txt` records the final status as exactly one of `DONE`,
`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.

Validate the evidence with:

```bash
bash scripts/validate-subagent-run.sh .agent/subagent-runs/<timestamp>-<role>-<task_id>
```

This evidence is optional and is not part of `scripts/agent-finish.sh` yet.

Planned JSON evidence format, not implemented in this pass:

```json
{
  "timestamp": "20260501-120000",
  "mode": "strict",
  "command": "scripts/agent-finish.sh --strict",
  "result": "pass",
  "gates": [
    {
      "name": "check-scope",
      "exit_code": 0,
      "log": ".agent/runs/20260501-120000/scope-result.txt"
    }
  ]
}
```

Until JSON output exists, treat `finish-summary.md` and the text evidence files
in the run directory as canonical.

## Codex

Install `AGENTS.md` in the repository root. A reusable template is available at
`templates/AGENTS.md`, and a Codex-specific adapter is available at
`adapters/codex/AGENTS.md`.

Recommended start prompt:

```text
You are working in this repository using Agent-Repo-Harness.
First read `AGENTS.md`, then follow its instructions.
Before editing, inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.
For delegated work, fill `.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh`.
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
Agents using Superpowers should also consult
[superpowers-integration.md](superpowers-integration.md) for the mapping between
Superpowers skills and harness contracts.

Subagent packets remain optional. Use `.agent/subagent-packet.yml` and
`scripts/validate-subagent-packet.sh` when delegating precise work to a fresh
subagent; packet validation is not part of `scripts/agent-finish.sh` yet.
Pair packets with `.agent/subagent-runs/<timestamp>-<role>-<task_id>/` when
you want durable trace evidence for what the subagent did.

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
3. Fill `.agent/subagent-packet.yml` only when handing work to a subagent.
4. Run `scripts/agent-preflight.sh`.
5. Modify only files allowed by `.agent/task.yml`.
6. Run `scripts/agent-finish.sh` before reporting completion.
7. Update `handoff.md`.

## Avoid This

Do not repeat the full harness workflow in every task prompt. Do not put a
current implementation plan in `agent.md`. Do not treat the harness as a
sandbox, runtime orchestrator, MCP server, or semantic correctness guarantee.
