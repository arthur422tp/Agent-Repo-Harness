# Command Ledger Evidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit command ledger evidence so important local commands can be recorded, validated, and surfaced in finish summaries.

**Architecture:** Add an installed command runner wrapper that writes `.agent/command-runs/<timestamp>/` evidence and returns the wrapped command's exit status. Add an opt-in command ledger finish gate controlled by `task.completion.requires_command_ledger`, following the existing optional evidence gate pattern. Keep the boundary clear: this is explicit local command evidence, not automatic provider trace capture or runtime interception.

**Tech Stack:** POSIX-ish Bash, Python standard library, harness-owned YAML reader, JSON summary files, existing `tests/harness/*.sh` validation suites.

---

## Approved Spec

Design source:

- `docs/superpowers/specs/2026-06-13-command-ledger-evidence-design.md`

This plan intentionally does not implement provider-native tracing, automatic
tool-call capture, token accounting, model-cost enforcement, or semantic
correctness guarantees.

## File Structure

Create:

- `templates/scripts/agent-run.sh`: command runner wrapper that records command metadata, stdout, stderr, exit status, and `command-summary.json`.
- `templates/scripts/check-command-ledger.sh`: optional completion gate for `.agent/command-runs/*/command-summary.json`.
- `tests/harness/command-runner.sh`: tests for wrapper pass/fail evidence, exit status propagation, collision handling, and summary redaction.
- `tests/harness/command-ledger.sh`: tests for optional gate behavior and malformed evidence failures.

Modify:

- `validate-harness.sh`: source the new command runner and command ledger suites.
- `templates/.agent/task.yml`: add `completion.requires_command_ledger: false`.
- `schemas/task.schema.json`: add the new boolean completion flag.
- `templates/scripts/validate-task.sh`: validate the new optional boolean flag.
- `templates/scripts/agent-finish.sh`: run `check-command-ledger.sh`, write `command-ledger-result.txt`, and include the gate in Markdown and JSON summaries.
- `tests/harness/lib.sh`: add command ledger evidence to finish evidence and JSON contract assertions.
- `tests/harness/static-install.sh`: assert installed scripts and default flag.
- `tests/harness/finish-examples.sh`: copy the new gate into finish fixtures and assert skip output.
- `tests/harness/resource-envelope.sh`: copy the new gate into finish fixtures.
- `tests/harness/template-sync.sh`: assert template/example command ledger alignment.
- `examples/universal-minimal-repo/.agent/task.yml`: mirror the disabled default flag.
- `examples/universal-minimal-repo/scripts/agent-run.sh`: mirror the template script if the example keeps copied scripts.
- `examples/universal-minimal-repo/scripts/check-command-ledger.sh`: mirror the template script if the example keeps copied scripts.
- `README.md`, `README.zh-TW.md`, `docs/USAGE_WITH_AGENTS.md`, `docs/runtime-boundaries.md`, `docs/superpowers-integration.md`, `templates/AGENTS.md`, `templates/CLAUDE.md`, `skills/verification-gate/SKILL.md`: document explicit command ledger evidence without claiming automatic trace capture.
- `handoff.md`: update after implementation with real validation evidence.

## Task 1: Task Contract And Validation

**Files:**
- Modify: `templates/.agent/task.yml`
- Modify: `schemas/task.schema.json`
- Modify: `templates/scripts/validate-task.sh`
- Modify: `tests/harness/task-validation.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `tests/harness/template-sync.sh`
- Modify: `examples/universal-minimal-repo/.agent/task.yml`

- [x] **Step 1: Add failing task-validation tests**

Append these cases to `tests/harness/task-validation.sh` after the sandbox flag
tests:

```bash
echo
echo "== Task validation command ledger flag behavior =="
command_ledger_task_root="$tmp_root/task-command-ledger-flag"
rm -rf "$command_ledger_task_root"
mkdir -p "$command_ledger_task_root/.agent" "$command_ledger_task_root/scripts/lib"
(
  cd "$command_ledger_task_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  status: "not_started"' \
    '  goal: "Validate command ledger task flag."' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_command_ledger: true' \
    > .agent/task.yml
  bash scripts/validate-task.sh > task-command-ledger.log 2>&1
  assert_contains task-command-ledger.log "task.completion.requires_command_ledger is boolean"
  assert_contains task-command-ledger.log "TASK_VALIDATION_RESULT=pass"
)
pass "task validation command ledger flag behavior"

echo
echo "== Task validation command ledger flag type failure =="
command_ledger_task_bad_root="$tmp_root/task-command-ledger-flag-bad"
rm -rf "$command_ledger_task_bad_root"
mkdir -p "$command_ledger_task_bad_root/.agent" "$command_ledger_task_bad_root/scripts/lib"
(
  cd "$command_ledger_task_bad_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  status: "not_started"' \
    '  goal: "Validate command ledger task flag failure."' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_command_ledger: "yes"' \
    > .agent/task.yml
  if bash scripts/validate-task.sh > task-command-ledger-bad.log 2>&1; then
    echo "ERROR: expected command ledger flag type failure"
    exit 1
  fi
  assert_contains task-command-ledger-bad.log "task.completion.requires_command_ledger must be boolean"
  assert_contains task-command-ledger-bad.log "TASK_VALIDATION_RESULT=fail"
)
pass "task validation command ledger flag type failure"
```

- [x] **Step 2: Run validation to verify the new flag is not implemented**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `Task validation command ledger flag behavior` because
`validate-task.sh` does not yet validate the new flag.

- [x] **Step 3: Add the task flag to templates and schema**

In `templates/.agent/task.yml`, add the flag near the other completion gates:

```yaml
    requires_command_ledger: false
    # Set true when important local commands must be recorded through
    # scripts/agent-run.sh and validated before finish.
