# Sandbox Verification Envelope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional sandbox verification envelope that runs configured harness verification in an external Docker or Podman boundary and records durable evidence without replacing obra/superpowers workflows.

**Architecture:** Keep `scripts/agent-finish.sh` as the canonical completion gate and add sandbox verification as an opt-in evidence source. The runner writes `.agent/sandbox-runs/<timestamp>/` evidence; the finish gate validates existing sandbox evidence only when `.agent/task.yml` requires it. Tests use fake runner fixtures so `bash validate-harness.sh` does not require Docker or Podman.

**Tech Stack:** POSIX-ish Bash, Python standard library, harness-owned YAML reader, JSON Schemas, Docker/Podman command-line contract, existing `tests/harness/*.sh` suites.

---

## Approved Spec

Source design:

- `docs/superpowers/specs/2026-06-06-sandbox-verification-envelope-design.md`

This implementation must preserve the responsibility split:

- Superpowers drives planning, TDD, subagent workflow, verification discipline, and finishing decisions.
- Agent-Repo-Harness records repo-local contracts, gates, and evidence.
- Sandbox verification only provides an external verification execution envelope.

## File Structure

Create:

- `templates/scripts/agent-sandbox-run.sh`: runs the configured sandbox command and writes `.agent/sandbox-runs/<timestamp>/` evidence.
- `templates/scripts/check-sandbox-evidence.sh`: validates newest sandbox evidence when required by `.agent/task.yml`.
- `tests/harness/sandbox-runner.sh`: fake-runner tests for sandbox command execution and evidence writing.
- `tests/harness/sandbox-evidence.sh`: optional finish-gate evidence tests.

Modify:

- `templates/.agent/harness.yml`: add disabled-by-default sandbox config.
- `schemas/harness.schema.json`: validate sandbox config shape.
- `templates/.agent/task.yml`: add `completion.requires_sandbox_verification: false`.
- `schemas/task.schema.json`: validate new task flag.
- `templates/scripts/validate-task.sh`: validate new task flag as boolean.
- `templates/scripts/agent-preflight.sh`: report sandbox runner availability/config status without blocking.
- `templates/scripts/agent-finish.sh`: run `check-sandbox-evidence.sh` and record gate evidence.
- `tests/harness/lib.sh`: assert sandbox evidence files in finish runs.
- `tests/harness/static-install.sh`: assert sandbox scripts install.
- `tests/harness/template-sync.sh`: assert templates/examples/docs remain aligned.
- `validate-harness.sh`: source new sandbox suites.
- `install-agent-harness.sh`: no special schema copy is needed if only existing schemas change; ensure new scripts install through `templates/`.
- `examples/universal-minimal-repo/.agent/harness.yml`: mirror disabled sandbox config if the example carries harness config.
- `examples/universal-minimal-repo/.agent/task.yml`: mirror disabled sandbox flag if the example carries task config.
- `examples/universal-minimal-repo/scripts/agent-sandbox-run.sh`: mirror minimal example script only if example scripts are kept in template sync.
- `examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh`: mirror minimal example script only if example scripts are kept in template sync.
- `README.md`, `README.zh-TW.md`, `docs/runtime-boundaries.md`, `docs/USAGE_WITH_AGENTS.md`, `docs/superpowers-integration.md`, `templates/AGENTS.md`, `templates/CLAUDE.md`, `skills/verification-gate/SKILL.md`, `skills/harness-entrypoint/SKILL.md`: document sandbox verification without overstating isolation.
- `handoff.md`: update after implementation with actual validation evidence.

## Implementation Tasks

### Task 1: Config And Task Contract

**Files:**
- Modify: `templates/.agent/harness.yml`
- Modify: `schemas/harness.schema.json`
- Modify: `templates/.agent/task.yml`
- Modify: `schemas/task.schema.json`
- Modify: `templates/scripts/validate-task.sh`
- Modify: `tests/harness/task-validation.sh`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Write failing task validation assertions**

In `tests/harness/task-validation.sh`, add a focused case near the existing task type validation tests:

```bash
echo
echo "== Task validation sandbox flag behavior =="
sandbox_task_root="$tmp_root/task-sandbox-flag"
rm -rf "$sandbox_task_root"
mkdir -p "$sandbox_task_root/.agent" "$sandbox_task_root/scripts/lib"
(
  cd "$sandbox_task_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  status: "not_started"' \
    '  goal: "Validate sandbox task flag."' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_sandbox_verification: true' \
    > .agent/task.yml
  bash scripts/validate-task.sh > task-sandbox.log 2>&1
  assert_contains task-sandbox.log "task.completion.requires_sandbox_verification is boolean"
  assert_contains task-sandbox.log "TASK_VALIDATION_RESULT=pass"
)
pass "task validation sandbox flag behavior"

echo
echo "== Task validation sandbox flag type failure =="
sandbox_task_bad_root="$tmp_root/task-sandbox-flag-bad"
rm -rf "$sandbox_task_bad_root"
mkdir -p "$sandbox_task_bad_root/.agent" "$sandbox_task_bad_root/scripts/lib"
(
  cd "$sandbox_task_bad_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  status: "not_started"' \
    '  goal: "Validate sandbox task flag failure."' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_sandbox_verification: "yes"' \
    > .agent/task.yml
  if bash scripts/validate-task.sh > task-sandbox-bad.log 2>&1; then
    echo "ERROR: expected sandbox flag type failure"
    exit 1
  fi
  assert_contains task-sandbox-bad.log "task.completion.requires_sandbox_verification must be boolean"
  assert_contains task-sandbox-bad.log "TASK_VALIDATION_RESULT=fail"
)
pass "task validation sandbox flag type failure"
```

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `validate-task.sh` does not know `requires_sandbox_verification`.

