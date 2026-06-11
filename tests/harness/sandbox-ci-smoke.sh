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
echo "== Sandbox CI smoke skips when runner daemon is unavailable =="
sandbox_ci_daemon_skip_root="$tmp_root/sandbox-ci-daemon-skip"
rm -rf "$sandbox_ci_daemon_skip_root"
mkdir -p "$sandbox_ci_daemon_skip_root/bin"
(
  cd "$sandbox_ci_daemon_skip_root"
  cat > bin/docker <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "info" ]; then
  printf '%s\n' "fake docker daemon unavailable" >&2
  exit 1
fi
printf '%s\n' "fake docker should not run" >&2
exit 1
SH
  chmod +x bin/docker

  if PATH="$PWD/bin:$PATH" \
    bash "$repo_root/ci/sandbox-smoke.sh" > sandbox-ci-daemon-skip.log 2>&1
  then
    assert_contains sandbox-ci-daemon-skip.log "SANDBOX_CI_SMOKE_RESULT=skip"
    assert_contains sandbox-ci-daemon-skip.log "Docker or Podman is unavailable."
    assert_not_contains sandbox-ci-daemon-skip.log "fake docker should not run"
  else
    echo "ERROR: expected unavailable runner daemon to skip without failing"
    cat sandbox-ci-daemon-skip.log
    exit 1
  fi
)
pass "sandbox CI smoke skips when runner daemon is unavailable"

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
  assert_contains "$target_root/fake-docker-args.txt" "bash -n scripts/*.sh"
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