```

In `examples/universal-minimal-repo/.agent/task.yml`, add:

```yaml
    requires_command_ledger: false
```

In `schemas/task.schema.json`, add this property under
`completion.properties`:

```json
"requires_command_ledger": { "type": "boolean" },
```

- [x] **Step 4: Validate the flag in `validate-task.sh`**

In `templates/scripts/validate-task.sh`, add the new flag to the `for flag in`
list:

```bash
    requires_command_ledger \
```

- [x] **Step 5: Add install and template sync assertions**

In `tests/harness/static-install.sh`, add after the sandbox opt-in assertion:

```bash
assert_contains "$target_root/.agent/task.yml" "requires_command_ledger: false"
pass "installed default command ledger gate is opt-in"
```

In `tests/harness/template-sync.sh`, add near the other task flag assertions:

```bash
assert_contains "$repo_root/templates/.agent/task.yml" 'requires_command_ledger: false'
assert_contains "$repo_root/examples/universal-minimal-repo/.agent/task.yml" 'requires_command_ledger: false'
```

- [x] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for the new task validation cases and install/template assertions.

- [x] **Step 7: Commit**

```bash
git add templates/.agent/task.yml examples/universal-minimal-repo/.agent/task.yml schemas/task.schema.json templates/scripts/validate-task.sh tests/harness/task-validation.sh tests/harness/static-install.sh tests/harness/template-sync.sh
git commit -m "feat: add command ledger task contract"
```

## Task 2: Command Runner Evidence

**Files:**
- Create: `templates/scripts/agent-run.sh`
- Create: `tests/harness/command-runner.sh`
- Modify: `validate-harness.sh`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Write failing command runner tests**

Create `tests/harness/command-runner.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Command runner pass writes evidence =="
command_runner_pass_root="$tmp_root/command-runner-pass"
rm -rf "$command_runner_pass_root"
mkdir -p "$command_runner_pass_root/scripts"
(
  cd "$command_runner_pass_root"
  cp "$repo_root/templates/scripts/agent-run.sh" scripts/agent-run.sh
  chmod +x scripts/*.sh
  bash scripts/agent-run.sh -- sh -c 'printf "%s\n" "hello stdout"; printf "%s\n" "hello stderr" >&2' > command-pass.log 2>&1
  assert_contains command-pass.log "COMMAND_RUN_RESULT=pass"
  command_summary="$(find .agent/command-runs -type f -name command-summary.json | sort | tail -n 1)"
  assert_exists "$command_summary"
  command_dir="$(dirname "$command_summary")"
  assert_contains "$command_dir/stdout.txt" "hello stdout"
  assert_contains "$command_dir/stderr.txt" "hello stderr"
  assert_contains "$command_dir/exit-status.txt" "0"
  assert_contains "$command_summary" '"overall_result": "pass"'
  assert_contains "$command_summary" '"exit_status": 0'
  assert_contains "$command_summary" '"command": "sh -c'
)
pass "command runner pass writes evidence"

echo
echo "== Command runner failure writes evidence and propagates status =="
command_runner_fail_root="$tmp_root/command-runner-fail"
rm -rf "$command_runner_fail_root"
mkdir -p "$command_runner_fail_root/scripts"
(
  cd "$command_runner_fail_root"
  cp "$repo_root/templates/scripts/agent-run.sh" scripts/agent-run.sh
  chmod +x scripts/*.sh
  set +e
  bash scripts/agent-run.sh -- sh -c 'printf "%s\n" "failing stdout"; exit 7' > command-fail.log 2>&1
  run_status=$?
  set -e
  if [ "$run_status" -ne 7 ]; then
    echo "ERROR: expected wrapped command status 7, got $run_status"
    exit 1
  fi
  assert_contains command-fail.log "COMMAND_RUN_RESULT=fail"
  command_summary="$(find .agent/command-runs -type f -name command-summary.json | sort | tail -n 1)"
  assert_exists "$command_summary"
  command_dir="$(dirname "$command_summary")"
  assert_contains "$command_dir/stdout.txt" "failing stdout"
  assert_contains "$command_dir/exit-status.txt" "7"
  assert_contains "$command_summary" '"overall_result": "fail"'
  assert_contains "$command_summary" '"exit_status": 7'
)
pass "command runner failure writes evidence and propagates status"

echo
echo "== Command runner avoids same-second evidence overwrite =="
command_runner_collision_root="$tmp_root/command-runner-collision"
rm -rf "$command_runner_collision_root"
mkdir -p "$command_runner_collision_root/scripts" "$command_runner_collision_root/bin"
(
  cd "$command_runner_collision_root"
  cp "$repo_root/templates/scripts/agent-run.sh" scripts/agent-run.sh
  chmod +x scripts/*.sh
  cat > bin/date <<'SH'
#!/usr/bin/env bash
printf '%s\n' "20260613-010203"
SH
  chmod +x bin/date
  PATH="$PWD/bin:$PATH" bash scripts/agent-run.sh -- true > first.log 2>&1
  PATH="$PWD/bin:$PATH" bash scripts/agent-run.sh -- true > second.log 2>&1
  assert_exists ".agent/command-runs/20260613-010203/command-summary.json"
  assert_exists ".agent/command-runs/20260613-010203-01/command-summary.json"
)
pass "command runner avoids same-second evidence overwrite"

echo
echo "== Command runner summary does not leak environment values =="
command_runner_env_root="$tmp_root/command-runner-env"
rm -rf "$command_runner_env_root"
mkdir -p "$command_runner_env_root/scripts"
(
  cd "$command_runner_env_root"
  cp "$repo_root/templates/scripts/agent-run.sh" scripts/agent-run.sh
  chmod +x scripts/*.sh
  SECRET_TOKEN="secret-value" bash scripts/agent-run.sh -- sh -c 'printf "%s\n" "no secret here"' > command-env.log 2>&1
  command_summary="$(find .agent/command-runs -type f -name command-summary.json | sort | tail -n 1)"
  assert_exists "$command_summary"
  assert_not_contains "$command_summary" "secret-value"
)
pass "command runner summary does not leak environment values"

echo
echo "== Command runner requires separator and command =="
command_runner_usage_root="$tmp_root/command-runner-usage"
rm -rf "$command_runner_usage_root"
mkdir -p "$command_runner_usage_root/scripts"
(
  cd "$command_runner_usage_root"
  cp "$repo_root/templates/scripts/agent-run.sh" scripts/agent-run.sh
  chmod +x scripts/*.sh
  if bash scripts/agent-run.sh > command-usage.log 2>&1; then
    echo "ERROR: expected missing separator failure"
    exit 1
  fi
  assert_contains command-usage.log "Usage: agent-run.sh -- COMMAND"
)
pass "command runner requires separator and command"
```

- [x] **Step 2: Source the failing suite**

In `validate-harness.sh`, source the suite after `task-validation.sh`:

```bash
source "$repo_root/tests/harness/command-runner.sh"
```

- [x] **Step 3: Run validation to verify the runner is missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/agent-run.sh` does not exist.

- [x] **Step 4: Implement `agent-run.sh`**

Create `templates/scripts/agent-run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-run.sh -- COMMAND [ARG...]

Runs COMMAND, records stdout/stderr/exit status under
.agent/command-runs/<timestamp>/, and exits with COMMAND's status.
EOF
}

if [ "${1:-}" != "--" ]; then
  usage
  exit 2
fi
shift
if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
run_dir=".agent/command-runs/$timestamp"
stdout_file="$run_dir/stdout.txt"
stderr_file="$run_dir/stderr.txt"
command_file="$run_dir/command.txt"
cwd_file="$run_dir/cwd.txt"
exit_status_file="$run_dir/exit-status.txt"
summary_json_file="$run_dir/command-summary.json"

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

refresh_evidence_paths() {
  stdout_file="$run_dir/stdout.txt"
  stderr_file="$run_dir/stderr.txt"
  command_file="$run_dir/command.txt"
  cwd_file="$run_dir/cwd.txt"
  exit_status_file="$run_dir/exit-status.txt"
  summary_json_file="$run_dir/command-summary.json"
}

create_run_dir() {
  local base_run_dir="$run_dir"
  local suffix=0

  mkdir -p "$(dirname "$base_run_dir")"
  while ! mkdir "$run_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    run_dir="$(printf '%s-%02d' "$base_run_dir" "$suffix")"
    refresh_evidence_paths
  done
}

quote_command() {
  local out=""
  local arg
  for arg in "$@"; do
    if [ -n "$out" ]; then
      out="$out "
    fi
    out="$out$(printf '%q' "$arg")"
  done
  printf '%s\n' "$out"
}

write_summary() {
  local overall_result="$1"
  local exit_status="$2"

  COMMAND_SUMMARY_JSON="$summary_json_file" \
  COMMAND_TIMESTAMP="$timestamp" \
  COMMAND_STRING="$command_string" \
  COMMAND_CWD="$cwd" \
  COMMAND_EXIT_STATUS="$exit_status" \
  COMMAND_OVERALL_RESULT="$overall_result" \
  COMMAND_RUN_DIR="$run_dir" \
  "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

run_dir = os.environ["COMMAND_RUN_DIR"]
data = {
    "timestamp": os.environ["COMMAND_TIMESTAMP"],
    "command": os.environ["COMMAND_STRING"],
    "cwd": os.environ["COMMAND_CWD"],
    "exit_status": int(os.environ["COMMAND_EXIT_STATUS"]),
    "overall_result": os.environ["COMMAND_OVERALL_RESULT"],
    "evidence": {
        "command": f"{run_dir}/command.txt",
        "cwd": f"{run_dir}/cwd.txt",
        "stdout": f"{run_dir}/stdout.txt",
        "stderr": f"{run_dir}/stderr.txt",
        "exit_status": f"{run_dir}/exit-status.txt",
    },
}
Path(os.environ["COMMAND_SUMMARY_JSON"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
}

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for command summary writes"
  exit 1
fi

create_run_dir
cwd="$(pwd)"
command_string="$(quote_command "$@")"
printf '%s\n' "$command_string" > "$command_file"
printf '%s\n' "$cwd" > "$cwd_file"

set +e
"$@" >"$stdout_file" 2>"$stderr_file"
command_status=$?
set -e

printf '%s\n' "$command_status" > "$exit_status_file"

if [ "$command_status" -eq 0 ]; then
  write_summary "pass" "$command_status"
  echo "COMMAND_RUN_RESULT=pass"
  echo "Command run directory: $run_dir"
  exit 0
fi

write_summary "fail" "$command_status"
echo "COMMAND_RUN_RESULT=fail"
echo "Command run directory: $run_dir"
exit "$command_status"
```

- [x] **Step 5: Add install assertions**

In `tests/harness/static-install.sh`, add `scripts/agent-run.sh` to the
installed required paths list.

- [x] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for command runner tests.

- [x] **Step 7: Commit**

```bash
git add templates/scripts/agent-run.sh tests/harness/command-runner.sh validate-harness.sh tests/harness/static-install.sh
git commit -m "feat: add command ledger runner"
```

## Task 3: Command Ledger Gate

**Files:**
- Create: `templates/scripts/check-command-ledger.sh`
- Create: `tests/harness/command-ledger.sh`
- Modify: `validate-harness.sh`
- Modify: `tests/harness/static-install.sh`

- [ ] **Step 1: Write failing command ledger gate tests**

Create `tests/harness/command-ledger.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

create_valid_command_summary() {
  local root="$1"
  local result="$2"
  local status="$3"
  local run_dir="$root/.agent/command-runs/20260613-010203"

  mkdir -p "$run_dir"
  printf '%s\n' 'printf hello' > "$run_dir/command.txt"
  printf '%s\n' "$root" > "$run_dir/cwd.txt"
  printf '%s\n' 'hello' > "$run_dir/stdout.txt"
  printf '%s\n' '' > "$run_dir/stderr.txt"
  printf '%s\n' "$status" > "$run_dir/exit-status.txt"
  "$(find_python)" - "$run_dir/command-summary.json" "$run_dir" "$result" "$status" "$root" <<'PY'
import json
import sys
from pathlib import Path

summary = Path(sys.argv[1])
run_dir = sys.argv[2]
result = sys.argv[3]
status = int(sys.argv[4])
cwd = sys.argv[5]
summary.write_text(
    json.dumps(
        {
            "timestamp": "20260613-010203",
            "command": "printf hello",
            "cwd": cwd,
            "exit_status": status,
            "overall_result": result,
            "evidence": {
                "command": f"{run_dir}/command.txt",
                "cwd": f"{run_dir}/cwd.txt",
                "stdout": f"{run_dir}/stdout.txt",
                "stderr": f"{run_dir}/stderr.txt",
                "exit_status": f"{run_dir}/exit-status.txt",
            },
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY
}

echo
echo "== Command ledger not required by default =="
command_ledger_skip_root="$tmp_root/command-ledger-skip"
rm -rf "$command_ledger_skip_root"
mkdir -p "$command_ledger_skip_root/.agent" "$command_ledger_skip_root/scripts/lib"
(
  cd "$command_ledger_skip_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: false' > .agent/task.yml
  bash scripts/check-command-ledger.sh > command-ledger-skip.log 2>&1
  assert_contains command-ledger-skip.log "Command ledger evidence is not required."
  assert_contains command-ledger-skip.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger not required by default"

echo
echo "== Command ledger required with passing command summary =="
command_ledger_pass_root="$tmp_root/command-ledger-pass"
rm -rf "$command_ledger_pass_root"
mkdir -p "$command_ledger_pass_root/.agent" "$command_ledger_pass_root/scripts/lib"
(
  cd "$command_ledger_pass_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: true' > .agent/task.yml
  create_valid_command_summary "$PWD" "pass" "0"
  bash scripts/check-command-ledger.sh > command-ledger-pass.log 2>&1
  assert_contains command-ledger-pass.log "Command ledger evidence is required."
  assert_contains command-ledger-pass.log "OK: command summary"
  assert_contains command-ledger-pass.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger required with passing command summary"

echo
echo "== Command ledger required accepts failing command summary =="
command_ledger_fail_summary_root="$tmp_root/command-ledger-fail-summary"
rm -rf "$command_ledger_fail_summary_root"
mkdir -p "$command_ledger_fail_summary_root/.agent" "$command_ledger_fail_summary_root/scripts/lib"
(
  cd "$command_ledger_fail_summary_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: true' > .agent/task.yml
  create_valid_command_summary "$PWD" "fail" "7"
  bash scripts/check-command-ledger.sh > command-ledger-fail-summary.log 2>&1
  assert_contains command-ledger-fail-summary.log "OK: command summary"
  assert_contains command-ledger-fail-summary.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger required accepts failing command summary"

echo
echo "== Command ledger required missing evidence fails =="
command_ledger_missing_root="$tmp_root/command-ledger-missing"
rm -rf "$command_ledger_missing_root"
mkdir -p "$command_ledger_missing_root/.agent" "$command_ledger_missing_root/scripts/lib"
(
  cd "$command_ledger_missing_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: true' > .agent/task.yml
  if bash scripts/check-command-ledger.sh > command-ledger-missing.log 2>&1; then
    echo "ERROR: expected missing command ledger evidence failure"
    exit 1
  fi
  assert_contains command-ledger-missing.log "FAIL: no command ledger evidence found"
  assert_contains command-ledger-missing.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger required missing evidence fails"

echo
echo "== Command ledger malformed summary fails =="
command_ledger_malformed_root="$tmp_root/command-ledger-malformed"
rm -rf "$command_ledger_malformed_root"
mkdir -p "$command_ledger_malformed_root/.agent/command-runs/bad" "$command_ledger_malformed_root/scripts/lib"
(
  cd "$command_ledger_malformed_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: true' > .agent/task.yml
  printf '%s\n' '{not-json' > .agent/command-runs/bad/command-summary.json
  if bash scripts/check-command-ledger.sh > command-ledger-malformed.log 2>&1; then
    echo "ERROR: expected malformed command summary failure"
    exit 1
  fi
  assert_contains command-ledger-malformed.log "FAIL: could not parse"
  assert_contains command-ledger-malformed.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger malformed summary fails"

echo
echo "== Command ledger missing referenced file fails =="
command_ledger_missing_file_root="$tmp_root/command-ledger-missing-file"
rm -rf "$command_ledger_missing_file_root"
mkdir -p "$command_ledger_missing_file_root/.agent" "$command_ledger_missing_file_root/scripts/lib"
(
  cd "$command_ledger_missing_file_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_command_ledger: true' > .agent/task.yml
  create_valid_command_summary "$PWD" "pass" "0"
  rm .agent/command-runs/20260613-010203/stdout.txt
  if bash scripts/check-command-ledger.sh > command-ledger-missing-file.log 2>&1; then
    echo "ERROR: expected missing referenced evidence failure"
    exit 1
  fi
  assert_contains command-ledger-missing-file.log "FAIL: missing evidence file"
  assert_contains command-ledger-missing-file.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger missing referenced file fails"

echo
echo "== Command ledger malformed task YAML failure =="
command_ledger_bad_task_root="$tmp_root/command-ledger-bad-task"
rm -rf "$command_ledger_bad_task_root"
mkdir -p "$command_ledger_bad_task_root/.agent" "$command_ledger_bad_task_root/scripts/lib"
(
  cd "$command_ledger_bad_task_root"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf 'task:\n\tcompletion:\n' > .agent/task.yml
  if bash scripts/check-command-ledger.sh > command-ledger-bad-task.log 2>&1; then
    echo "ERROR: expected malformed task YAML failure"
    exit 1
  fi
  assert_contains command-ledger-bad-task.log "FAIL: could not read task completion flag"
  assert_contains command-ledger-bad-task.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger malformed task YAML failure"
```

- [ ] **Step 2: Source the failing suite**

In `validate-harness.sh`, source the suite after `command-runner.sh`:

```bash
source "$repo_root/tests/harness/command-ledger.sh"
```

- [ ] **Step 3: Run validation to verify the gate is missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/check-command-ledger.sh` does not
exist.

- [ ] **Step 4: Implement `check-command-ledger.sh`**

Create `templates/scripts/check-command-ledger.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-command-ledger.sh [TASK_FILE] [COMMAND_RUNS_DIR]

Defaults:
  TASK_FILE         .agent/task.yml
  COMMAND_RUNS_DIR .agent/command-runs

Requires command ledger evidence only when TASK_FILE contains:
  task.completion.requires_command_ledger: true
EOF
}

task_file=".agent/task.yml"
command_runs_dir=".agent/command-runs"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    task_file="$1"
    command_runs_dir="${2:-$command_runs_dir}"
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

echo "== Command Ledger Gate =="
echo "Task file: $task_file"
echo "Command runs directory: $command_runs_dir"

if [ ! -f "$task_file" ]; then
  echo "Command ledger evidence is not required."
  echo "COMMAND_LEDGER_RESULT=pass"
  exit 0
fi

if [ ! -f "$reader" ]; then
  echo "FAIL: YAML reader not found: $reader"
  echo "COMMAND_LEDGER_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "FAIL: python is required for command ledger validation"
  echo "COMMAND_LEDGER_RESULT=fail"
  exit 1
fi

set +e
requires_command_ledger="$("$python_bin" "$reader" "$task_file" "task.completion.requires_command_ledger" --optional 2>&1)"
reader_status=$?
set -e

if [ "$reader_status" -ne 0 ]; then
  echo "FAIL: could not read task completion flag"
  printf '%s\n' "$requires_command_ledger"
  echo "COMMAND_LEDGER_RESULT=fail"
  exit 1
fi

if [ "$requires_command_ledger" != "true" ]; then
  echo "Command ledger evidence is not required."
  echo "COMMAND_LEDGER_RESULT=pass"
  exit 0
fi

echo "Command ledger evidence is required."

if [ ! -d "$command_runs_dir" ]; then
  echo "FAIL: no command ledger evidence found"
  echo "COMMAND_LEDGER_RESULT=fail"
  exit 1
fi

set +e
"$python_bin" - "$command_runs_dir" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
summaries = sorted(root.glob("*/command-summary.json"))
failures = 0


def fail(message):
    global failures
    print(f"FAIL: {message}")
    failures += 1


if not summaries:
    fail("no command ledger evidence found")

for summary in summaries:
    try:
        data = json.loads(summary.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"could not parse {summary}: {exc}")
        continue

    required_top = ["timestamp", "command", "cwd", "exit_status", "overall_result", "evidence"]
    for key in required_top:
        if key not in data:
            fail(f"{summary}: missing {key}")

    if data.get("overall_result") not in {"pass", "fail"}:
        fail(f"{summary}: overall_result must be pass or fail")
    if not isinstance(data.get("exit_status"), int):
        fail(f"{summary}: exit_status must be integer")

    evidence = data.get("evidence")
    if not isinstance(evidence, dict):
        fail(f"{summary}: evidence must be a map")
        continue

    for key in ["command", "cwd", "stdout", "stderr", "exit_status"]:
        value = evidence.get(key)
        if not isinstance(value, str) or not value:
            fail(f"{summary}: evidence.{key} must be non-empty")
            continue
        if not Path(value).is_file():
            fail(f"missing evidence file: {value}")

    if failures == 0:
        print(f"OK: command summary {summary}")

if failures:
    print("COMMAND_LEDGER_RESULT=fail")
    sys.exit(1)

print("COMMAND_LEDGER_RESULT=pass")
PY
status=$?
set -e

exit "$status"
```

- [ ] **Step 5: Add install assertions**

In `tests/harness/static-install.sh`, add `scripts/check-command-ledger.sh` to
the installed required paths list.

- [ ] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for command ledger gate tests.

- [ ] **Step 7: Commit**

```bash
git add templates/scripts/check-command-ledger.sh tests/harness/command-ledger.sh validate-harness.sh tests/harness/static-install.sh
git commit -m "feat: add command ledger evidence gate"
```

## Task 4: Finish Gate Integration

**Files:**
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/finish-examples.sh`
- Modify: `tests/harness/resource-envelope.sh`

- [ ] **Step 1: Add failing finish evidence assertions**

In `tests/harness/lib.sh`, update `assert_run_evidence_files()` to include:

```bash
    command-ledger-result.txt \
```

In `assert_finish_summary_contract()`, add:

```bash
  assert_file_contains "$root" "finish-summary.md" "| check-command-ledger |"
  assert_file_contains "$root" "finish-summary.md" "command-ledger-result.txt"
```

In `assert_finish_json_contract()`, add `"check-command-ledger"` to
`expected_gate_names`.

In `tests/harness/finish-examples.sh`, add this script copy to each fixture that
manually copies finish scripts:

```bash
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
```

In finish pass/fail assertions, add:

```bash
  assert_file_contains "$finish_acceptance_review_root" "command-ledger-result.txt" "Command ledger evidence is not required."
```

Use the matching fixture root in each scenario:

- `$finish_acceptance_review_root`
- `$finish_strict_root`
- `$tdd_required_failure_root`
- `$subagent_required_failure_root`
- `$finish_nongit_root` if that scenario asserts run evidence

In `tests/harness/resource-envelope.sh`, copy the new check script into both
resource fixtures:

```bash
  cp "$repo_root/templates/scripts/check-command-ledger.sh" scripts/check-command-ledger.sh
```

- [ ] **Step 2: Run validation to verify finish integration is missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `agent-finish.sh` does not write
`command-ledger-result.txt` yet.

- [ ] **Step 3: Wire command ledger into `agent-finish.sh` state**

In `templates/scripts/agent-finish.sh`, add variables near the other result
files:

```bash
command_ledger_result_file="$run_dir/command-ledger-result.txt"
```

Add status variable near the other gate statuses:

```bash
command_ledger_status=""
```

- [ ] **Step 4: Add command ledger to Markdown summary**

In `write_summary()`, add this row after `check-interventions` and before
`check-sandbox-evidence`:

```bash
    echo "| check-command-ledger | $command_ledger_status | $command_ledger_result_file |"
```

- [ ] **Step 5: Add command ledger to JSON summary**

In `write_json_summary()`, add environment entries:

```bash
  AGENT_FINISH_COMMAND_LEDGER_STATUS="${command_ledger_status:-0}" \
  AGENT_FINISH_COMMAND_LEDGER_EVIDENCE="$command_ledger_result_file" \
```

In the Python `gates` list, add after `check-interventions`:

```python
        {
            "name": "check-command-ledger",
            "exit_status": int(env["AGENT_FINISH_COMMAND_LEDGER_STATUS"]),
            "evidence": env["AGENT_FINISH_COMMAND_LEDGER_EVIDENCE"],
        },
```

- [ ] **Step 6: Run the command ledger gate in strict and best-effort modes**

In both strict and best-effort gate sequences, add after
`check-interventions` and before `check-sandbox-evidence`:

```bash
  run_gate "check-command-ledger" "$command_ledger_result_file" bash scripts/check-command-ledger.sh
  command_ledger_status="$last_status"
```

- [ ] **Step 7: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for finish evidence examples and resource-envelope scenarios.

- [ ] **Step 8: Commit**

```bash
git add templates/scripts/agent-finish.sh tests/harness/lib.sh tests/harness/finish-examples.sh tests/harness/resource-envelope.sh
git commit -m "feat: include command ledger in finish evidence"
```

## Task 5: Examples, Docs, And Boundary Alignment

**Files:**
- Modify: `examples/universal-minimal-repo/scripts/agent-run.sh`
- Modify: `examples/universal-minimal-repo/scripts/check-command-ledger.sh`
- Modify: `examples/universal-minimal-repo/.agent/task.yml`
- Modify: `tests/harness/template-sync.sh`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/runtime-boundaries.md`
- Modify: `docs/superpowers-integration.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `skills/verification-gate/SKILL.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Mirror copied example scripts**

Run:

```bash
cp templates/scripts/agent-run.sh examples/universal-minimal-repo/scripts/agent-run.sh
cp templates/scripts/check-command-ledger.sh examples/universal-minimal-repo/scripts/check-command-ledger.sh
chmod +x examples/universal-minimal-repo/scripts/agent-run.sh examples/universal-minimal-repo/scripts/check-command-ledger.sh
```

- [ ] **Step 2: Add template sync assertions**

In `tests/harness/template-sync.sh`, add:

```bash
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/agent-run.sh"
assert_exists "$repo_root/examples/universal-minimal-repo/scripts/check-command-ledger.sh"
assert_files_match \
  "$repo_root/templates/scripts/agent-run.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/agent-run.sh"
assert_files_match \
  "$repo_root/templates/scripts/check-command-ledger.sh" \
  "$repo_root/examples/universal-minimal-repo/scripts/check-command-ledger.sh"
```

- [ ] **Step 3: Add failing doc consistency assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_contains "$repo_root/README.md" "Command Ledger"
assert_contains "$repo_root/README.md" "agent-run"
assert_contains "$repo_root/README.md" "requires_command_ledger"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Command ledger"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Explicit command ledger evidence"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Full tool-call replay"
assert_contains "$repo_root/docs/superpowers-integration.md" "Command ledger"
assert_contains "$repo_root/templates/AGENTS.md" "agent-run"
assert_contains "$repo_root/templates/CLAUDE.md" "agent-run"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "agent-run"
```

- [ ] **Step 4: Run validation to verify docs are not updated yet**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL on doc consistency assertions.

- [ ] **Step 5: Update README command ledger section**

In `README.md`, add this section after `## Evidence And Optional Gates` and
before `## Episode And Audit Evidence`:

```markdown
## Command Ledger

For tasks that need replayable local command evidence, run important commands
through the installed command runner:

```text
agent-run -- npm test
agent-run -- bash scripts/agent-verify.sh --best-effort
```

The runner writes `.agent/command-runs/<timestamp>/command-summary.json` plus
stdout, stderr, command, cwd, and exit-status evidence. A failed wrapped command
still writes evidence and returns the original exit status.

When `.agent/task.yml` contains `completion.requires_command_ledger: true`,
`scripts/agent-finish.sh` validates that command ledger evidence exists and is
structurally complete. This is explicit local command evidence, not automatic
tool-call interception or provider-native trace capture.
```

- [ ] **Step 6: Update Traditional Chinese README**

In `README.zh-TW.md`, add a concise `## Command Ledger` section near the
English README's equivalent location:

```markdown
## Command Ledger

需要可回放的本機命令證據時，請透過已安裝的 command runner 執行重要命令：

```text
agent-run -- npm test
agent-run -- bash scripts/agent-verify.sh --best-effort
```

runner 會寫入 `.agent/command-runs/<timestamp>/command-summary.json`，以及
stdout、stderr、command、cwd、exit-status evidence。被包裝的命令失敗時仍會留下
evidence，並回傳原本的 exit status。

當 `.agent/task.yml` 設定 `completion.requires_command_ledger: true` 時，
`scripts/agent-finish.sh` 會驗證 command ledger evidence 是否存在且結構完整。
這是明確使用的本機命令證據，不是自動 tool-call interception 或 provider-native
trace capture。
```

- [ ] **Step 7: Update usage and Superpowers docs**

In `docs/USAGE_WITH_AGENTS.md`, add `scripts/agent-run.sh` to the scripts list
and add a short paragraph:

```markdown
Use command ledger evidence when important commands need replayable local
evidence. Run those commands through the installed command runner before
finish. When `completion.requires_command_ledger: true`, the finish gate
validates `.agent/command-runs/<timestamp>/command-summary.json` evidence.
```

In `docs/superpowers-integration.md`, add a row or paragraph mapping command
ledger evidence to verification discipline:

```markdown
Command ledger evidence complements `verification-before-completion`: use the
installed command runner for important local commands when a task requires
replayable command evidence.
```

- [ ] **Step 8: Update runtime boundaries**

In `docs/runtime-boundaries.md`, add under `Implemented`:

```markdown
- Explicit command ledger evidence for commands run through the installed
  command runner.
```

Keep `Full tool-call replay outside local script evidence` and
`Provider-native trace capture unless an external runtime supplies it` under
`Not Implemented`.

- [ ] **Step 9: Update templates and skill guidance**

In `templates/AGENTS.md` and `templates/CLAUDE.md`, add a short bullet near
verification guidance:

```markdown
- If the task requires command ledger evidence, run important commands through
  the installed command runner before final finish.
```

In `skills/verification-gate/SKILL.md`, add:

```markdown
If `.agent/task.yml` sets `completion.requires_command_ledger: true`, record
important local verification commands through the installed command runner
before running the finish gate.
```

- [ ] **Step 10: Update changelog**

In `CHANGELOG.md`, add under `Unreleased`:

```markdown
- Add explicit command ledger evidence through an installed command runner and
  optional finish gate.
```

- [ ] **Step 11: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for template sync and doc consistency.

- [ ] **Step 12: Commit**

```bash
git add examples/universal-minimal-repo/scripts/agent-run.sh examples/universal-minimal-repo/scripts/check-command-ledger.sh examples/universal-minimal-repo/.agent/task.yml tests/harness/template-sync.sh tests/harness/doc-consistency.sh README.md README.zh-TW.md docs/USAGE_WITH_AGENTS.md docs/runtime-boundaries.md docs/superpowers-integration.md templates/AGENTS.md templates/CLAUDE.md skills/verification-gate/SKILL.md CHANGELOG.md
git commit -m "docs: document command ledger evidence"
```

## Task 6: Installed Target Smoke And Final Handoff

**Files:**
- Modify: `handoff.md`
- Modify: `docs/superpowers/plans/2026-06-13-command-ledger-evidence.md`

- [ ] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 2: Run doc-link validation**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
```

Expected: `DOC_LINKS_RESULT=pass`.

- [ ] **Step 3: Run installed-target command ledger smoke**

Run:

```bash
target="/private/tmp/agent-harness-command-ledger-target"
rm -rf "$target"
mkdir -p "$target"
git init -q "$target"
bash install-agent-harness.sh --force "$target"
cd "$target"
git config user.email "agent-harness@example.invalid"
git config user.name "Agent Harness Smoke"
git add .
git commit -q -m "chore: install harness"
bash scripts/agent-run.sh -- bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

Expected:

- `COMMAND_RUN_RESULT=pass`
- `AGENT_FINISH_RESULT=pass`
- `.agent/command-runs/<timestamp>/command-summary.json` exists
- `.agent/runs/<timestamp>/command-ledger-result.txt` exists

- [ ] **Step 4: Run source checkout audit**

Run from the source checkout:

```bash
bash templates/scripts/agent-audit.sh
```

Expected: `AGENT_AUDIT_RESULT=pass`.

- [ ] **Step 5: Update handoff**

Update `handoff.md` with:

```markdown
## Current State

Command ledger evidence has been designed and implemented. Installed projects
can run important commands through the command runner, store
`.agent/command-runs/<timestamp>/command-summary.json`, and optionally require
command ledger evidence during finish.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- Installed target command ledger smoke: PASS in `/private/tmp/agent-harness-command-ledger-target`
- `bash templates/scripts/agent-audit.sh`: PASS

## Evidence

- Latest installed command run: `/private/tmp/agent-harness-command-ledger-target/.agent/command-runs/<timestamp>/`
- Latest installed finish run: `/private/tmp/agent-harness-command-ledger-target/.agent/runs/<timestamp>/`
- Latest source audit run: `.agent/audits/<timestamp>/`

## Next Action

Decide whether command ledger evidence should become required for selected
high-risk or release tasks by setting `completion.requires_command_ledger:
true` in those task files.
```

Replace `<timestamp>` values with actual evidence directories.

- [ ] **Step 6: Mark this plan complete**

Mark completed plan steps with `[x]` after validation and handoff are updated.

- [ ] **Step 7: Inspect final status**

Run:

```bash
git status --short
```

Expected: only intended tracked changes plus expected untracked `.agent/`
runtime evidence.

- [ ] **Step 8: Commit**

```bash
git add handoff.md docs/superpowers/plans/2026-06-13-command-ledger-evidence.md
git commit -m "chore: finalize command ledger evidence"
```

## Self-Review

Spec coverage:

- Explicit command runner wrapper: Task 2.
- Optional command ledger gate and result marker: Task 3.
- Task completion contract: Task 1.
- Finish Markdown and JSON summary integration: Task 4.
- Documentation and runtime boundary honesty: Task 5.
- Installed-target smoke and final evidence: Task 6.

Incomplete-content scan:

- No incomplete-content markers are intentionally left in this plan.

Type and name consistency:

- Task flag is consistently `requires_command_ledger`.
- Command run evidence directory is consistently `.agent/command-runs/<timestamp>/`.
- Command runner marker is consistently `COMMAND_RUN_RESULT=pass|fail`.
- Command ledger gate marker is consistently `COMMAND_LEDGER_RESULT=pass|fail`.
- Finish gate name is consistently `check-command-ledger`.

Plan complete and saved to `docs/superpowers/plans/2026-06-13-command-ledger-evidence.md`.
