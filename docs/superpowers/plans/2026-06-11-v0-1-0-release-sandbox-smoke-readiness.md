# v0.1.0 Release And Sandbox Smoke Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make v0.1.0 public-release readiness verifiable while adding a narrow sandbox smoke path that passes or explicitly skips when Docker or Podman is unavailable.

**Architecture:** Keep `bash validate-harness.sh` as the main repo validation entrypoint and add a standalone `ci/sandbox-smoke.sh` command for installed-target sandbox smoke. The smoke command installs the harness into a temporary target, enables sandbox verification there, runs `scripts/agent-sandbox-run.sh`, then runs `scripts/agent-finish.sh` to validate the produced evidence. Release checklist updates stay evidence-backed and do not mark external GitHub publishing actions complete unless they are actually performed.

**Tech Stack:** POSIX-ish Bash, Python standard library, GitHub Actions, existing harness shell tests, `install-agent-harness.sh`, Docker or Podman when available.

---

## Approved Spec

Design source:

- `docs/superpowers/specs/2026-06-11-v0-1-0-release-sandbox-smoke-design.md`

This plan intentionally excludes provider-native tracing, token accounting,
model-cost enforcement, full tool-call replay, secret manager integration, and
stronger sandbox security. Those remain future v0.2+ work unless a new design
cycle starts.

## File Structure

Create:

- `ci/sandbox-smoke.sh`: standalone CI/local sandbox smoke command. It creates a temporary installed target, enables sandbox verification, runs sandbox evidence generation, validates finish evidence, and prints `SANDBOX_CI_SMOKE_RESULT=pass|skip|fail`.
- `tests/harness/sandbox-ci-smoke.sh`: validation suite for the smoke command's no-runner skip, fake-runner pass, and fake-runner failure behavior.

Modify:

- `validate-harness.sh`: source `tests/harness/sandbox-ci-smoke.sh` after `tests/harness/sandbox-runner.sh`.
- `.github/workflows/ci.yml`: run `bash ci/sandbox-smoke.sh` after `bash validate-harness.sh`.
- `tests/harness/doc-consistency.sh`: assert release readiness checklist and sandbox smoke wording stay present.
- `docs/public-packaging.md`: mark repository-verifiable v0.1.0 release items complete and keep external publishing actions separate.
- `CHANGELOG.md`: fold current Unreleased items into the v0.1.0 release notes or otherwise make the release-note source unambiguous.
- `README.md`: add only the minimal public wording needed for sandbox smoke evidence if missing after checklist review.
- `handoff.md`: record the new validation, audit, sandbox smoke, and release-readiness status after implementation.

## Task 1: Sandbox Smoke Command Contract

**Files:**
- Create: `tests/harness/sandbox-ci-smoke.sh`
- Modify: `validate-harness.sh`

- [x] **Step 1: Write failing validation tests for the smoke command**