- [x] **Step 2: Add disabled sandbox config to harness template**

In `templates/.agent/harness.yml`, add after `runtime.resource_limits`:

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

- [x] **Step 3: Extend harness schema**

In `schemas/harness.schema.json`, add this top-level property beside `runtime`:

```json
"sandbox": {
  "type": "object",
  "properties": {
    "enabled": { "type": "boolean" },
    "runner": { "type": "string", "enum": ["docker", "podman"] },
    "mode": { "type": "string", "enum": ["verification"] },
    "command": { "type": "string" },
    "workspace": {
      "type": "object",
      "properties": {
        "strategy": { "type": "string", "enum": ["copy"] }
      },
      "additionalProperties": false
    },
    "network": { "type": "string", "enum": ["disabled", "host"] },
    "env": {
      "type": "object",
      "properties": {
        "allow": {
          "type": "array",
          "items": { "type": "string" }
        }
      },
      "additionalProperties": false
    },
    "resource_limits": {
      "type": "object",
      "properties": {
        "cpus": { "type": "string" },
        "memory": { "type": "string" },
        "timeout_seconds": { "type": "integer", "minimum": 1 }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

- [x] **Step 4: Add task flag to template and schema**

In `templates/.agent/task.yml`, add under `completion`:

```yaml
    requires_sandbox_verification: false
```

In `schemas/task.schema.json`, add under `completion.properties`:

```json
"requires_sandbox_verification": { "type": "boolean" }
```

- [x] **Step 5: Validate sandbox flag in task script**

In `templates/scripts/validate-task.sh`, add the new optional boolean check next to the existing completion flags:

```bash
check_optional_bool "task.completion.requires_sandbox_verification"
```

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for the new task validation cases, or FAIL only in template/example sync because example fixtures still need updates.

- [x] **Step 6: Update static install assertions**

In `tests/harness/static-install.sh`, add assertions after existing installed gate checks:

```bash
assert_contains "$target_root/.agent/harness.yml" "sandbox:"
assert_contains "$target_root/.agent/harness.yml" "enabled: false"
assert_contains "$target_root/.agent/task.yml" "requires_sandbox_verification: false"
```

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add templates/.agent/harness.yml schemas/harness.schema.json templates/.agent/task.yml schemas/task.schema.json templates/scripts/validate-task.sh tests/harness/task-validation.sh tests/harness/static-install.sh
git commit -m "feat: add sandbox verification config contract"
```

### Task 2: Sandbox Evidence Gate

**Files:**
- Create: `templates/scripts/check-sandbox-evidence.sh`
- Create: `tests/harness/sandbox-evidence.sh`
- Modify: `validate-harness.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Write failing sandbox evidence tests**

Create `tests/harness/sandbox-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Sandbox evidence skip semantics =="
sandbox_skip_root="$tmp_root/sandbox-skip"
rm -rf "$sandbox_skip_root"
mkdir -p "$sandbox_skip_root/.agent" "$sandbox_skip_root/scripts/lib"
(
  cd "$sandbox_skip_root"
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_sandbox_verification: false' \
    > .agent/task.yml
  bash scripts/check-sandbox-evidence.sh > sandbox-skip.log 2>&1
  assert_contains sandbox-skip.log "Sandbox verification is not required."
  assert_contains sandbox-skip.log "SANDBOX_EVIDENCE_RESULT=pass"
)
pass "sandbox evidence skip semantics"

echo
echo "== Sandbox evidence required and valid =="
sandbox_pass_root="$tmp_root/sandbox-pass"
rm -rf "$sandbox_pass_root"
mkdir -p "$sandbox_pass_root/.agent/sandbox-runs/20260606-010000" "$sandbox_pass_root/scripts/lib"
(
  cd "$sandbox_pass_root"
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_sandbox_verification: true' \
    > .agent/task.yml
  printf '%s\n' \
    '{"exit_status": 0, "overall_result": "pass"}' \
    > .agent/sandbox-runs/20260606-010000/sandbox-summary.json
  bash scripts/check-sandbox-evidence.sh > sandbox-pass.log 2>&1
  assert_contains sandbox-pass.log "Sandbox verification is required."
  assert_contains sandbox-pass.log "OK: sandbox verification evidence"
  assert_contains sandbox-pass.log "SANDBOX_EVIDENCE_RESULT=pass"
)
pass "sandbox evidence required and valid"

