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
  printf '%s\n' '#!/usr/bin/env bash' 'printf '\''%s\n'\'' "20260613-010203"' > bin/date
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
