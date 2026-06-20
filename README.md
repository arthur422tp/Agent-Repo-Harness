# Agent-Repo-Harness

[English](README.md) | [繁體中文](README.zh-TW.md)

[![CI](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml)

**Agent-Repo-Harness is a repo-local completion gate for AI coding agents.**

It gives Codex, Claude Code, and generic AI coding agents a small set of
repo-owned contracts and scripts to check work before claiming it is complete.
It helps AI coding agents avoid claiming completion without:

- staying inside task scope
- passing policy checks
- running verification
- leaving durable run evidence and concise continuity notes

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

## Choose A Gate Profile

Profiles are recommendations expressed through existing `.agent/task.yml`
flags; the harness does not read a profile name or enable gates automatically.

- **Minimal:** scope, policy, verification, and handoff expectation for small,
  low-risk maintenance.
- **Standard:** Minimal plus TDD for behavior changes, with acceptance or review
  evidence when the task requires it.
- **High-Risk:** Standard plus only the architecture, command ledger, sandbox,
  subagent, failure-attribution, or intervention evidence that answers a named
  risk.

See [Gate Guide](docs/agent/gate-guide.md) for the decision matrix, profile
examples, evidence files, and failure meanings.

## Guardrails, Not A Sandbox

Scope and policy gates are process guardrails, not security boundaries. They
inspect Git changes and repo-local policy patterns; they do not isolate the
filesystem, network, secrets, or command side effects, and they do not
guarantee semantic correctness.

## Resource Envelope

Agent-Repo-Harness can enforce local finish-run limits for maximum finish
duration and maximum changed-file count:

```yaml
runtime:
  resource_limits:
    max_finish_seconds: 300
    max_changed_files: 20
```

A value of `0` disables that limit. These limits are local shell-run controls
and do not measure provider tokens or hosted model cost.

For the full runtime boundary, see [docs/runtime-boundaries.md](docs/runtime-boundaries.md).

## How It Works

The harness keeps stable repository facts separate from current task state:

- `agent.md`: stable repository map and operating rules
- `handoff.md`: human-readable current task handoff and next action
- `.agent/handoff.yml`: optional machine-readable handoff state
- `.agent/task.yml`: machine-readable current task scope and enabled gates
- `.agent/policy.yml`: repo-local policy checks and protected paths
- `.agent/tdd-evidence.yml`: optional structured TDD evidence
- `.agent/acceptance.yml`: optional acceptance criteria evidence
- `.agent/review.yml`: optional review evidence
- `.agent/episode.yml`: optional episode package metadata
- `.agent/failure-attribution.yml`: optional failure attribution evidence
- `.agent/interventions.yml`: optional intervention record
- `.agent/subagent-packet.yml`: optional controller-to-subagent handoff packet
- `.agent/subagent-runs/`: optional durable evidence from delegated runs

Installed entrypoints are `AGENTS.md` and `CLAUDE.md`. Agents use these files
with the durable context above, then finish work through
`scripts/agent-finish.sh`.

## Evidence Vs Handoff

`.agent/runs/<timestamp>/` is the authoritative completion evidence produced
by `scripts/agent-finish.sh`. It records the command, mode, gate results,
verification output, changed files, and diff summary for a specific finish run.

Each finish run also writes `finish-summary.json`, a machine-readable summary
with the run directory, mode, overall result, gate statuses, changed-file
evidence, diff-stat evidence, elapsed seconds, and the reserved
resource-envelope result.
Use the JSON file for tools and CI; use the Markdown and text files for human
debugging.

`handoff.md` is a model-authored continuity artifact for humans and future
agents. It should summarize what changed, which run evidence to inspect, what
passed, what remains open, and the next recommended action. `.agent/handoff.yml`
is an optional structured mirror of that continuity state for tools that want a
machine-readable handoff.

`.agent/task.yml` may set `completion.expects_handoff_update: true` to document
that the workflow expects a handoff update after finishing. This is advisory:
`agent-finish.sh` does not enforce handoff freshness.

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

`agent-finish.sh` writes authoritative evidence under
`.agent/runs/<timestamp>/`, including `finish-summary.md`,
`finish-summary.json`, per-check result files, changed files, and diff stat.

Optional evidence gates remain disabled by default. Enable one only when it
answers a concrete completion risk. The available categories cover TDD,
acceptance, review, architecture, failure attribution, interventions, command
ledger, sandbox verification, and delegated subagent runs.

Use [Gate Guide](docs/agent/gate-guide.md) for detailed flag selection and
evidence requirements. See [Handoff And Evidence](docs/handoff.md) for the
difference between run evidence and continuity notes, and
[Runtime Boundaries](docs/runtime-boundaries.md) for containment and tracing
limits.

## Useful Commands

Run individual checks when diagnosing a task or integrating the harness:

```bash
bash scripts/agent-preflight.sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/validate-handoff.sh
bash scripts/validate-subagent-packet.sh
bash scripts/check-doc-links.sh
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/check-tdd-evidence.sh
bash scripts/check-acceptance.sh
bash scripts/check-review-evidence.sh
bash scripts/check-architecture-evidence.sh
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
   the next recommended action. Optionally mirror structured state in
   `.agent/handoff.yml`.

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
