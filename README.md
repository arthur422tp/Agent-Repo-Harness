# Agent-Repo-Harness

Agent-Repo-Harness is a lightweight repo-local harness framework for AI coding
agents such as Codex, Claude Code, Superpowers-compatible agents, and generic
coding agents.

It provides a universal core plus adapter files:

- universal repo memory: `agent.md`, `handoff.md`, `.agent/task.yml`,
  optional `.agent/subagent-packet.yml`
- universal gates: `scripts/check-policy.sh`, `scripts/check-scope.sh`,
  `scripts/check-tdd-evidence.sh`, `scripts/agent-verify.sh`,
  `scripts/agent-finish.sh`
- universal entrypoints: `AGENTS.md`, `CLAUDE.md`
- adapters: `adapters/codex/`, `adapters/claude-code/`
- preserved Superpowers-compatible skills: `skills/*`

The harness keeps stable repo facts separate from task state:

- `agent.md`: stable repo map and operating rules
- `handoff.md`: current task state and next action
- `.agent/task.yml`: machine-readable current task scope
- `.agent/tdd-evidence.yml`: structured TDD evidence, required only when
  `.agent/task.yml` sets `completion.requires_tdd_evidence: true`
- `.agent/subagent-packet.yml`: optional controller-agent to subagent handoff
  packet for repeatable delegated work

## What It Is Not

Agent-Repo-Harness does not provide:

- a full agent runtime
- an MCP server
- sandboxing
- full runtime orchestration
- semantic correctness guarantees
- a replacement for Superpowers

It makes repo expectations explicit and gives agents lightweight gates to run
before they claim completion.

`scripts/agent-finish.sh` is the canonical completion gate. It runs the local
scope, policy, and verification checks and records durable evidence for the
run.

## Current Status

This repository is evolving from a Superpowers Companion MVP into a universal
repo-local harness core with agent adapters.

Superpowers remains supported. Existing Superpowers-compatible skills stay in
place and remain documented.

## Superpowers Integration

Agent-Repo-Harness is designed to work alongside Superpowers. Superpowers
provides workflow discipline; this harness provides repo-local contracts,
gates, and evidence.

See [docs/superpowers-integration.md](docs/superpowers-integration.md).

## Quick Start

Install the universal templates into a target repo:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
```

Then fill in:

- `agent.md`
- `handoff.md`
- `.agent/policy.yml`
- `.agent/task.yml`

Run the gates:

```bash
bash scripts/agent-preflight.sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/validate-subagent-packet.sh
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/check-tdd-evidence.sh
bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

`agent-finish.sh` writes evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`, gate result files such as `tdd-evidence-result.txt`,
`changed-files.txt`, and `git-diff-stat.txt`.

TDD evidence is opt-in per task. When `.agent/task.yml` contains
`completion.requires_tdd_evidence: true`, fill `.agent/tdd-evidence.yml` with
non-empty red and green phase commands/results plus at least one changed test
entry before running `scripts/agent-finish.sh`.

Subagent packets are optional. Fill `.agent/subagent-packet.yml` when a
controller agent needs to hand precise task text, allowed paths, required
verification, and expected status values to a fresh subagent. Validate it with
`scripts/validate-subagent-packet.sh`. It is not part of `agent-finish.sh` yet
and is not mandatory for ordinary tasks.

## Agent Entrypoints

Codex:

- install or copy `templates/AGENTS.md` to the target repo root
- see `docs/codex-usage.md`
- reusable adapter prompt: `adapters/codex/codex-start-prompt.md`

Claude Code:

- install or copy `templates/CLAUDE.md` to the target repo root
- optional project skills live under
  `adapters/claude-code/.claude/skills/`

Superpowers:

- use the existing Superpowers-compatible skills in `skills/`
- keep using Superpowers for workflow discipline such as planning, TDD,
  subagent-driven development, review, and branch finishing

Generic agents:

- read `AGENTS.md`
- inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`
- fill `.agent/subagent-packet.yml` only when delegating work to a subagent
- run the scripts directly

See [docs/USAGE_WITH_AGENTS.md](docs/USAGE_WITH_AGENTS.md) and
[docs/agent-support-matrix.md](docs/agent-support-matrix.md).

## Repository Contents

- `templates/`: files copied into target repositories
- `templates/scripts/`: dependency-light gates and validators
- `skills/`: Superpowers-compatible skills
- `adapters/`: agent-specific entrypoints and skill layouts
- `schemas/`: JSON Schemas for harness, policy, task, and handoff structures
- `examples/`: example installed shapes and task flows
- `install-agent-harness.sh`: template installer
- `validate-harness.sh`: repository validation and smoke tests

## Typical Workflow

1. Open the target repo in the coding agent.
2. Ask the agent to read `AGENTS.md` or `CLAUDE.md`.
3. Fill `.agent/task.yml` for scoped work.
4. Run `scripts/agent-preflight.sh`.
5. Make changes within task boundaries.
6. Run `scripts/agent-finish.sh`.
7. Update `handoff.md` with changed files, verification results, blockers, and
   next recommended action.

## Validation

Validate this repository:

```bash
bash validate-harness.sh
```

The validation checks script syntax, YAML and JSON syntax, required harness
files, install smoke tests, scope and policy behavior, configured verification,
subagent packet validation, TDD evidence behavior, and finish evidence creation.