echo
echo "== Sandbox evidence required and failing newest run =="
sandbox_fail_root="$tmp_root/sandbox-fail"
rm -rf "$sandbox_fail_root"
mkdir -p "$sandbox_fail_root/.agent/sandbox-runs/20260606-010000" \
  "$sandbox_fail_root/.agent/sandbox-runs/20260606-020000" \
  "$sandbox_fail_root/scripts/lib"
(
  cd "$sandbox_fail_root"
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_sandbox_verification: true' \
    > .agent/task.yml
  printf '%s\n' '{"exit_status": 0, "overall_result": "pass"}' \
    > .agent/sandbox-runs/20260606-010000/sandbox-summary.json
  printf '%s\n' '{"exit_status": 1, "overall_result": "fail"}' \
    > .agent/sandbox-runs/20260606-020000/sandbox-summary.json
  if bash scripts/check-sandbox-evidence.sh > sandbox-fail.log 2>&1; then
    echo "ERROR: expected sandbox evidence failure"
    exit 1
  fi
  assert_contains sandbox-fail.log "ERROR: newest sandbox run did not pass"
  assert_contains sandbox-fail.log "SANDBOX_EVIDENCE_RESULT=fail"
)
pass "sandbox evidence required and failing newest run"
```

Source it in `validate-harness.sh` after `interventions.sh`:

```bash
source "$repo_root/tests/harness/sandbox-evidence.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/check-sandbox-evidence.sh` does not exist.

- [x] **Step 2: Add sandbox evidence check script**

Create `templates/scripts/check-sandbox-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-sandbox-evidence.sh [TASK_FILE] [SANDBOX_RUNS_DIR]

Defaults:
  TASK_FILE          .agent/task.yml
  SANDBOX_RUNS_DIR   .agent/sandbox-runs

Requires passing sandbox evidence only when TASK_FILE contains:
  task.completion.requires_sandbox_verification: true
EOF
}

task_file=".agent/task.yml"
sandbox_runs_dir=".agent/sandbox-runs"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    sandbox_runs_dir="${2:-$sandbox_runs_dir}"
    ;;
esac

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

read_optional_value() {
  local file="$1"
  local path="$2"
  "$python_bin" "$reader" "$file" "$path" --optional 2>/dev/null || true
}

echo "== Sandbox Evidence Gate =="
echo "Task file: $task_file"
echo "Sandbox runs directory: $sandbox_runs_dir"

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for sandbox evidence checks"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

if [ ! -f "$task_file" ]; then
  echo "Sandbox verification is not required."
  echo "SANDBOX_EVIDENCE_RESULT=pass"
  exit 0
fi

required="$(read_optional_value "$task_file" "task.completion.requires_sandbox_verification")"
if [ "$required" != "true" ]; then
  echo "Sandbox verification is not required."
  echo "SANDBOX_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "Sandbox verification is required."

if [ ! -d "$sandbox_runs_dir" ]; then
  echo "ERROR: missing sandbox runs directory: $sandbox_runs_dir"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

summary_file="$(find "$sandbox_runs_dir" -type f -name sandbox-summary.json | sort | tail -n 1)"
if [ -z "$summary_file" ]; then
  echo "ERROR: no sandbox-summary.json files found under $sandbox_runs_dir"
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

"$python_bin" - "$summary_file" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
try:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"ERROR: failed to parse sandbox summary: {exc}")
    sys.exit(1)

if data.get("overall_result") != "pass" or int(data.get("exit_status", 1)) != 0:
    print("ERROR: newest sandbox run did not pass")
    print(f"Summary: {summary_path}")
    sys.exit(1)

print("OK: sandbox verification evidence")
print(f"Summary: {summary_path}")
PY
status=$?

if [ "$status" -ne 0 ]; then
  echo "SANDBOX_EVIDENCE_RESULT=fail"
  exit 1
fi

echo "SANDBOX_EVIDENCE_RESULT=pass"
```

- [x] **Step 3: Wire sandbox evidence into finish gate**

In `templates/scripts/agent-finish.sh`, add variables near the other result files:

```bash
sandbox_evidence_result_file="$run_dir/sandbox-evidence-result.txt"
sandbox_evidence_status=""
```

Run the gate in both strict and best-effort branches after `check-interventions` and before `check-subagent-evidence`:

```bash
run_gate "check-sandbox-evidence" "$sandbox_evidence_result_file" bash scripts/check-sandbox-evidence.sh
sandbox_evidence_status="$last_status"
```

Add a summary row:

```bash
echo "| check-sandbox-evidence | $sandbox_evidence_status | $sandbox_evidence_result_file |"
```

Add JSON environment variables:

```bash
AGENT_FINISH_SANDBOX_EVIDENCE_STATUS="${sandbox_evidence_status:-0}" \
AGENT_FINISH_SANDBOX_EVIDENCE="$sandbox_evidence_result_file" \
```

