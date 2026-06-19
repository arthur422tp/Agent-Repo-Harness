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
  local mkdir_status
  local suffix=0

  mkdir -p "$(dirname "$base_run_dir")"
  while true; do
    if mkdir "$run_dir"; then
      return 0
    else
      mkdir_status=$?
    fi

    if [ ! -e "$run_dir" ]; then
      echo "ERROR: could not create command run directory: $run_dir" >&2
      return "$mkdir_status"
    fi

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
  if ! write_summary "pass" "$command_status"; then
    set +e
    rm -f "$summary_json_file"
    echo "ERROR: could not write command summary: $summary_json_file" >&2
    echo "COMMAND_RUN_RESULT=fail"
    echo "Command run directory: $run_dir"
    exit 1
  fi
  echo "COMMAND_RUN_RESULT=pass"
  echo "Command run directory: $run_dir"
  exit 0
fi

if ! write_summary "fail" "$command_status"; then
  set +e
  rm -f "$summary_json_file"
  echo "ERROR: could not write command summary: $summary_json_file" >&2
  echo "COMMAND_RUN_RESULT=fail"
  echo "Command run directory: $run_dir"
  exit "$command_status"
fi
echo "COMMAND_RUN_RESULT=fail"
echo "Command run directory: $run_dir"
exit "$command_status"
