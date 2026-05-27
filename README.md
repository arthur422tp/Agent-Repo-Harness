# Agent-Repo-Harness

[![CI](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml)

**Agent-Repo-Harness is a repo-local completion gate for AI coding agents.**

It gives Codex, Claude Code, and generic AI coding agents a small set of
repo-owned contracts and scripts to check work before claiming it is complete.
It helps AI coding agents avoid claiming completion without:

- staying inside task scope
- passing policy checks
- running verification
- leaving durable handoff evidence

`scripts/agent-finish.sh` is the canonical completion gate. It checks local
scope and policy rules, applies any enabled evidence gates, runs verification,
and records durable evidence for the run. Updating `handoff.md` with that
outcome is a documented workflow step, not a check enforced by the finish
gate.

## Versioning

Current version: `0.1.0`.

See [CHANGELOG.md](CHANGELOG.md) for changes and
[docs/versioning.md](docs/versioning.md) for versioning and upgrade
expectations.

For public repository metadata and the `v0.1.0` release checklist, see
[docs/public-packaging.md](docs/public-packaging.md).

## Try It in Three Steps

1. Preview and install the harness into a target repository.
2. Enter that target repository.
3. Run the completion gate once to see the workflow.

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
cd /path/to/target-repo
bash scripts/agent-finish.sh --best-effort
```
For real tasks, edit .agent/task.yml, then run scripts/agent-finish.sh again.

## What It Is Not

Agent-Repo-Harness is not:

- a full agent runtime
- an MCP server
- a sandbox
- a semantic correctness guarantee

It makes completion expectations explicit; it does not decide whether a
feature is correct beyond the checks configured by the repository. See
[Guardrails, Not A Sandbox](#guardrails-not-a-sandbox) for the operational
boundary.

## Platform Support

Agent-Repo-Harness targets Unix-like shell environments. Its primary supported
environments are Linux, macOS, WSL, and Git Bash. Native PowerShell support is
not currently a goal.

## Verification Strategy

`scripts/agent-verify.sh` includes convenience heuristics for common Node, Go,
Python, and Docker Compose repositories. Real projects should prefer
repo-owned verification commands in `.agent/harness.yml`, for example:

```yaml
verification:
  required:
    - name: "unit tests"
      command: "uv run pytest tests/unit"
    - name: "lint"
      command: "uv run ruff check ."
```

When project-specific tooling differs from the default heuristics, the
repo-defined verification commands are the source of truth.

## Guardrails, Not A Sandbox

Scope and policy gates are process guardrails, not security boundaries. They
inspect Git changes and repo-local policy patterns; they do not isolate the
filesystem, network, secrets, or command side effects, and they do not
guarantee semantic correctness.

## How It Works

The harness keeps stable repository facts separate from current task state:

- `agent.md`: stable repository map and operating rules
- `handoff.md`: current task state and next action
- `.agent/task.yml`: machine-readable current task scope and enabled gates
- `.agent/policy.yml`: repo-local policy checks and protected paths
- `.agent/tdd-evidence.yml`: optional structured TDD evidence
- `.agent/acceptance.yml`: optional acceptance criteria evidence
- `.agent/review.yml`: optional review evidence
- `.agent/subagent-packet.yml`: optional controller-to-subagent handoff packet
- `.agent/subagent-runs/`: optional durable evidence from delegated runs

Installed entrypoints are `AGENTS.md` and `CLAUDE.md`. Agents use these files
with the durable context above, then finish work through
`scripts/agent-finish.sh`.

## Setup Details

Prerequisites:

- Bash
- Python (`python3` preferred; `python` accepted)
- Git for scope, diff, and finish evidence in normal repository workflows

After installation, fill in the repository-specific content in:

- `agent.md`
- `handoff.md`
- `.agent/policy.yml`
- `.agent/task.yml`

Harness config files use a small shared-reader YAML subset documented in
[docs/config-format.md](docs/config-format.md).

Before starting feature work, review the installed files and commit a clean
harness baseline:

```bash
git add .
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

Scope gates compare task changes against Git state. A committed baseline keeps
newly installed scaffold files from being reported as feature-task changes.

Structured high-risk approval is preferred. Installed projects document its
contract in `docs/agent/policy-approval.md`; agents must not record approval
without explicit human instruction.

## Evidence And Optional Gates

`agent-finish.sh` writes evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`, gate result files such as `tdd-evidence-result.txt`,
`acceptance-result.txt`, `review-result.txt`,
`subagent-evidence-result.txt`, `changed-files.txt`, and `git-diff-stat.txt`.

TDD evidence is opt-in per task. When `.agent/task.yml` contains
`completion.requires_tdd_evidence: true`, fill `.agent/tdd-evidence.yml` with
non-empty red and green phase commands/results plus at least one changed test
entry before running `scripts/agent-finish.sh`.

Acceptance and review evidence are also opt-in. When `.agent/task.yml`
contains `completion.requires_acceptance_check: true`, fill
`.agent/acceptance.yml` with at least one met criterion and concrete evidence
or verification. When it contains
`completion.requires_review_evidence: true`, fill `.agent/review.yml` with an
approving status, reviewer, evidence, and no blocking concerns.

Subagent packets are optional. Fill `.agent/subagent-packet.yml` when a
controller agent needs to hand precise task text, allowed paths, required
verification, and expected status values to a fresh subagent. Validate it with
`scripts/validate-subagent-packet.sh`. Packet validation is not itself part of
`agent-finish.sh`.

Controller agents can optionally record delegated results under
`.agent/subagent-runs/<timestamp>-<role>-<task_id>/` with `packet.yml`,
`result.md`, and `status.txt`, then validate a directory with
`scripts/validate-subagent-run.sh`. This becomes a completion gate only when
`.agent/task.yml` contains `completion.requires_subagent_evidence: true`; in
that mode, `scripts/check-subagent-evidence.sh` and `scripts/agent-finish.sh`
require at least one valid run directory.

## Useful Commands

Run individual checks when diagnosing a task or integrating the harness:

```bash
bash scripts/agent-preflight.sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/validate-subagent-packet.sh
bash scripts/check-doc-links.sh
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/check-tdd-evidence.sh
bash scripts/check-acceptance.sh
bash scripts/check-review-evidence.sh
bash scripts/check-subagent-evidence.sh
bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

## Typical Workflow

1. Open the target repository in an AI coding agent.
2. Ask it to read `AGENTS.md` or `CLAUDE.md`.
3. Define scoped work in `.agent/task.yml`.
4. Run `scripts/agent-preflight.sh`.
5. Make changes within the task boundaries.
6. Run `scripts/agent-finish.sh`.
7. Update `handoff.md` with changed files, verification results, blockers, and
   the next recommended action.

## Context Loading Policy

Agent-Repo-Harness is designed for staged context loading. Agents should read
compact, durable context first:

1. `AGENTS.md` or the installed adapter entrypoint
2. `agent.md`
3. `handoff.md`
4. `.agent/task.yml`
5. applicable `.agent/policy.yml` entries

They can then expand with `rg`, file lists, and targeted file ranges for the
active task. `scripts/collect-context.sh` prints compact startup context by
default; `scripts/collect-context.sh --full` includes optional known issues
and discoveries for deeper debugging.

## Agent Compatibility

Codex:

- install or copy `templates/AGENTS.md` to the target repository root
- see [docs/codex-usage.md](docs/codex-usage.md)
- reusable prompt: `adapters/codex/codex-start-prompt.md`
- optional lifecycle prompts, not auto-installed into target repositories:
  `adapters/codex/codex-repair-prompt.md`,
  `adapters/codex/codex-verify-prompt.md`, and
  `adapters/codex/codex-handoff-prompt.md`

Claude Code:

- install or copy `templates/CLAUDE.md` to the target repository root
- optional project skills live under
  `adapters/claude-code/.claude/skills/`

Generic AI coding agents:

- read `AGENTS.md`
- inspect `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable
  `.agent/policy.yml` entries
- run the scripts directly

Superpowers-compatible agents remain supported. The existing skills in
`skills/` provide workflow discipline such as planning, TDD, delegation,
review, and branch finishing; this harness supplies repo-local contracts,
gates, and evidence. See
[docs/superpowers-integration.md](docs/superpowers-integration.md).

See [docs/USAGE_WITH_AGENTS.md](docs/USAGE_WITH_AGENTS.md) and
[docs/agent-support-matrix.md](docs/agent-support-matrix.md) for detailed
agent workflows and support boundaries.

## Repository Contents

- `templates/`: files copied into target repositories
- `templates/scripts/`: dependency-light gates and validators
- `skills/`: Superpowers-compatible skills
- `adapters/`: agent-specific entrypoints and skill layouts
- `schemas/`: JSON Schemas for harness, policy, task, and handoff structures
- `examples/`: example installed shapes and task flows
- `install-agent-harness.sh`: template installer
- `validate-harness.sh`: repository validation and smoke tests

## Validation

Validation runs in CI on every push and pull request. Run the same repository
validation locally with:

```bash
bash validate-harness.sh
```

Validation checks script syntax, YAML and JSON syntax, required harness files,
install smoke tests, local document links, scope and policy behavior,
configured verification, subagent packet/run validation, TDD evidence
behavior, acceptance/review gate behavior, and finish evidence creation.