Create `tests/harness/sandbox-ci-smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Sandbox CI smoke skips when no runner is available =="
sandbox_ci_skip_root="$tmp_root/sandbox-ci-skip"
rm -rf "$sandbox_ci_skip_root"
mkdir -p "$sandbox_ci_skip_root/bin"
(
  cd "$sandbox_ci_skip_root"
  if HARNESS_SANDBOX_SMOKE_FORCE_NO_RUNNER=1 \
    bash "$repo_root/ci/sandbox-smoke.sh" > sandbox-ci-skip.log 2>&1
  then
    assert_contains sandbox-ci-skip.log "SANDBOX_CI_SMOKE_RESULT=skip"
    assert_contains sandbox-ci-skip.log "Docker or Podman is unavailable."
  else
    echo "ERROR: expected missing runner to skip without failing"
    cat sandbox-ci-skip.log
    exit 1
  fi
)
pass "sandbox CI smoke skips when no runner is available"

echo
echo "== Sandbox CI smoke fake runner pass validates finish evidence =="
sandbox_ci_pass_root="$tmp_root/sandbox-ci-pass"
rm -rf "$sandbox_ci_pass_root"
mkdir -p "$sandbox_ci_pass_root/bin"
(
  cd "$sandbox_ci_pass_root"
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > fake-docker-args.txt
printf '%s\n' "fake sandbox verification stdout"
exit 0
SH
  chmod +x bin/fake-docker

  HARNESS_SANDBOX_SMOKE_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_SMOKE_RUNNER_NAME="docker" \
    bash "$repo_root/ci/sandbox-smoke.sh" > sandbox-ci-pass.log 2>&1

  assert_contains sandbox-ci-pass.log "SANDBOX_CI_SMOKE_RESULT=pass"
  assert_contains sandbox-ci-pass.log "Sandbox smoke target:"
  assert_contains sandbox-ci-pass.log "Sandbox smoke run:"
  assert_contains sandbox-ci-pass.log "Finish evidence run:"

  target_root="$(awk -F': ' '/Sandbox smoke target:/ { print $2 }' sandbox-ci-pass.log | tail -n 1)"
  assert_exists "$target_root/.agent/sandbox-runs"
  assert_exists "$target_root/.agent/runs"
  sandbox_summary="$(find "$target_root/.agent/sandbox-runs" -type f -name sandbox-summary.json | sort | tail -n 1)"
  assert_exists "$sandbox_summary"
  assert_contains "$sandbox_summary" '"overall_result": "pass"'
  assert_file_contains "$target_root" "finish-summary.md" "Overall result: pass"
  assert_file_contains "$target_root" "sandbox-evidence-result.txt" "SANDBOX_EVIDENCE_RESULT=pass"
)
pass "sandbox CI smoke fake runner pass validates finish evidence"

echo
echo "== Sandbox CI smoke fake runner failure is blocking =="
sandbox_ci_fail_root="$tmp_root/sandbox-ci-fail"
rm -rf "$sandbox_ci_fail_root"
mkdir -p "$sandbox_ci_fail_root/bin"
(
  cd "$sandbox_ci_fail_root"
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "fake sandbox failure" >&2
exit 42
SH
  chmod +x bin/fake-docker

  if HARNESS_SANDBOX_SMOKE_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_SMOKE_RUNNER_NAME="docker" \
    bash "$repo_root/ci/sandbox-smoke.sh" > sandbox-ci-fail.log 2>&1
  then
    echo "ERROR: expected sandbox smoke failure"
    cat sandbox-ci-fail.log
    exit 1
  fi

  assert_contains sandbox-ci-fail.log "SANDBOX_CI_SMOKE_RESULT=fail"
  assert_contains sandbox-ci-fail.log "Sandbox smoke failed."
)
pass "sandbox CI smoke fake runner failure is blocking"
```

- [x] **Step 2: Source the new failing suite**

In `validate-harness.sh`, add this line immediately after
`tests/harness/sandbox-runner.sh`:

```bash
source "$repo_root/tests/harness/sandbox-ci-smoke.sh"
```

- [x] **Step 3: Run validation to verify the command is missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `Sandbox CI smoke skips when no runner is available` because
`ci/sandbox-smoke.sh` does not exist yet.

## Task 2: Implement The Sandbox Smoke Command

**Files:**
- Create: `ci/sandbox-smoke.sh`

- [x] **Step 1: Add the standalone smoke command**