Add a JSON gate entry:

```python
{
    "name": "check-sandbox-evidence",
    "exit_status": int(env["AGENT_FINISH_SANDBOX_EVIDENCE_STATUS"]),
    "evidence": env["AGENT_FINISH_SANDBOX_EVIDENCE"],
},
```

- [x] **Step 4: Update finish evidence assertions**

In `tests/harness/lib.sh`, add `sandbox-evidence-result.txt` to `assert_run_evidence_files`:

```bash
sandbox-evidence-result.txt
```

Add summary assertions in `assert_finish_summary_contract`:

```bash
assert_file_contains "$root" "finish-summary.md" "| check-sandbox-evidence |"
assert_file_contains "$root" "finish-summary.md" "sandbox-evidence-result.txt"
```

In `assert_finish_json_contract`, require the new gate name:

```python
if "check-sandbox-evidence" not in gate_names:
    raise SystemExit("missing check-sandbox-evidence gate")
```

- [x] **Step 5: Update install smoke**

In `tests/harness/static-install.sh`, assert the script installs:

```bash
assert_exists "$target_root/scripts/check-sandbox-evidence.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add templates/scripts/check-sandbox-evidence.sh templates/scripts/agent-finish.sh tests/harness/sandbox-evidence.sh tests/harness/lib.sh tests/harness/static-install.sh validate-harness.sh
git commit -m "feat: add sandbox evidence gate"
```

### Task 3: Sandbox Runner Command

**Files:**
- Create: `templates/scripts/agent-sandbox-run.sh`
- Create: `tests/harness/sandbox-runner.sh`
- Modify: `validate-harness.sh`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Write failing fake-runner tests**

Create `tests/harness/sandbox-runner.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Sandbox runner disabled skips cleanly =="
sandbox_runner_skip_root="$tmp_root/sandbox-runner-skip"
rm -rf "$sandbox_runner_skip_root"
mkdir -p "$sandbox_runner_skip_root/.agent" "$sandbox_runner_skip_root/scripts/lib"
(
  cd "$sandbox_runner_skip_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'sandbox:' \
    '  enabled: false' \
    > .agent/harness.yml
  bash scripts/agent-sandbox-run.sh > sandbox-skip.log 2>&1
  assert_contains sandbox-skip.log "Sandbox verification is disabled."
  assert_contains sandbox-skip.log "SANDBOX_RUN_RESULT=skip"
)
pass "sandbox runner disabled skips cleanly"

echo
echo "== Sandbox runner fake pass writes evidence =="
sandbox_runner_pass_root="$tmp_root/sandbox-runner-pass"
rm -rf "$sandbox_runner_pass_root"
mkdir -p "$sandbox_runner_pass_root/.agent" "$sandbox_runner_pass_root/scripts/lib" "$sandbox_runner_pass_root/bin"
(
  cd "$sandbox_runner_pass_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > fake-runner-args.txt
printf '%s\n' "fake sandbox stdout"
printf '%s\n' "fake sandbox stderr" >&2
exit 0
SH
  chmod +x bin/fake-docker
  printf '%s\n' \
    'sandbox:' \
    '  enabled: true' \
    '  runner: docker' \
    '  mode: verification' \
    '  command: "bash scripts/agent-finish.sh --strict"' \
    '  workspace:' \
    '    strategy: "copy"' \
    '  network: "disabled"' \
    '  env:' \
    '    allow:' \
    '      - "SAFE_ENV"' \
    '  resource_limits:' \
    '    cpus: "2"' \
    '    memory: "2g"' \
    '    timeout_seconds: 60' \
    > .agent/harness.yml
  SAFE_ENV="secret-value" HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" bash scripts/agent-sandbox-run.sh > sandbox-pass.log 2>&1
  assert_contains sandbox-pass.log "SANDBOX_RUN_RESULT=pass"
  sandbox_summary="$(find .agent/sandbox-runs -type f -name sandbox-summary.json | sort | tail -n 1)"
  assert_exists "$sandbox_summary"
  assert_file="$(dirname "$sandbox_summary")/stdout.txt"
  assert_contains "$assert_file" "fake sandbox stdout"
  assert_contains fake-runner-args.txt "--network"
  assert_contains fake-runner-args.txt "none"
  assert_contains fake-runner-args.txt "--cpus"
  assert_contains fake-runner-args.txt "2"
  assert_contains fake-runner-args.txt "--memory"
  assert_contains fake-runner-args.txt "2g"
  assert_not_contains "$sandbox_summary" "secret-value"
  assert_contains "$sandbox_summary" '"overall_result": "pass"'
)
pass "sandbox runner fake pass writes evidence"

echo
echo "== Sandbox runner fake failure writes evidence =="
sandbox_runner_fail_root="$tmp_root/sandbox-runner-fail"
rm -rf "$sandbox_runner_fail_root"
mkdir -p "$sandbox_runner_fail_root/.agent" "$sandbox_runner_fail_root/scripts/lib" "$sandbox_runner_fail_root/bin"
(
  cd "$sandbox_runner_fail_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "failure stdout"
printf '%s\n' "failure stderr" >&2
exit 7
SH
  chmod +x bin/fake-docker
  printf '%s\n' \
    'sandbox:' \
    '  enabled: true' \
    '  runner: docker' \
    '  mode: verification' \
    '  command: "bash scripts/agent-finish.sh --strict"' \
    '  workspace:' \
    '    strategy: "copy"' \
    '  network: "host"' \
    > .agent/harness.yml
  if HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" bash scripts/agent-sandbox-run.sh > sandbox-fail.log 2>&1; then
    echo "ERROR: expected sandbox runner failure"
    exit 1
  fi
  assert_contains sandbox-fail.log "SANDBOX_RUN_RESULT=fail"
  sandbox_summary="$(find .agent/sandbox-runs -type f -name sandbox-summary.json | sort | tail -n 1)"
  assert_exists "$sandbox_summary"
  assert_contains "$sandbox_summary" '"exit_status": 7'
  assert_contains "$sandbox_summary" '"overall_result": "fail"'
  assert_contains "$(dirname "$sandbox_summary")/stderr.txt" "failure stderr"
)
pass "sandbox runner fake failure writes evidence"
```

