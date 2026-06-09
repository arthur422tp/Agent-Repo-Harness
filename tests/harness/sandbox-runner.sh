#!/usr/bin/env bash
set -euo pipefail

assert_sandbox_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq -- "$expected" "$file"; then
    echo "ERROR: expected output to contain: $expected"
    echo "File: $file"
    exit 1
  fi
}

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
mkdir -p \
  "$sandbox_runner_pass_root/.agent" \
  "$sandbox_runner_pass_root/scripts/lib" \
  "$sandbox_runner_pass_root/bin"
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
  cat > bin/fake-timeout <<'SH'
#!/usr/bin/env bash
shift
exec "$@"
SH
  chmod +x bin/fake-docker bin/fake-timeout
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
  SAFE_ENV="secret-value" \
    HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_TIMEOUT_BIN="$PWD/bin/fake-timeout" \
    bash scripts/agent-sandbox-run.sh > sandbox-pass.log 2>&1
  assert_contains sandbox-pass.log "SANDBOX_RUN_RESULT=pass"
  sandbox_summary="$(
    find .agent/sandbox-runs -type f -name sandbox-summary.json |
      sort |
      tail -n 1
  )"
  assert_exists "$sandbox_summary"
  assert_file="$(dirname "$sandbox_summary")/stdout.txt"
  assert_contains "$assert_file" "fake sandbox stdout"
  assert_sandbox_contains fake-runner-args.txt "--network"
  assert_sandbox_contains fake-runner-args.txt "none"
  assert_sandbox_contains fake-runner-args.txt "--cpus"
  assert_sandbox_contains fake-runner-args.txt "2"
  assert_sandbox_contains fake-runner-args.txt "--memory"
  assert_sandbox_contains fake-runner-args.txt "2g"
  assert_not_contains "$sandbox_summary" "secret-value"
  assert_contains "$sandbox_summary" '"overall_result": "pass"'
)
pass "sandbox runner fake pass writes evidence"

echo
echo "== Sandbox runner fake failure writes evidence =="
sandbox_runner_fail_root="$tmp_root/sandbox-runner-fail"
rm -rf "$sandbox_runner_fail_root"
mkdir -p \
  "$sandbox_runner_fail_root/.agent" \
  "$sandbox_runner_fail_root/scripts/lib" \
  "$sandbox_runner_fail_root/bin"
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
  if HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    bash scripts/agent-sandbox-run.sh > sandbox-fail.log 2>&1; then
    echo "ERROR: expected sandbox runner failure"
    exit 1
  fi
  assert_contains sandbox-fail.log "SANDBOX_RUN_RESULT=fail"
  sandbox_summary="$(
    find .agent/sandbox-runs -type f -name sandbox-summary.json |
      sort |
      tail -n 1
  )"
  assert_exists "$sandbox_summary"
  assert_contains "$sandbox_summary" '"exit_status": 7'
  assert_contains "$sandbox_summary" '"overall_result": "fail"'
  assert_contains "$(dirname "$sandbox_summary")/stderr.txt" "failure stderr"
)
pass "sandbox runner fake failure writes evidence"

echo
echo "== Sandbox runner best-effort failure writes evidence without failing =="
sandbox_runner_best_effort_root="$tmp_root/sandbox-runner-best-effort"
rm -rf "$sandbox_runner_best_effort_root"
mkdir -p \
  "$sandbox_runner_best_effort_root/.agent" \
  "$sandbox_runner_best_effort_root/scripts/lib" \
  "$sandbox_runner_best_effort_root/bin"
(
  cd "$sandbox_runner_best_effort_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "best-effort failure stderr" >&2
exit 9
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
    > .agent/harness.yml
  HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    bash scripts/agent-sandbox-run.sh --best-effort \
    > sandbox-best-effort.log 2>&1
  assert_contains sandbox-best-effort.log "SANDBOX_RUN_RESULT=fail"
  assert_contains sandbox-best-effort.log "Best-effort mode: sandbox failure did not fail command."
  sandbox_summary="$(
    find .agent/sandbox-runs -type f -name sandbox-summary.json |
      sort |
      tail -n 1
  )"
  assert_exists "$sandbox_summary"
  assert_contains "$sandbox_summary" '"exit_status": 9'
  assert_contains "$sandbox_summary" '"overall_result": "fail"'
)
pass "sandbox runner best-effort failure writes evidence without failing"

echo
echo "== Sandbox runner avoids same-second evidence overwrite =="
sandbox_runner_collision_root="$tmp_root/sandbox-runner-collision"
rm -rf "$sandbox_runner_collision_root"
mkdir -p \
  "$sandbox_runner_collision_root/.agent" \
  "$sandbox_runner_collision_root/scripts/lib" \
  "$sandbox_runner_collision_root/bin"
(
  cd "$sandbox_runner_collision_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > bin/date <<'SH'
#!/usr/bin/env bash
printf '%s\n' "20260606-030000"
SH
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "collision stdout"
exit 0
SH
  chmod +x bin/date bin/fake-docker
  printf '%s\n' \
    'sandbox:' \
    '  enabled: true' \
    '  runner: docker' \
    '  mode: verification' \
    '  command: "bash scripts/agent-finish.sh --strict"' \
    '  workspace:' \
    '    strategy: "copy"' \
    '  network: "disabled"' \
    > .agent/harness.yml
  PATH="$PWD/bin:$PATH" \
    HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    bash scripts/agent-sandbox-run.sh > first.log 2>&1
  PATH="$PWD/bin:$PATH" \
    HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    bash scripts/agent-sandbox-run.sh > second.log 2>&1
  assert_exists ".agent/sandbox-runs/20260606-030000/sandbox-summary.json"
  assert_exists ".agent/sandbox-runs/20260606-030000-01/sandbox-summary.json"
)
pass "sandbox runner avoids same-second evidence overwrite"

echo
echo "== Sandbox runner explicit timeout requires timeout command =="
sandbox_runner_timeout_root="$tmp_root/sandbox-runner-timeout"
rm -rf "$sandbox_runner_timeout_root"
mkdir -p \
  "$sandbox_runner_timeout_root/.agent" \
  "$sandbox_runner_timeout_root/scripts/lib" \
  "$sandbox_runner_timeout_root/bin"
(
  cd "$sandbox_runner_timeout_root"
  cp "$repo_root/templates/scripts/agent-sandbox-run.sh" scripts/agent-sandbox-run.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
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
    '  resource_limits:' \
    '    timeout_seconds: 60' \
    > .agent/harness.yml
  if HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_TIMEOUT_BIN="$PWD/bin/missing-timeout" \
    bash scripts/agent-sandbox-run.sh > sandbox-timeout.log 2>&1; then
    echo "ERROR: expected sandbox runner timeout dependency failure"
    exit 1
  fi
  assert_contains \
    sandbox-timeout.log \
    "ERROR: sandbox timeout_seconds is configured, but $PWD/bin/missing-timeout is not available"
  assert_contains sandbox-timeout.log "SANDBOX_RUN_RESULT=fail"
)
pass "sandbox runner explicit timeout requires timeout command"
