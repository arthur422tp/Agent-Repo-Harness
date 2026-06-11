#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-sandbox-smoke.XXXXXX")"
target_root="$tmp_root/target"
keep_target="${HARNESS_SANDBOX_SMOKE_KEEP_TARGET:-1}"
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
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/sandbox-timeout" <<'SH'
#!/usr/bin/env bash
shift
exec "$@"
SH
chmod +x "$tmp_root/bin/sandbox-timeout"
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
    HARNESS_SANDBOX_TIMEOUT_BIN="$tmp_root/bin/sandbox-timeout" \
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