Source it in `validate-harness.sh` after `sandbox-evidence.sh`:

```bash
source "$repo_root/tests/harness/sandbox-runner.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/agent-sandbox-run.sh` is missing.

- [x] **Step 2: Add sandbox runner script**

Create `templates/scripts/agent-sandbox-run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-sandbox-run.sh [--strict|--best-effort]

Runs the configured sandbox verification command from .agent/harness.yml and
writes durable evidence under .agent/sandbox-runs/<timestamp>/.
EOF
}

mode="strict"
case "${1:-}" in
  "")
    ;;
  --strict)
    mode="strict"
    ;;
  --best-effort)
    mode="best-effort"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unsupported mode: ${1:-}"
    usage
    exit 2
    ;;
esac

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
run_dir=".agent/sandbox-runs/$timestamp"
stdout_file="$run_dir/stdout.txt"
stderr_file="$run_dir/stderr.txt"
command_file="$run_dir/command.txt"
exit_status_file="$run_dir/exit-status.txt"
summary_json_file="$run_dir/sandbox-summary.json"
harness_file=".agent/harness.yml"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

read_value() {
  "$python_bin" "$reader" "$harness_file" "$1" --optional 2>/dev/null || true
}

write_summary() {
  local overall_result="$1"
  local exit_status="$2"

  SANDBOX_SUMMARY_JSON="$summary_json_file" \
  SANDBOX_TIMESTAMP="$timestamp" \
  SANDBOX_RUNNER="$runner" \
  SANDBOX_MODE="$sandbox_mode" \
  SANDBOX_COMMAND="$sandbox_command" \
  SANDBOX_NETWORK="$network" \
  SANDBOX_WORKSPACE_STRATEGY="$workspace_strategy" \
  SANDBOX_EXIT_STATUS="$exit_status" \
  SANDBOX_OVERALL_RESULT="$overall_result" \
  SANDBOX_RUN_DIR="$run_dir" \
  SANDBOX_ENV_ALLOW_NAMES="$env_allow_names" \
  "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

run_dir = os.environ["SANDBOX_RUN_DIR"]
data = {
    "timestamp": os.environ["SANDBOX_TIMESTAMP"],
    "runner": os.environ["SANDBOX_RUNNER"],
    "mode": os.environ["SANDBOX_MODE"],
    "command": os.environ["SANDBOX_COMMAND"],
    "network": os.environ["SANDBOX_NETWORK"],
    "workspace_strategy": os.environ["SANDBOX_WORKSPACE_STRATEGY"],
    "exit_status": int(os.environ["SANDBOX_EXIT_STATUS"]),
    "overall_result": os.environ["SANDBOX_OVERALL_RESULT"],
    "env_allow": [name for name in os.environ["SANDBOX_ENV_ALLOW_NAMES"].splitlines() if name],
    "evidence": {
        "stdout": f"{run_dir}/stdout.txt",
        "stderr": f"{run_dir}/stderr.txt",
        "command": f"{run_dir}/command.txt",
        "exit_status": f"{run_dir}/exit-status.txt",
    },
}
Path(os.environ["SANDBOX_SUMMARY_JSON"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
}

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for sandbox verification"
  exit 1
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  exit 1
fi

if [ ! -f "$harness_file" ]; then
  echo "Sandbox verification is disabled."
  echo "SANDBOX_RUN_RESULT=skip"
  exit 0
fi

enabled="$(read_value "sandbox.enabled")"
if [ "$enabled" != "true" ]; then
  echo "Sandbox verification is disabled."
  echo "SANDBOX_RUN_RESULT=skip"
  exit 0
fi

runner="$(read_value "sandbox.runner")"
sandbox_mode="$(read_value "sandbox.mode")"
sandbox_command="$(read_value "sandbox.command")"
workspace_strategy="$(read_value "sandbox.workspace.strategy")"
network="$(read_value "sandbox.network")"
cpus="$(read_value "sandbox.resource_limits.cpus")"
memory="$(read_value "sandbox.resource_limits.memory")"
timeout_seconds="$(read_value "sandbox.resource_limits.timeout_seconds")"
env_allow_json="$("$python_bin" "$reader" "$harness_file" "sandbox.env.allow" --json --optional 2>/dev/null || true)"

runner="${runner:-docker}"
sandbox_mode="${sandbox_mode:-verification}"
sandbox_command="${sandbox_command:-bash scripts/agent-finish.sh --strict}"
workspace_strategy="${workspace_strategy:-copy}"
network="${network:-disabled}"
timeout_seconds="${timeout_seconds:-600}"

case "$runner" in
  docker|podman) ;;
  *)
    echo "ERROR: unsupported sandbox runner: $runner"
    echo "SANDBOX_RUN_RESULT=fail"
    exit 1
    ;;
esac

case "$sandbox_mode" in
  verification) ;;
  *)
    echo "ERROR: unsupported sandbox mode: $sandbox_mode"
    echo "SANDBOX_RUN_RESULT=fail"
    exit 1
    ;;
esac

case "$workspace_strategy" in
  copy) ;;
  *)
    echo "ERROR: unsupported workspace strategy: $workspace_strategy"
    echo "SANDBOX_RUN_RESULT=fail"
    exit 1
    ;;
esac

case "$network" in
  disabled|host) ;;
  *)
    echo "ERROR: unsupported sandbox network mode: $network"
    echo "SANDBOX_RUN_RESULT=fail"
    exit 1
    ;;
esac

runner_bin="${HARNESS_SANDBOX_RUNNER_BIN:-$runner}"
if ! command -v "$runner_bin" >/dev/null 2>&1; then
  echo "ERROR: sandbox runner not found: $runner_bin"
  echo "SANDBOX_RUN_RESULT=fail"
  exit 1
fi

mkdir -p "$run_dir"
printf '%s\n' "$sandbox_command" > "$command_file"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-sandbox.XXXXXX")"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

workspace_dir="$tmp_root/workspace"
mkdir -p "$workspace_dir"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude '.git' --exclude '.agent/sandbox-runs' ./ "$workspace_dir/"
else
  tar --exclude './.git' --exclude './.agent/sandbox-runs' -cf - . | (cd "$workspace_dir" && tar -xf -)
fi

network_args=()
if [ "$network" = "disabled" ]; then
  network_args=(--network none)
else
  network_args=(--network host)
fi

resource_args=()
if [ -n "$cpus" ]; then
  resource_args+=(--cpus "$cpus")
fi
if [ -n "$memory" ]; then
  resource_args+=(--memory "$memory")
fi

env_args=()
env_allow_names=""
if [ -n "$env_allow_json" ] && [ "$env_allow_json" != "null" ]; then
  env_allow_names="$(
    ENV_ALLOW_JSON="$env_allow_json" "$python_bin" - <<'PY'
import json
import os
names = json.loads(os.environ["ENV_ALLOW_JSON"])
if isinstance(names, list):
    for name in names:
        if isinstance(name, str) and name:
            print(name)
PY
  )"
  while IFS= read -r env_name; do
    [ -z "$env_name" ] && continue
    if [ "${!env_name+x}" = "x" ]; then
      env_args+=("-e" "$env_name")
    fi
  done <<EOF
$env_allow_names
EOF
fi

image="ubuntu:24.04"

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "$timeout_seconds" "$runner_bin" run --rm \
    "${network_args[@]}" \
    "${resource_args[@]}" \
    "${env_args[@]}" \
    -v "$workspace_dir:/workspace" \
    -w /workspace \
    "$image" \
    bash -lc "$sandbox_command" >"$stdout_file" 2>"$stderr_file"
  sandbox_status=$?
else
  "$runner_bin" run --rm \
    "${network_args[@]}" \
    "${resource_args[@]}" \
    "${env_args[@]}" \
    -v "$workspace_dir:/workspace" \
    -w /workspace \
    "$image" \
    bash -lc "$sandbox_command" >"$stdout_file" 2>"$stderr_file"
  sandbox_status=$?
fi
set -e

printf '%s\n' "$sandbox_status" > "$exit_status_file"

if [ "$sandbox_status" -eq 0 ]; then
  write_summary "pass" "$sandbox_status"
  echo "SANDBOX_RUN_RESULT=pass"
  echo "Sandbox run directory: $run_dir"
  exit 0
fi

write_summary "fail" "$sandbox_status"
echo "SANDBOX_RUN_RESULT=fail"
echo "Sandbox run directory: $run_dir"
exit 1
```

