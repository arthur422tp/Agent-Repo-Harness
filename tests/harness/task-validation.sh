#!/usr/bin/env bash
set -euo pipefail

echo "== YAML reader behavior =="
rm -rf "$yaml_reader_root"
mkdir -p "$yaml_reader_root"
(
  cd "$yaml_reader_root"
  copy_fixture yaml-reader-harness.yml harness.yml
  reader_log="$yaml_reader_root/read-yaml.log"
  "$(find_python)" "$repo_root/templates/scripts/lib/read-yaml.py" \
    harness.yml verification.required --list-fields name command \
    >"$reader_log" 2>&1
  assert_contains "$reader_log" $'quoted check\tbash -n scripts/example.sh'
  assert_contains "$reader_log" $'bare-check\tprintf'

  jsonl_log="$yaml_reader_root/read-yaml-jsonl.log"
  "$(find_python)" "$repo_root/templates/scripts/lib/read-yaml.py" \
    harness.yml verification.required --list-fields-jsonl name command \
    >"$jsonl_log" 2>&1
  assert_contains "$jsonl_log" '"name": "quoted check"'
  assert_contains "$jsonl_log" '"command": "bash -n scripts/example.sh"'

  missing_log="$yaml_reader_root/read-yaml-missing.log"
  if "$(find_python)" "$repo_root/templates/scripts/lib/read-yaml.py" \
    harness.yml verification.missing >"$missing_log" 2>&1
  then
    echo "ERROR: expected missing path failure"
    exit 1
  fi
  assert_contains "$missing_log" "missing path: verification.missing"
)
pass "YAML reader behavior"

echo
echo "== Task validation shared reader behavior =="
rm -rf "$task_config_root"
mkdir -p "$task_config_root/.agent" "$task_config_root/scripts/lib"
(
  cd "$task_config_root"
  cp "$repo_root/templates/.agent/task.yml" .agent/task.yml
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  task_log="$task_config_root/validate-task-valid.log"
  bash scripts/validate-task.sh >"$task_log" 2>&1
  assert_contains "$task_log" "OK: .agent/task.yml contains task.status"
  assert_contains "$task_log" "OK: .agent/task.yml contains task.completion"
  assert_contains "$task_log" "TASK_VALIDATION_RESULT=pass"
)
pass "valid task config through shared reader"

echo
echo "== Task validation malformed config failure =="
rm -rf "$task_bad_config_root"
mkdir -p "$task_bad_config_root/.agent" "$task_bad_config_root/scripts/lib"
(
  cd "$task_bad_config_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf 'task:\n\tstatus: "in_progress"\n' > .agent/task.yml
  task_log="$task_bad_config_root/validate-task-bad-config.log"
  if bash scripts/validate-task.sh >"$task_log" 2>&1; then
    echo "ERROR: expected malformed task config validation failure"
    exit 1
  fi
  assert_contains "$task_log" "FAIL: .agent/task.yml could not be parsed"
  assert_contains "$task_log" "tabs are not supported for indentation"
  assert_contains "$task_log" "TASK_VALIDATION_RESULT=fail"
)
pass "malformed task config failure"

echo
echo "== Task validation nested key failure =="
rm -rf "$task_missing_nested_root"
mkdir -p "$task_missing_nested_root/.agent" "$task_missing_nested_root/scripts/lib"
(
  cd "$task_missing_nested_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  copy_fixture task-root-status.yml .agent/task.yml
  task_log="$task_missing_nested_root/validate-task-missing-nested.log"
  if bash scripts/validate-task.sh >"$task_log" 2>&1; then
    echo "ERROR: expected missing nested task status validation failure"
    exit 1
  fi
  assert_contains "$task_log" "FAIL: .agent/task.yml missing key: task.status"
  assert_contains "$task_log" "TASK_VALIDATION_RESULT=fail"
)
pass "nested task keys checked through shared reader"

echo
echo "== Task validation type failure =="
rm -rf "$task_invalid_types_root"
mkdir -p "$task_invalid_types_root/.agent" "$task_invalid_types_root/scripts/lib"
(
  cd "$task_invalid_types_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  copy_fixture task-invalid-types.yml .agent/task.yml
  task_log="$task_invalid_types_root/validate-task-invalid-types.log"
  if bash scripts/validate-task.sh >"$task_log" 2>&1; then
    echo "ERROR: expected invalid task type validation failure"
    exit 1
  fi
  assert_contains "$task_log" "FAIL: .agent/task.yml task.status must be one of"
  assert_contains "$task_log" "FAIL: .agent/task.yml task.allowed_paths must be an array or null"
  assert_contains "$task_log" "FAIL: .agent/task.yml task.completion.requires_verification must be boolean"
  assert_contains "$task_log" "TASK_VALIDATION_RESULT=fail"
)
pass "task type validation failure"

echo
