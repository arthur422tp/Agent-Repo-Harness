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

refresh_evidence_paths() {
  stdout_file="$run_dir/stdout.txt"
  stderr_file="$run_dir/stderr.txt"
  command_file="$run_dir/command.txt"
  exit_status_file="$run_dir/exit-status.txt"
  summary_json_file="$run_dir/sandbox-summary.json"
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
timeout_configured="$timeout_seconds"
env_allow_json="$(
  "$python_bin" "$reader" "$harness_file" "sandbox.env.allow" \
    --optional 2>/dev/null || true
)"

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

timeout_bin="${HARNESS_SANDBOX_TIMEOUT_BIN:-timeout}"
if [ -n "$timeout_configured" ] && ! command -v "$timeout_bin" >/dev/null 2>&1; then
  echo "ERROR: sandbox timeout_seconds is configured, but $timeout_bin is not available"
  echo "SANDBOX_RUN_RESULT=fail"
  exit 1
fi

create_run_dir
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
  tar --exclude './.git' --exclude './.agent/sandbox-runs' -cf - . |
    (cd "$workspace_dir" && tar -xf -)
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
if command -v "$timeout_bin" >/dev/null 2>&1; then
  "$timeout_bin" "$timeout_seconds" "$runner_bin" run --rm \
    "${network_args[@]+"${network_args[@]}"}" \
    "${resource_args[@]+"${resource_args[@]}"}" \
    "${env_args[@]+"${env_args[@]}"}" \
    -v "$workspace_dir:/workspace" \
    -w /workspace \
    "$image" \
    bash -lc "$sandbox_command" >"$stdout_file" 2>"$stderr_file"
  sandbox_status=$?
else
  "$runner_bin" run --rm \
    "${network_args[@]+"${network_args[@]}"}" \
    "${resource_args[@]+"${resource_args[@]}"}" \
    "${env_args[@]+"${env_args[@]}"}" \
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
if [ "$mode" = "best-effort" ]; then
  echo "Best-effort mode: sandbox failure did not fail command."
  exit 0
fi
exit 1