- [x] **Step 3: Update install smoke**

In `tests/harness/static-install.sh`, add:

```bash
assert_exists "$target_root/scripts/agent-sandbox-run.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [x] **Step 4: Commit**

```bash
git add templates/scripts/agent-sandbox-run.sh tests/harness/sandbox-runner.sh tests/harness/static-install.sh validate-harness.sh
git commit -m "feat: add sandbox verification runner"
```

### Task 4: Example And Template Sync

**Files:**
- Modify: `examples/universal-minimal-repo/.agent/harness.yml`
- Modify: `examples/universal-minimal-repo/.agent/task.yml`
- Create: `examples/universal-minimal-repo/scripts/agent-sandbox-run.sh`
- Create: `examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh`
- Modify: `tests/harness/template-sync.sh`
- Modify: `tests/harness/static-install.sh`

- [ ] **Step 1: Run template sync to expose example drift**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL only if template/example sync requires the universal example to mirror new config or scripts. If it already passes, continue to Step 4 and do not change examples unnecessarily.

- [ ] **Step 2: Mirror disabled sandbox config in the universal example**

If `examples/universal-minimal-repo/.agent/harness.yml` exists, add:

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

If `examples/universal-minimal-repo/.agent/task.yml` exists, add:

```yaml
    requires_sandbox_verification: false
