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
  assert_contains "$task_log" "FAIL: .agent/task.yml task.completion.requires_architecture_evidence must be boolean"
  assert_contains "$task_log" "TASK_VALIDATION_RESULT=fail"
)
pass "task type validation failure"

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

echo
echo "== Task validation accepts known verification profile =="
verification_profile_task_root="$tmp_root/task-verification-profile"
rm -rf "$verification_profile_task_root"
mkdir -p "$verification_profile_task_root/.agent" "$verification_profile_task_root/scripts/lib"
(
  cd "$verification_profile_task_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  printf '%s\n' \
    'task:' \
    '  status: "in_progress"' \
    '  goal: "Build package baseline"' \
    '  verification_profile: "bootstrap"' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion: {}' \
    > .agent/task.yml
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "OK: .agent/task.yml task.verification_profile selects bootstrap"
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "task validation accepts known verification profile"

echo
echo "== Task validation rejects unknown verification profile =="
(
  cd "$verification_profile_task_root"
  sed 's/verification_profile: "bootstrap"/verification_profile: "missing"/' \
    .agent/task.yml > .agent/task-unknown.yml
  if bash scripts/validate-task.sh .agent/task-unknown.yml .agent/harness.yml \
    > unknown.log 2>&1; then
    echo "ERROR: expected unknown verification profile failure"
    exit 1
  fi
  assert_contains unknown.log "task.verification_profile names unknown profile: missing"
  assert_contains unknown.log "TASK_VALIDATION_RESULT=fail"
)
pass "task validation rejects unknown verification profile"

echo
echo "== Task validation rejects malformed verification profile name =="
(
  cd "$verification_profile_task_root"
  sed 's/verification_profile: "bootstrap"/verification_profile: "bad.profile"/' \
    .agent/task.yml > .agent/task-malformed-profile.yml
  if bash scripts/validate-task.sh .agent/task-malformed-profile.yml .agent/harness.yml \
    > malformed-profile.log 2>&1; then
    echo "ERROR: expected malformed verification profile failure"
    exit 1
  fi
  assert_contains malformed-profile.log "must match [A-Za-z0-9][A-Za-z0-9_-]*"
)
pass "task validation rejects malformed verification profile name"

echo
echo "== Config validation rejects empty verification profile commands =="
verification_profile_bad_config_root="$tmp_root/verification-profile-bad-config"
rm -rf "$verification_profile_bad_config_root"
mkdir -p "$verification_profile_bad_config_root/.agent" \
  "$verification_profile_bad_config_root/scripts/lib"
(
  cd "$verification_profile_bad_config_root"
  cp "$repo_root/templates/scripts/validate-config.sh" scripts/validate-config.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'name: Bad Profiles' \
    'version: 1' \
    'mode: lightweight' \
    'paths:' \
    '  agent_map: agent.md' \
    '  handoff: handoff.md' \
    '  task_state: .agent/task.yml' \
    'scripts:' \
    '  preflight: scripts/agent-preflight.sh' \
    '  finish: scripts/agent-finish.sh' \
    '  verify: scripts/agent-verify.sh' \
    '  check_policy: scripts/check-policy.sh' \
    '  check_scope: scripts/check-scope.sh' \
    'verification:' \
    '  final_gate_command: scripts/agent-finish.sh' \
    '  profiles:' \
    '    bootstrap:' \
    '      required: []' \
    > .agent/harness.yml
  printf '%s\n' \
    'version: 1' \
    'default_mode: warn' \
    'risk_files: {}' \
    'rules: []' \
    > .agent/policy.yml
  if bash scripts/validate-config.sh > invalid-profile-config.log 2>&1; then
    echo "ERROR: expected empty verification profile failure"
    exit 1
  fi
  assert_contains invalid-profile-config.log "verification profiles are invalid"
  assert_contains invalid-profile-config.log "CONFIG_VALIDATION_RESULT=fail"
)
pass "config validation rejects empty verification profile commands"
