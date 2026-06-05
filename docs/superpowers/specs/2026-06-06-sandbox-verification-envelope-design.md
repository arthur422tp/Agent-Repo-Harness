# Sandbox Verification Envelope Design

## Goal

Add a sandbox verification layer to Agent-Repo-Harness that strengthens final
verification evidence without replacing obra/superpowers workflows or claiming
to be a full agent runtime.

The first version should prove that a configured harness command can run in an
external isolated environment, record durable evidence, and optionally become a
completion requirement.

## Product Boundary

The sandbox feature is a verification envelope, not an orchestration engine.

Superpowers remains responsible for planning, TDD, subagent-driven development,
verification discipline, and branch finishing. Agent-Repo-Harness remains
responsible for repo-local task contracts, policy gates, verification gates,
and evidence. The sandbox envelope only adds an external execution boundary for
selected verification commands.

The feature must not describe itself as a complete sandbox by default. Security
depends on the configured external runner, host platform, container runtime,
mount policy, and network settings.

## Recommended Approach

Implement a `Sandbox Verification Envelope` with Docker or Podman as the first
runner target.

This approach gives immediate value for reproducible final verification and
repo-contained writes while avoiding a false promise of complete runtime
control. It fits the current shell/Python architecture and can be tested with
the existing harness validation suites.

Rejected alternatives:

- Worktree-only sandbox: useful for clean working directories, but it does not
  provide process, network, or environment isolation.
- Full custom runtime sandbox: too broad for the current repo-local harness and
  likely to create misleading security claims.
- CI-only sandbox: strong for release confidence, but slower and less useful
  for local agent workflows.

## Configuration Contract

Add an optional `sandbox` section to `.agent/harness.yml`:

```yaml
sandbox:
  enabled: false
  runner: docker
  mode: verification
  command: "bash scripts/agent-finish.sh --strict"
  workspace:
    strategy: "copy"
  network: "disabled"
  env:
    allow: []
  resource_limits:
    cpus: "2"
    memory: "2g"
    timeout_seconds: 600
```

Supported first-version values:

- `enabled`: boolean.
- `runner`: `docker` or `podman`.
- `mode`: `verification`.
- `command`: shell command to run inside the sandbox workspace.
- `workspace.strategy`: `copy`.
- `network`: `disabled` or `host`.
- `env.allow`: list of explicit environment variable names to pass through.
- `resource_limits.cpus`: string passed to the container runner.
- `resource_limits.memory`: string passed to the container runner.
- `resource_limits.timeout_seconds`: integer local timeout for the sandbox run.

Do not implement network allowlists, secret manager integrations, or per-tool
permissions in the first version.

## Task Completion Contract

Add an optional completion flag to `.agent/task.yml`:

```yaml
task:
  completion:
    requires_sandbox_verification: false
```

When the flag is false or missing, sandbox verification is optional. When true,
`scripts/agent-finish.sh` must require a passing sandbox run evidence directory.

The flag should validate as a boolean in `schemas/task.schema.json` and
`scripts/validate-task.sh`.

## Command Interface

Add a proposed runner entrypoint named `agent-sandbox-run.sh` under the
installed `scripts/` directory:

```bash
agent-sandbox-run.sh [--strict|--best-effort]
```

The command should:

1. Read `.agent/harness.yml` sandbox configuration with `scripts/lib/read-yaml.py`.
2. Exit with a clear skip result when sandbox is disabled.
3. Fail clearly when sandbox is enabled but the configured runner is missing.
4. Create a temporary workspace copy outside the source checkout.
5. Run the configured command inside Docker or Podman.
6. Use no host network when `network: disabled`.
7. Pass no host environment except explicit `env.allow` values.
8. Apply configured CPU, memory, and timeout limits when available.
9. Copy durable evidence back to the source checkout.
10. Exit non-zero when the sandbox command fails.

The command must not stage, commit, push, delete worktrees, delete source repo
files, or mutate files outside its own temporary workspace and evidence output.

## Evidence Contract

Sandbox runs write to:

```text
.agent/sandbox-runs/<timestamp>/
  command.txt
  stdout.txt
  stderr.txt
  exit-status.txt
  sandbox-summary.json
```

`sandbox-summary.json` should contain:

```json
{
  "timestamp": "20260606-000000",
  "runner": "docker",
  "mode": "verification",
  "command": "bash scripts/agent-finish.sh --strict",
  "network": "disabled",
  "workspace_strategy": "copy",
  "exit_status": 0,
  "overall_result": "pass",
  "evidence": {
    "stdout": ".agent/sandbox-runs/20260606-000000/stdout.txt",
    "stderr": ".agent/sandbox-runs/20260606-000000/stderr.txt",
    "command": ".agent/sandbox-runs/20260606-000000/command.txt"
  }
}
```

Evidence files should avoid recording full host environment values. If allowed
environment variables are listed, record only their names, not their values.

## Finish Gate Integration

Add a proposed evidence-check entrypoint named `check-sandbox-evidence.sh`
under the installed `scripts/` directory:

```bash
check-sandbox-evidence.sh
```

The check should:

1. Read `.agent/task.yml`.
2. Skip when `task.completion.requires_sandbox_verification` is false or
   missing.
3. Require at least one `.agent/sandbox-runs/*/sandbox-summary.json`.
4. Select the newest sandbox run by path sort.
5. Require `overall_result: pass`.
6. Require `exit_status: 0`.
7. Print `SANDBOX_EVIDENCE_RESULT=pass` or `SANDBOX_EVIDENCE_RESULT=fail`.

`scripts/agent-finish.sh` should run `check-sandbox-evidence.sh` as another
optional gate and include the result in:

- `finish-summary.md`
- `finish-summary.json`
- `.agent/runs/<timestamp>/sandbox-evidence-result.txt`

Avoid running `agent-sandbox-run.sh` from inside `agent-finish.sh` by default.
The finish gate should validate evidence, not create a nested finish run unless
a later design explicitly adds that behavior.

## Superpowers Integration

The sandbox envelope should be documented as a verification enhancement for
Superpowers:

- `verification-before-completion`: run the sandbox runner entrypoint when the
  task requires sandbox verification or when the user requests isolated
  verification.
- `finishing-a-development-branch`: expect sandbox evidence to appear in
  `scripts/agent-finish.sh` output when required.
- `using-git-worktrees`: remains responsible for isolated development
  workspaces; sandbox verification does not replace worktrees.
- `subagent-driven-development`: remains responsible for subagent orchestration;
  sandbox verification only checks final repo-level evidence.

Update `docs/superpowers-integration.md` and relevant local skills to make this
split explicit.

## Error Handling

The first version should use explicit, boring errors:

- Missing Docker or Podman: fail with the configured runner name.
- Unsupported runner: fail and list supported values.
- Unsupported network mode: fail and list supported values.
- Missing `.agent/harness.yml`: skip when sandbox is disabled by absence.
- Sandbox command timeout: fail and record timeout in `sandbox-summary.json`.
- Sandbox command exit non-zero: fail and preserve stdout/stderr evidence.
- Evidence malformed: `check-sandbox-evidence.sh` fails.

## Testing Strategy

Tests should not require Docker or Podman for the full `bash validate-harness.sh`
path. Use fake runner scripts in temporary fixture directories to validate
command construction, evidence writing, skip semantics, failure semantics, and
finish gate integration.

Add focused suites:

- `tests/harness/sandbox-runner.sh`
- `tests/harness/sandbox-evidence.sh`

Required test cases:

- sandbox disabled skips cleanly
- enabled runner missing fails clearly
- fake runner pass writes all evidence files
- fake runner failure writes stdout, stderr, exit status, and JSON
- `network: disabled` maps to a no-network runner argument
- environment allowlist records names only
- sandbox evidence gate skips by default
- sandbox evidence gate passes with newest passing summary
- sandbox evidence gate fails with newest failing summary
- task validation accepts `requires_sandbox_verification`
- install copies new scripts and schema updates

## Documentation Updates

Update:

- `README.md`
- `README.zh-TW.md`
- `docs/runtime-boundaries.md`
- `docs/USAGE_WITH_AGENTS.md`
- `docs/superpowers-integration.md`
- `templates/AGENTS.md`
- `templates/CLAUDE.md`
- `skills/verification-gate/SKILL.md`
- `skills/harness-entrypoint/SKILL.md`

Public wording must say that the harness can run verification in an external
container sandbox when configured. It must not claim complete isolation,
network security, secret protection, or semantic correctness.

## Success Criteria

- Existing `bash validate-harness.sh` passes without requiring Docker or
  Podman.
- Sandbox runner tests pass with fake runner fixtures.
- Installed templates include the sandbox scripts and config.
- `agent-finish.sh` can require sandbox evidence through `.agent/task.yml`.
- Documentation preserves the Superpowers responsibility split.
- Runtime boundary docs clearly list what sandbox verification implements and
  what it does not implement.