```

- [ ] **Step 3: Mirror scripts only if examples carry copied scripts**

If `examples/universal-minimal-repo/scripts/agent-finish.sh` is a copied script, copy the new sandbox scripts:

```bash
cp templates/scripts/agent-sandbox-run.sh examples/universal-minimal-repo/scripts/agent-sandbox-run.sh
cp templates/scripts/check-sandbox-evidence.sh examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh
chmod +x examples/universal-minimal-repo/scripts/agent-sandbox-run.sh examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh
```

- [ ] **Step 4: Add sync assertions**

In `tests/harness/template-sync.sh`, add assertions matching the existing style:

```bash
assert_contains "$repo_root/templates/.agent/harness.yml" "sandbox:"
assert_contains "$repo_root/templates/.agent/task.yml" "requires_sandbox_verification: false"
```

If universal example files are updated, add:

```bash
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/harness.yml" "sandbox:"
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" "requires_sandbox_verification: false"
```

- [ ] **Step 5: Run tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add examples/universal-minimal-repo tests/harness/template-sync.sh tests/harness/static-install.sh
git commit -m "test: keep sandbox templates and examples aligned"
```

### Task 5: Documentation And Superpowers Alignment

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/runtime-boundaries.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/superpowers-integration.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `skills/verification-gate/SKILL.md`
- Modify: `skills/harness-entrypoint/SKILL.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/adapter-sync.sh`

- [ ] **Step 1: Write failing doc assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_contains "$repo_root/README.md" "Sandbox Verification"
assert_contains "$repo_root/README.md" "external container sandbox"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Sandbox verification"
assert_contains "$repo_root/docs/superpowers-integration.md" "Sandbox verification"
assert_contains "$repo_root/templates/AGENTS.md" "sandbox verification"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "agent-sandbox-run.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in doc consistency.

- [ ] **Step 2: Update README wording**

In `README.md`, add after `Episode And Audit Evidence`:

```markdown
## Sandbox Verification

When configured, Agent-Repo-Harness can run a verification command inside an
external container sandbox through `scripts/agent-sandbox-run.sh`. The sandbox
runner writes `.agent/sandbox-runs/<timestamp>/sandbox-summary.json` plus
stdout, stderr, command, and exit-status evidence.

Sandbox verification is opt-in. A task can require existing passing sandbox
evidence with:

```yaml
task:
  completion:
    requires_sandbox_verification: true
```

The finish gate validates sandbox evidence; it does not create a nested sandbox
run by default. This keeps sandbox verification aligned with Superpowers
`verification-before-completion` instead of replacing the Superpowers workflow.
```

Add equivalent Traditional Chinese wording to `README.zh-TW.md`.

- [ ] **Step 3: Update runtime boundaries**

In `docs/runtime-boundaries.md`, add under Implemented:

```markdown
- Optional sandbox verification evidence from an external Docker or Podman
  runner when configured.
```

Add under Not Implemented:

```markdown
- Complete sandbox security independent of the configured external runner.
- Per-tool runtime interception.
- Network allowlists beyond first-version disabled or host modes.
- Secret manager integration.
```

- [ ] **Step 4: Update Superpowers integration docs**

In `docs/superpowers-integration.md`, add a row to the responsibility table:

```markdown
| Isolated final verification | `verification-before-completion` | `scripts/agent-sandbox-run.sh` + `.agent/sandbox-runs/<timestamp>/` |
```

Add to the example flow after `scripts/agent-verify.sh`:

```markdown
If `.agent/task.yml` requires sandbox verification, run
`scripts/agent-sandbox-run.sh` before `scripts/agent-finish.sh`. The finish
gate validates the resulting sandbox evidence; it does not dispatch the
sandbox run itself.
```

Add to non-goals:

```markdown
- This harness does not replace Superpowers verification workflows with
  sandbox orchestration.
```

- [ ] **Step 5: Update local skills**

