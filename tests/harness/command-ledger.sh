#!/usr/bin/env bash
set -euo pipefail

create_command_ledger_root() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/scripts/lib"
  cp "$repo_root/templates/scripts/check-command-ledger.sh" "$root/scripts/check-command-ledger.sh"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" "$root/scripts/lib/read-yaml.py"
  chmod +x "$root/scripts/check-command-ledger.sh"
}

write_command_ledger_task() {
  local root="$1"
  local required="$2"
  mkdir -p "$root/.agent"
  printf 'task:\n  completion:\n    requires_command_ledger: %s\n' "$required" > "$root/.agent/task.yml"
}

create_valid_command_summary() {
  local root="$1"
  local run_name="$2"
  local overall_result="$3"
  local exit_status="$4"
  local run_dir="$root/.agent/command-runs/$run_name"

  mkdir -p "$run_dir"
  printf '%s\n' 'printf command' > "$run_dir/command.txt"
  printf '%s\n' "$root" > "$run_dir/cwd.txt"
  printf '%s\n' 'stdout' > "$run_dir/stdout.txt"
  printf '%s\n' 'stderr' > "$run_dir/stderr.txt"
  printf '%s\n' "$exit_status" > "$run_dir/exit-status.txt"

  COMMAND_SUMMARY="$run_dir/command-summary.json" \
  COMMAND_ROOT="$root" \
  COMMAND_RUN_NAME="$run_name" \
  COMMAND_RESULT="$overall_result" \
  COMMAND_STATUS="$exit_status" \
  "$(find_python)" - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["COMMAND_ROOT"])
run_name = os.environ["COMMAND_RUN_NAME"]
run_dir = root / ".agent" / "command-runs" / run_name
data = {
    "timestamp": "20260619-010203",
    "command": "printf command",
    "cwd": str(root),
    "exit_status": int(os.environ["COMMAND_STATUS"]),
    "overall_result": os.environ["COMMAND_RESULT"],
    "evidence": {
        "command": str(run_dir / "command.txt"),
        "cwd": str(run_dir / "cwd.txt"),
        "stdout": str(run_dir / "stdout.txt"),
        "stderr": str(run_dir / "stderr.txt"),
        "exit_status": str(run_dir / "exit-status.txt"),
    },
}
Path(os.environ["COMMAND_SUMMARY"]).write_text(json.dumps(data) + "\n", encoding="utf-8")
PY
}

echo
echo "== Command ledger optional pass =="
command_ledger_optional_root="$tmp_root/command-ledger-optional"
create_command_ledger_root "$command_ledger_optional_root"
write_command_ledger_task "$command_ledger_optional_root" false
(
  cd "$command_ledger_optional_root"
  bash scripts/check-command-ledger.sh > command-ledger.log 2>&1
  assert_contains command-ledger.log "Command ledger evidence is not required."
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger optional pass"

echo
echo "== Command ledger accepts successful command evidence =="
command_ledger_pass_root="$tmp_root/command-ledger-pass"
create_command_ledger_root "$command_ledger_pass_root"
write_command_ledger_task "$command_ledger_pass_root" true
create_valid_command_summary "$command_ledger_pass_root" "20260619-010203" pass 0
(
  cd "$command_ledger_pass_root"
  bash scripts/check-command-ledger.sh > command-ledger.log 2>&1
  assert_contains command-ledger.log "Command ledger evidence is required."
  assert_contains command-ledger.log "OK: command summary"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger accepts successful command evidence"

echo
echo "== Command ledger accepts failed command evidence =="
command_ledger_failed_command_root="$tmp_root/command-ledger-failed-command"
create_command_ledger_root "$command_ledger_failed_command_root"
write_command_ledger_task "$command_ledger_failed_command_root" true
create_valid_command_summary "$command_ledger_failed_command_root" "20260619-010204" fail 7
(
  cd "$command_ledger_failed_command_root"
  bash scripts/check-command-ledger.sh > command-ledger.log 2>&1
  assert_contains command-ledger.log "OK: command summary"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=pass"
)
pass "command ledger accepts failed command evidence"

echo
echo "== Command ledger rejects missing evidence =="
command_ledger_missing_root="$tmp_root/command-ledger-missing"
create_command_ledger_root "$command_ledger_missing_root"
write_command_ledger_task "$command_ledger_missing_root" true
(
  cd "$command_ledger_missing_root"
  if bash scripts/check-command-ledger.sh > command-ledger.log 2>&1; then
    echo "ERROR: expected missing command ledger evidence failure"
    exit 1
  fi
  assert_contains command-ledger.log "FAIL: no command ledger evidence found"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger rejects missing evidence"

echo
echo "== Command ledger rejects malformed summary =="
command_ledger_malformed_summary_root="$tmp_root/command-ledger-malformed-summary"
create_command_ledger_root "$command_ledger_malformed_summary_root"
write_command_ledger_task "$command_ledger_malformed_summary_root" true
mkdir -p "$command_ledger_malformed_summary_root/.agent/command-runs/bad"
printf '%s\n' '{bad json' > "$command_ledger_malformed_summary_root/.agent/command-runs/bad/command-summary.json"
(
  cd "$command_ledger_malformed_summary_root"
  if bash scripts/check-command-ledger.sh > command-ledger.log 2>&1; then
    echo "ERROR: expected malformed command summary failure"
    exit 1
  fi
  assert_contains command-ledger.log "FAIL: could not parse"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger rejects malformed summary"

echo
echo "== Command ledger rejects missing referenced evidence =="
command_ledger_missing_file_root="$tmp_root/command-ledger-missing-file"
create_command_ledger_root "$command_ledger_missing_file_root"
write_command_ledger_task "$command_ledger_missing_file_root" true
create_valid_command_summary "$command_ledger_missing_file_root" "20260619-010205" pass 0
rm "$command_ledger_missing_file_root/.agent/command-runs/20260619-010205/stdout.txt"
(
  cd "$command_ledger_missing_file_root"
  if bash scripts/check-command-ledger.sh > command-ledger.log 2>&1; then
    echo "ERROR: expected missing referenced evidence failure"
    exit 1
  fi
  assert_contains command-ledger.log "FAIL: missing evidence file"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger rejects missing referenced evidence"

echo
echo "== Command ledger rejects malformed task YAML =="
command_ledger_bad_task_root="$tmp_root/command-ledger-bad-task"
create_command_ledger_root "$command_ledger_bad_task_root"
mkdir -p "$command_ledger_bad_task_root/.agent"
printf 'task:\n\tcompletion:\n' > "$command_ledger_bad_task_root/.agent/task.yml"
(
  cd "$command_ledger_bad_task_root"
  if bash scripts/check-command-ledger.sh > command-ledger.log 2>&1; then
    echo "ERROR: expected malformed task YAML failure"
    exit 1
  fi
  assert_contains command-ledger.log "FAIL: could not read task completion flag"
  assert_contains command-ledger.log "COMMAND_LEDGER_RESULT=fail"
)
pass "command ledger rejects malformed task YAML"
