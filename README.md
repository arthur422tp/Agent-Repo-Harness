# Agent-Repo-Harness

[繁體中文](README.zh-TW.md)

[![CI](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml)

**Agent-Repo-Harness is a repo-local completion gate for AI coding agents.**

It makes task scope, policy, repository-owned verification, and durable finish
evidence explicit before an agent claims completion. It is not a sandbox, a
full agent runtime, or a semantic correctness guarantee.

Current version: `0.2.0`. See [CHANGELOG.md](CHANGELOG.md),
[versioning](docs/versioning.md), and the [stability contract](docs/stability-contract.md)
for release and interface details.

## Quick Start

Preview the installer, install the harness into a target repository, then
commit a clean baseline before asking an agent to change product files:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
cd /path/to/target-repo
git add AGENTS.md CLAUDE.md agent.md handoff.md .agent docs/agent scripts schemas
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

Platform Support: the primary supported environments are Linux, macOS, WSL, and Git Bash. The
harness targets Unix-like shell environments; native PowerShell support is not
currently a goal.

## Configure The Repository

After installation, fill in the repository-owned context and controls:

- `agent.md` describes stable repository facts and operating rules.
- `.agent/harness.yml` defines authoritative verification commands.
- `.agent/policy.yml` defines protected paths and approval rules.
- `handoff.md` records the current human-readable continuity state.

Prefer repo-defined commands over language heuristics. repo-defined commands are authoritative, and projects without them retain heuristic fallback behavior.

```yaml
# .agent/harness.yml
verification:
  required:
    - name: unit-tests
      command: uv run pytest
    - name: lint
      command: uv run ruff check .
```

Use a verification profile when a staged task needs only the commands that
exist at its current delivery stage:

```yaml
verification:
  profiles:
    bootstrap:
      required:
        - name: package-import
          command: uv run python -c "import package_name"
```

```yaml
# .agent/task.yml
task:
  verification_profile: bootstrap
```

`task.verification_profile` replaces `verification.required`; it does not
merge with the default command set. Use final or release profiles only after
their tests, CLI, build, and lint targets exist.

## Run The First Task

Use the installed agent entrypoint and durable context first: `AGENTS.md` or
`CLAUDE.md`, `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable
`.agent/policy.yml` entries. The applicable `.agent/policy.yml` entries are
loaded for the active task. Then follow this lifecycle:

1. Generate scoped task state with `scripts/agent-task-profile.sh`.
2. Run `scripts/agent-preflight.sh`.
3. Implement only within the generated task boundaries.
4. Run the canonical `scripts/agent-finish.sh` gate.
5. Inspect `.agent/runs/<timestamp>/finish-summary.json` and its related result files.
6. If strict acceptance is enabled, bind the run artifacts with
   `scripts/agent-evidence-bind.sh` and rerun the acceptance and finish checks.
7. Update `handoff.md` with changed files, verification results, blockers, and
   the next recommended action before claiming completion.

For a typical task, the helper-first command path is:

```bash
bash scripts/agent-task-profile.sh standard \
  --goal "Implement the current task" \
  --current-task "Complete the scoped change" \
  --allowed "src/**" \
  --allowed "tests/**" \
  --verification-profile feature
bash scripts/agent-preflight.sh
bash scripts/agent-finish.sh
```

The finish gate checks local scope and policy rules, applies enabled evidence
gates, runs verification, and records durable evidence. `finish-summary.json`
is the machine-readable summary; the surrounding Markdown and text files are
for human debugging.

### Evidence Vs Handoff

`.agent/runs/<timestamp>/` is authoritative evidence for a specific finish
run. `handoff.md` is a model-authored continuity artifact for humans and future
agents; `.agent/handoff.yml` is an optional structured mirror. A task may set
`completion.expects_handoff_update: true` to document the expectation, but
`agent-finish.sh` does not enforce handoff freshness.

## When Finish Fails

Do not claim completion after a failed finish run. Read the failed result and
follow [Repair Failed Finish Runs](docs/agent/repair-failed-run.md):

1. Identify the failed gate and inspect its evidence file.
2. Repair the task, configuration, or evidence that caused the failure.
3. Rerun `scripts/agent-finish.sh` and inspect the newest run directory.
4. Bind strict acceptance evidence only after the referenced run passes.
5. Update `handoff.md` with the repair outcome and remaining blockers.

Evidence references improve traceability but do not prove semantic correctness
beyond the configured checks. See [Handoff And Evidence](docs/handoff.md) for
the evidence/continuity distinction.

## Choose An Adoption Path

Agent-Repo-Harness supports both greenfield projects and repositories already
in progress. Choose the path that matches the repository baseline.

### Greenfield Project

1. Install the harness immediately after creating the repository.
2. Fill `agent.md` with the intended repository shape and coding rules.
3. Set `.agent/harness.yml` to the first real verification commands.
4. Configure `.agent/policy.yml` for protected paths.
5. Commit the harness files with the initial project scaffold.
6. Generate a Minimal, Standard, or selective High-Risk task profile for each
   change, then finish through `scripts/agent-finish.sh`.

### Existing Or Mid-Development Project

1. Run `--dry-run` first and review conflicts with existing entrypoints,
   scripts, docs, and `.agent/` files.
2. Use `--backup` or `--force` only after reviewing those conflicts.
3. Fill `agent.md` from concrete repository facts and keep `handoff.md` focused
   on the current state.
4. Define the project's real test, lint, build, or type-check commands.
5. Commit the harness scaffold as a clean baseline before feature work.

For unfinished product changes, use a separate branch or worktree when
possible. Otherwise commit or stash unrelated work before installing the
harness so `check-scope.sh` can distinguish the scaffold from feature changes.

## Choose Verification And Gates

Task profiles are recommendations rendered into `.agent/task.yml`; the harness
enforces the resulting flags rather than reading a profile name at finish time.

- **Minimal** covers scope, policy, verification, and handoff expectation for
  small, low-risk maintenance.
- **Standard** adds TDD for behavior changes and evidence when the task needs it.
- **High-Risk** adds only the architecture, command ledger, sandbox, subagent,
  failure-attribution, or intervention evidence that answers a named risk.

Use [Gate Guide](docs/agent/gate-guide.md) for the decision matrix, profile
examples, evidence requirements, and failure meanings. Optional evidence gates
remain disabled by default; enable one only when it answers a concrete
completion risk.

## Architecture And Boundaries

The harness keeps stable repository facts separate from current task state:

- repository facts and operating rules live in `agent.md`;
- current task scope and enabled gates live in `.agent/task.yml`;
- policy and protected paths live in `.agent/policy.yml`;
- finish orchestration produces immutable per-run evidence under
  `.agent/runs/<timestamp>/`;
- `handoff.md` records mutable continuity notes for the next person or agent.

The finish gate is a process boundary. Guardrails, Not A Sandbox: scope and
policy are process guardrails, not security boundaries. The harness does not isolate the filesystem, network,
secrets, provider tokens, or model cost. See [Runtime Boundaries](docs/runtime-boundaries.md)
for implemented and not implemented capabilities.

The local Resource Envelope can cap finish duration and changed-file count; it
does not measure provider tokens or hosted model cost. Command-ledger,
sandbox-verification, architecture-sensor, episode, failure-attribution, and
intervention evidence are selective local contracts rather than provider-native
runtime tracing.

## Examples And References

Start with the examples that match the task:

- [Docs-only change](examples/docs-only-change/README.md)
- [Bugfix with strict evidence refs](examples/bugfix-with-evidence-refs/README.md)
- [High-risk policy change](examples/high-risk-policy-change/README.md)
- [RAG contract adoption fixture](examples/rag-contract-system/README.md)

For deeper usage, see:

- [Usage With Agents](docs/USAGE_WITH_AGENTS.md)
- [Gate Guide](docs/agent/gate-guide.md)
- [Architecture Sensors](docs/agent/architecture-sensors.md)
- [Codex usage](docs/codex-usage.md)
- [Agent support matrix](docs/agent-support-matrix.md)
- [Public packaging](docs/public-packaging.md)

Run the same repository validation used by CI with:

```bash
bash validate-harness.sh
```

Validation covers script syntax, config and task schemas, install smoke tests,
document links, scope and policy behavior, configured verification, evidence
gates, finish evidence creation, examples, and stability-contract checks.