In `skills/verification-gate/SKILL.md`, add after the `agent-verify.sh` command list:

```markdown
If `.agent/task.yml` sets `completion.requires_sandbox_verification: true`, run:

```bash
scripts/agent-sandbox-run.sh
```

Then run `scripts/agent-finish.sh`; the finish gate validates the sandbox
evidence instead of creating the sandbox run itself.
```

In `skills/harness-entrypoint/SKILL.md`, add before final completion:

```markdown
- run `scripts/agent-sandbox-run.sh` when sandbox verification is required
```

- [ ] **Step 6: Update templates**

In `templates/AGENTS.md`, add during-task guidance:

```markdown
- If `.agent/task.yml` requires sandbox verification, run the sandbox runner
  before final finish and preserve `.agent/sandbox-runs/<timestamp>/` evidence.
```

In `templates/CLAUDE.md`, add the same concise instruction where verification guidance lives.

- [ ] **Step 7: Run docs and adapter tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add README.md README.zh-TW.md docs/runtime-boundaries.md docs/USAGE_WITH_AGENTS.md docs/superpowers-integration.md templates/AGENTS.md templates/CLAUDE.md skills/verification-gate/SKILL.md skills/harness-entrypoint/SKILL.md tests/harness/doc-consistency.sh tests/harness/adapter-sync.sh
git commit -m "docs: align sandbox verification with superpowers"
```

### Task 6: Final Verification And Handoff

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `handoff.md`

- [ ] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS, including:

- sandbox evidence skip/pass/fail tests
- sandbox runner disabled/fake pass/fake fail tests
- existing finish evidence suites
- doc consistency
- template sync
- resource envelope
- entropy audit

- [ ] **Step 2: Run source checkout audit**

Run:

```bash
bash templates/scripts/agent-audit.sh
```

Expected: `AGENT_AUDIT_RESULT=pass`.

Record the printed audit directory.

- [ ] **Step 3: Run finish gate**

Run:

```bash
bash scripts/agent-finish.sh --best-effort
```

Expected: `AGENT_FINISH_RESULT=pass`, unless the live `.agent/task.yml` intentionally requires evidence not filled in the source checkout.

If it fails because live task state requires evidence, record the failing run directory and exact reason in `handoff.md`; do not claim final finish verified.

- [ ] **Step 4: Update changelog**

In `CHANGELOG.md`, add under `Unreleased`:

```markdown
- Add optional sandbox verification envelope configuration and task flag.
- Add sandbox verification runner evidence under `.agent/sandbox-runs/<timestamp>/`.
- Add optional sandbox evidence gate to `scripts/agent-finish.sh`.
- Document the sandbox/Superpowers responsibility split and runtime boundary.
```

- [ ] **Step 5: Update handoff**

Update `handoff.md` with:

```markdown
## Current State

Implemented the sandbox verification envelope: disabled-by-default sandbox
configuration, sandbox runner evidence, sandbox evidence finish gate, tests,
and Superpowers-aligned documentation.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/agent-audit.sh`: PASS
- `bash scripts/agent-finish.sh --best-effort`: PASS

## Evidence

- Latest audit run: `.agent/audits/<timestamp>/`
- Latest finish run: `.agent/runs/<timestamp>/`

## Next Action

Review sandbox verification behavior in a repository with Docker or Podman
installed, then decide whether to enable `requires_sandbox_verification` for
high-risk tasks.
```

Replace `<timestamp>` with actual evidence directories.

- [ ] **Step 6: Commit**

```bash
git add CHANGELOG.md handoff.md
git commit -m "chore: finalize sandbox verification envelope"
```

## Self-Review

Spec coverage:

- Sandbox config contract: Task 1.
- Task completion flag: Task 1 and Task 2.
- Sandbox runner command and evidence: Task 3.
- Finish gate validation: Task 2.
- Fake-runner testing without Docker or Podman: Task 3.
- Superpowers responsibility split: Task 5.
- Runtime boundary honesty: Task 5.
- Final verification evidence: Task 6.

Placeholder scan:

- The plan contains no placeholder markers, deferred implementation notes, or unspecified test commands.
- Future code paths are introduced in tasks before they are referenced as required implementation artifacts.
- Docker/Podman are not required for `bash validate-harness.sh`; fake runner tests cover local behavior.

Type consistency:

- The task flag is consistently named `requires_sandbox_verification`.
- Sandbox run evidence consistently lives under `.agent/sandbox-runs/<timestamp>/`.
- Finish evidence consistently uses `sandbox-evidence-result.txt`.
- Runner result output consistently uses `SANDBOX_RUN_RESULT`.
- Evidence gate result output consistently uses `SANDBOX_EVIDENCE_RESULT`.

## Execution Options

Plan complete and saved to `docs/superpowers/plans/2026-06-06-sandbox-verification-envelope.md`.

1. **Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fastest feedback.
2. **Inline Execution** - execute tasks in this session using `superpowers:executing-plans`, batching with review checkpoints.
