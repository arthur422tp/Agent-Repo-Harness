# v0.1.0 Release And Sandbox Smoke Readiness Design

## Goal

Prepare Agent-Repo-Harness for a v0.1.0 public release while adding a narrow,
real sandbox verification smoke path that can run locally or in CI when Docker
or Podman is available.

## Scope

This phase combines public release readiness with sandbox smoke hardening. It
does not add provider-native tracing, token accounting, model-cost enforcement,
tool-call replay, or a full agent runtime. It also does not change the core
runtime boundary: Agent-Repo-Harness remains a repo-local completion harness,
and sandbox verification remains an external runner envelope.

## Architecture

The release checklist in `docs/public-packaging.md` remains the source of truth
for v0.1.0 readiness. The implementation should mark only items that are
proven by repository files or commands. GitHub repository metadata and release
tag creation remain human publishing steps unless they are explicitly performed.

Sandbox smoke verification should use an installed temporary target rather than
the source checkout. The source repository is a template/package source and
does not expose root-level installed `scripts/` in normal operation. The smoke
path installs the harness into a temporary repository, enables sandbox
verification there, runs `scripts/agent-sandbox-run.sh`, then runs
`scripts/agent-finish.sh` to validate the produced sandbox evidence.

CI should keep the existing `bash validate-harness.sh` job and add an explicit
sandbox smoke step or job. The sandbox smoke result must be visible in logs as
one of `SANDBOX_CI_SMOKE_RESULT=pass`, `SANDBOX_CI_SMOKE_RESULT=skip`, or
`SANDBOX_CI_SMOKE_RESULT=fail`.

## Components

### Release Readiness Checklist

`docs/public-packaging.md` should distinguish between repository-verifiable
release readiness and external publishing actions.

Repository-verifiable examples include:

- `VERSION` is `0.1.0`.
- `CHANGELOG.md` has a `v0.1.0` entry and usable release-note content.
- `README.md` has the required public sections and CI badge.
- `docs/handoff.md` explains the handoff and run evidence model.
- `install-agent-harness.sh` prints the short three-step next path.
- The default TDD evidence gate is opt-in.
- `bash validate-harness.sh` passes locally.
- Sandbox smoke has a documented pass or skip result.

External publishing examples include:

- GitHub repository description and topics.
- GitHub release tag creation.
- Manual verification of README rendering on GitHub.
- Final confirmation that the CI badge points at the published workflow.

### Sandbox Smoke Command

The smoke command should be a repo-owned script or harness test helper with one
clear responsibility: prove the installed sandbox verification path works when
a compatible external runner is available.

The command should:

1. Create a temporary target repository.
2. Install Agent-Repo-Harness into that target with `install-agent-harness.sh`.
3. Configure `.agent/harness.yml` in the target with sandbox enabled.
4. Configure `.agent/task.yml` with `completion.requires_sandbox_verification:
   true`.
5. Run `scripts/agent-sandbox-run.sh`.
6. Verify that `.agent/sandbox-runs/<timestamp>/sandbox-summary.json` exists and
   records `overall_result: pass`.
7. Run `scripts/agent-finish.sh --best-effort` or `--strict` in the installed
   target to prove the finish gate validates the sandbox evidence.
8. Print `SANDBOX_CI_SMOKE_RESULT=pass`, `skip`, or `fail`.

If neither Docker nor Podman is available, the command should print
`SANDBOX_CI_SMOKE_RESULT=skip` and exit 0. If a runner is available but the
sandbox run or evidence validation fails, it should print
`SANDBOX_CI_SMOKE_RESULT=fail` and exit nonzero.

### CI Integration

`.github/workflows/ci.yml` should run the sandbox smoke command after the normal
harness validation. The CI output must make the sandbox smoke state explicit.

A skip is acceptable only for missing external runner availability. It is not
acceptable for malformed configuration, missing evidence, failing sandbox
commands, or finish-gate failures.

### Documentation And Evidence

`README.md`, `CHANGELOG.md`, `docs/public-packaging.md`, and `handoff.md` should
tell the same story:

- v0.1.0 is a repo-local completion harness release.
- External sandbox verification is available as an opt-in smoke-tested path.
- The harness does not provide filesystem isolation, network isolation, secret
  isolation, complete sandbox security, provider-native trace capture, or
  model-cost enforcement.
- Release readiness is supported by validation, audit, sandbox smoke, and
  checklist evidence.

## Data Flow

The intended release verification flow is:

```text
install-agent-harness.sh
  -> temporary installed target
  -> enable sandbox config and requires_sandbox_verification
  -> scripts/agent-sandbox-run.sh
  -> .agent/sandbox-runs/<timestamp>/sandbox-summary.json
  -> scripts/agent-finish.sh
  -> .agent/runs/<timestamp>/finish-summary.json
  -> docs/public-packaging.md and handoff.md evidence
```

## Error Handling

The sandbox smoke result contract is:

- `SANDBOX_CI_SMOKE_RESULT=pass`: external runner is available, sandbox run
  passes, sandbox summary exists, and finish gate validates the evidence.
- `SANDBOX_CI_SMOKE_RESULT=skip`: Docker and Podman are unavailable. This is an
  acceptable release-readiness state only when clearly recorded.
- `SANDBOX_CI_SMOKE_RESULT=fail`: a runner is available but execution,
  evidence, or finish validation fails.

The command should fail closed when it sees contradictory state. For example,
an existing runner with missing `sandbox-summary.json` is a failure, not a
skip.

## Testing Strategy

Implementation should use TDD and keep the main validation independent of
host-level Docker or Podman availability.

Required checks:

- `bash validate-harness.sh` covers fake-runner and no-runner sandbox smoke
  behavior.
- The CI workflow runs the sandbox smoke command and leaves a visible result
  marker.
- `bash templates/scripts/agent-audit.sh` passes from the source checkout.
- Doc-link validation passes after README, checklist, and release-note updates.
- Final git status is clean except expected untracked `.agent/` runtime
  evidence if local audit or finish commands generated it.

## Release Boundary

This phase should not expand into v0.2 runtime work. Provider traces,
tool-call replay, token accounting, cost enforcement, secret manager
integration, and stronger sandbox security should remain documented as future
work unless the user explicitly starts a separate design cycle.

## Acceptance Criteria

- v0.1.0 checklist items that are provable from the repository are marked
  complete with evidence.
- External publishing actions remain separate and are not marked complete
  unless actually performed.
- CI includes a visible sandbox smoke result.
- Sandbox smoke distinguishes pass, skip, and fail without hiding runner
  failures.
- Runtime boundary documentation remains truthful.
- Full local validation passes.
