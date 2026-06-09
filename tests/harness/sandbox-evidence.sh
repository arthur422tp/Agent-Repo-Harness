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

echo
echo "== Sandbox evidence malformed task YAML failure =="
sandbox_bad_task_root="$tmp_root/sandbox-bad-task"
rm -rf "$sandbox_bad_task_root"
mkdir -p "$sandbox_bad_task_root/.agent" "$sandbox_bad_task_root/scripts/lib"
(
  cd "$sandbox_bad_task_root"
  cp "$repo_root/templates/scripts/check-sandbox-evidence.sh" scripts/check-sandbox-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '    completion:' \
    '  bad: true' \
    > .agent/task.yml
  if bash scripts/check-sandbox-evidence.sh > sandbox-bad-task.log 2>&1; then
    echo "ERROR: expected sandbox evidence malformed task failure"
    exit 1
  fi
  assert_contains sandbox-bad-task.log "SANDBOX_EVIDENCE_RESULT=fail"
)
pass "sandbox evidence malformed task YAML failure"