Create `ci/sandbox-smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-sandbox-smoke.XXXXXX")"
target_root="$tmp_root/target"
keep_target="${HARNESS_SANDBOX_SMOKE_KEEP_TARGET:-0}"
force_no_runner="${HARNESS_SANDBOX_SMOKE_FORCE_NO_RUNNER:-0}"

cleanup() {
  if [ "$keep_target" != "1" ]; then
    rm -rf "$tmp_root"
  fi
}

trap cleanup EXIT

find_runner() {
  if [ "$force_no_runner" = "1" ]; then
    return 1
  fi
  if [ -n "${HARNESS_SANDBOX_SMOKE_RUNNER_BIN:-}" ]; then
    printf '%s\n' "$HARNESS_SANDBOX_SMOKE_RUNNER_BIN"
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    printf '%s\n' "docker"
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then
    printf '%s\n' "podman"
    return 0
  fi
  return 1
}

runner_bin=""
if ! runner_bin="$(find_runner)"; then
  echo "Docker or Podman is unavailable."
  echo "SANDBOX_CI_SMOKE_RESULT=skip"
  exit 0
fi

runner_name="${HARNESS_SANDBOX_SMOKE_RUNNER_NAME:-}"
if [ -z "$runner_name" ]; then
  runner_name="$(basename "$runner_bin")"
fi

case "$runner_name" in
  docker|podman) ;;
  *)
    echo "ERROR: unsupported sandbox smoke runner name: $runner_name"
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
    ;;
esac

mkdir -p "$target_root"
(
  cd "$target_root"
  git init -q
  git config user.email "agent-harness@example.invalid"
  git config user.name "Agent Harness Smoke"
  printf '%s\n' "# Sandbox Smoke Target" > README.md
  git add README.md
  git commit -q -m "chore: initialize smoke target"
)

bash "$repo_root/install-agent-harness.sh" --force "$target_root" >/dev/null

(
  cd "$target_root"
  git add .
  git commit -q -m "chore: install agent harness"

  python_bin=""
  if command -v python3 >/dev/null 2>&1; then
    python_bin="python3"
  elif command -v python >/dev/null 2>&1; then
    python_bin="python"
  else
    echo "ERROR: python is required for sandbox smoke setup"
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  "$python_bin" - <<'PY'
from pathlib import Path

harness = Path(".agent/harness.yml")
text = harness.read_text(encoding="utf-8")
text = text.replace("  enabled: false\n", "  enabled: true\n", 1)
text = text.replace("  runner: docker\n", "  runner: docker\n", 1)
text = text.replace(
    '  command: "bash scripts/agent-finish.sh --strict"\n',
    '  command: "bash scripts/agent-verify.sh --best-effort"\n',
    1,
)
harness.write_text(text, encoding="utf-8")

task = Path(".agent/task.yml")
text = task.read_text(encoding="utf-8")
text = text.replace(
    "    requires_sandbox_verification: false\n",
    "    requires_sandbox_verification: true\n",
    1,
)
task.write_text(text, encoding="utf-8")
PY

  set +e
  HARNESS_SANDBOX_RUNNER_BIN="$runner_bin" \
    bash scripts/agent-sandbox-run.sh > sandbox-smoke-run.log 2>&1
  sandbox_status=$?
  set -e

  if [ "$sandbox_status" -ne 0 ]; then
    echo "Sandbox smoke failed."
    cat sandbox-smoke-run.log
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  sandbox_summary="$(
    find .agent/sandbox-runs -type f -name sandbox-summary.json |
      sort |
      tail -n 1
  )"
  if [ -z "$sandbox_summary" ] || [ ! -f "$sandbox_summary" ]; then
    echo "ERROR: sandbox summary was not written"
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi
  if ! grep -Fq '"overall_result": "pass"' "$sandbox_summary"; then
    echo "ERROR: sandbox summary did not record pass"
    cat "$sandbox_summary"
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  set +e
  bash scripts/agent-finish.sh --best-effort > finish-smoke-run.log 2>&1
  finish_status=$?
  set -e

  if [ "$finish_status" -ne 0 ]; then
    echo "Sandbox smoke finish validation failed."
    cat finish-smoke-run.log
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  if ! grep -Fq "AGENT_FINISH_RESULT=pass" finish-smoke-run.log; then
    echo "ERROR: finish run did not report pass"
    cat finish-smoke-run.log
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  finish_summary="$(
    find .agent/runs -type f -name finish-summary.json |
      sort |
      tail -n 1
  )"
  if [ -z "$finish_summary" ] || [ ! -f "$finish_summary" ]; then
    echo "ERROR: finish summary was not written"
    echo "SANDBOX_CI_SMOKE_RESULT=fail"
    exit 1
  fi

  echo "Sandbox smoke target: $target_root"
  echo "Sandbox smoke run: $(dirname "$sandbox_summary")"
  echo "Finish evidence run: $(dirname "$finish_summary")"
  echo "SANDBOX_CI_SMOKE_RESULT=pass"
)
```

- [x] **Step 2: Make the smoke command executable**

Run:

```bash
chmod +x ci/sandbox-smoke.sh
```

- [x] **Step 3: Run the targeted smoke tests**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for:

- `Sandbox CI smoke skips when no runner is available`
- `Sandbox CI smoke fake runner pass validates finish evidence`
- `Sandbox CI smoke fake runner failure is blocking`

- [x] **Step 4: Commit**

```bash
git add ci/sandbox-smoke.sh tests/harness/sandbox-ci-smoke.sh validate-harness.sh
git commit -m "test: add sandbox CI smoke command"
```

## Task 3: Wire Sandbox Smoke Into CI

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `docs/public-packaging.md`
- Modify: `docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md`

- [x] **Step 1: Add failing doc consistency assertions for CI smoke**

In `tests/harness/doc-consistency.sh`, add these assertions near the existing
release documentation assertions:

```bash
assert_exists "$repo_root/ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "bash ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "Sandbox smoke"
assert_contains "$repo_root/docs/public-packaging.md" "Sandbox smoke"
```

- [x] **Step 2: Run validation to verify CI workflow is not wired yet**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `.github/workflows/ci.yml` does not yet run
`bash ci/sandbox-smoke.sh`.

