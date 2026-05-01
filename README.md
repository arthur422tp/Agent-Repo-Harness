# Agent-Repo-Harness

Agent-Repo-Harness is a lightweight repo-local harness framework for AI coding
agents such as Codex, Claude Code, Superpowers-compatible agents, and generic
coding agents.

It provides a universal core plus adapter files:

- universal repo memory: `agent.md`, `handoff.md`, `.agent/task.yml`
- universal gates: `scripts/check-policy.sh`, `scripts/check-scope.sh`,
  `scripts/agent-verify.sh`, `scripts/agent-finish.sh`
- universal entrypoints: `AGENTS.md`, `CLAUDE.md`
- adapters: `adapters/codex/`, `adapters/claude-code/`
- preserved Superpowers-compatible skills: `skills/*`

The harness keeps stable repo facts separate from task state:

- `agent.md`: stable repo map and operating rules
- `handoff.md`: current task state and next action
- `.agent/task.yml`: machine-readable current task scope

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

## Current Status

This repository is evolving from a Superpowers Companion MVP into a universal
repo-local harness core with agent adapters.

Superpowers remains supported. Existing Superpowers-compatible skills stay in
place and remain documented.

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
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

`agent-finish.sh` writes evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`.

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
and finish evidence creation.