- [x] **Step 3: Add the CI smoke step**

Modify `.github/workflows/ci.yml` so the `validate` job includes this step
after `bash validate-harness.sh`:

```yaml
      - name: Sandbox smoke
        run: bash ci/sandbox-smoke.sh
```

The top of the workflow should still look like this:

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash validate-harness.sh
      - name: Sandbox smoke
        run: bash ci/sandbox-smoke.sh
      - name: Verify universal adapter files are tracked
        run: |
          test -f templates/AGENTS.md
          test -f templates/CLAUDE.md
          test -f adapters/codex/AGENTS.md
          test -f adapters/codex/codex-start-prompt.md
          test -f adapters/claude-code/CLAUDE.md
          test -f docs/codex-usage.md
          test -f docs/agent-support-matrix.md
          test -f schemas/harness.schema.json
          test -f schemas/policy.schema.json
          test -f schemas/task.schema.json
          test -f schemas/handoff.schema.json
```

- [x] **Step 4: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS, including the new CI workflow assertions.

- [x] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml tests/harness/doc-consistency.sh docs/public-packaging.md docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md
git commit -m "ci: run sandbox smoke in validation workflow"
```

## Task 4: Release Checklist And Public Docs

**Files:**
- Modify: `docs/public-packaging.md`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md`

- [x] **Step 1: Add failing release-readiness assertions**

In `tests/harness/doc-consistency.sh`, add assertions near the existing public
packaging checks:

```bash
assert_contains "$repo_root/docs/public-packaging.md" "- [x] `VERSION` is `0.1.0`."
assert_contains "$repo_root/docs/public-packaging.md" "- [x] `CHANGELOG.md` has a `v0.1.0` entry."
assert_contains "$repo_root/docs/public-packaging.md" "- [x] `README.md` has a CI badge"
assert_contains "$repo_root/docs/public-packaging.md" "- [x] `install-agent-harness.sh` prints the short 3-step next path."
assert_contains "$repo_root/docs/public-packaging.md" "- [x] Sandbox smoke is wired into CI"
assert_contains "$repo_root/docs/public-packaging.md" "- [ ] Set the GitHub description."
assert_contains "$repo_root/docs/public-packaging.md" "- [ ] Create the GitHub release tag `v0.1.0`."
assert_contains "$repo_root/CHANGELOG.md" "Sandbox smoke readiness"
assert_contains "$repo_root/README.md" "SANDBOX_CI_SMOKE_RESULT"
```

- [x] **Step 2: Run validation to verify docs are not updated yet**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL on the new public packaging or README assertions.

- [x] **Step 3: Update the release checklist**

In `docs/public-packaging.md`, replace the current v0.1.0 checklist block with:

```markdown
## v0.1.0 release checklist

- [ ] CI is passing on the published default branch.
- [x] `VERSION` is `0.1.0`.
- [x] `CHANGELOG.md` has a `v0.1.0` entry.
- [x] `README.md` has a CI badge, Quick Start, What It Is Not, Platform Support, Verification Strategy, Evidence vs Handoff, and Guardrails section.
- [x] `docs/handoff.md` explains `.agent/runs/<timestamp>/`, `handoff.md`, and optional `.agent/handoff.yml`.
- [x] `install-agent-harness.sh` prints the short 3-step next path.
- [x] The default TDD evidence is opt-in.
- [x] `bash validate-harness.sh` passes locally.
- [x] Sandbox smoke is wired into CI and reports `SANDBOX_CI_SMOKE_RESULT=pass|skip|fail`.
- [x] GitHub release notes are copied or summarized from `CHANGELOG.md`.
```

Keep `Before Publishing` unchanged unless the publishing action has actually
been completed.

- [x] **Step 4: Update CHANGELOG release notes**

In `CHANGELOG.md`, keep `## Unreleased` present but empty except for a short
sentence, and move current unreleased bullets into the `v0.1.0` highlights.
Use this structure:

```markdown
## Unreleased

No unreleased changes.

## v0.1.0 - Initial public baseline

Initial repo-local completion gate for AI coding agents.

Highlights:

- installable repo-local harness templates
- `AGENTS.md` and `CLAUDE.md` entrypoints
- `scripts/agent-finish.sh` completion gate
- scope and policy checks
- repo-defined verification via `.agent/harness.yml`
- opt-in TDD, acceptance, review, architecture, subagent, failure attribution, intervention, and sandbox evidence gates
- durable `.agent/runs/<timestamp>/` finish evidence
- machine-readable `finish-summary.json` and `episode-summary.json`
- local resource-envelope controls and entropy audit reports
- external sandbox verification envelope with `.agent/sandbox-runs/<timestamp>/` evidence
- Sandbox smoke readiness through `ci/sandbox-smoke.sh` and GitHub Actions
- Codex and Claude Code adapters
- GitHub Actions CI running `bash validate-harness.sh`

Notes:

- not a runtime
- not a sandbox
- not a semantic correctness guarantee
- sandbox verification depends on an external Docker or Podman runner
```

- [x] **Step 5: Update README sandbox smoke wording**

In `README.md`, add this paragraph under `## Sandbox Verification`, after the
paragraph that says the finish gate validates sandbox evidence:

```markdown
CI and release smoke checks use `ci/sandbox-smoke.sh`. The command installs the
harness into a temporary target, runs sandbox verification when Docker or Podman
is available, and prints `SANDBOX_CI_SMOKE_RESULT=pass`, `skip`, or `fail`.
A skip means no compatible external runner was available; a runner execution or
evidence failure is treated as a failure.
```

- [x] **Step 6: Run docs validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for doc consistency and doc links.

- [x] **Step 7: Commit**

```bash
git add docs/public-packaging.md CHANGELOG.md README.md tests/harness/doc-consistency.sh tests/harness/lib.sh docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md
git commit -m "docs: mark v0.1 release readiness evidence"
```

## Task 5: Final Verification And Handoff

**Files:**
- Modify: `handoff.md`
- Modify: `docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md`

- [ ] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 2: Run source checkout audit**

Run:

```bash
bash templates/scripts/agent-audit.sh
```

Expected: `AGENT_AUDIT_RESULT=pass`.

- [ ] **Step 3: Run sandbox smoke**

Run:

```bash
bash ci/sandbox-smoke.sh
```

Expected:

- `SANDBOX_CI_SMOKE_RESULT=pass` when Docker or Podman is available and works.
- `SANDBOX_CI_SMOKE_RESULT=skip` when neither Docker nor Podman is available.

Unexpected:

- `SANDBOX_CI_SMOKE_RESULT=fail` must be fixed before completing the plan.

- [ ] **Step 4: Update handoff**

Add a concise current-state entry to `handoff.md`:

```markdown
## Current State

v0.1.0 release readiness has been tightened: repository-verifiable public
packaging checklist items are marked complete, CI runs the normal harness
validation plus sandbox smoke, and sandbox smoke reports explicit pass, skip,
or fail evidence.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/agent-audit.sh`: PASS
- `bash ci/sandbox-smoke.sh`: PASS or SKIP with reason recorded in command output

## Evidence

- Latest audit run: `.agent/audits/<timestamp>/`
- Latest sandbox smoke target: printed by `bash ci/sandbox-smoke.sh` when kept or available in CI logs

## Next Action

Run the GitHub Actions workflow on the published default branch and complete
the external publishing checklist in `docs/public-packaging.md`.
```

Replace the result labels and evidence paths with the actual command output.

- [ ] **Step 5: Mark this plan complete**

In this plan file, mark completed steps with `[x]` only after the commands above
have run and the handoff reflects the actual results.

- [ ] **Step 6: Inspect final status**

Run:

```bash
git status --short
```

Expected: only intended tracked changes plus expected untracked `.agent/`
runtime evidence.

- [ ] **Step 7: Commit**

```bash
git add handoff.md docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md
git commit -m "chore: finalize v0.1 release sandbox smoke readiness"
```

## Self-Review

Spec coverage:

- Public release readiness checklist: Task 4.
- Installed-target sandbox smoke path: Tasks 1 and 2.
- CI-visible sandbox smoke result: Task 3.
- Pass/skip/fail error contract: Tasks 1 and 2.
- Runtime boundary honesty and v0.2 exclusions: Task 4.
- Final validation, audit, smoke, and handoff evidence: Task 5.

Incomplete-content scan:

- No incomplete-content markers are intentionally left in this plan.

Type and name consistency:

- Smoke command path is consistently `ci/sandbox-smoke.sh`.
- Result marker is consistently `SANDBOX_CI_SMOKE_RESULT=pass|skip|fail`.
- Existing sandbox runner marker remains `SANDBOX_RUN_RESULT=pass|fail|skip`.
- Existing finish marker remains `AGENT_FINISH_RESULT=pass|fail`.

Plan complete and saved to `docs/superpowers/plans/2026-06-11-v0-1-0-release-sandbox-smoke-readiness.md`.
