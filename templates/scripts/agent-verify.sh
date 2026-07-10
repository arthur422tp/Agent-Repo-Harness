#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-verify.sh [--strict|--best-effort]

Modes:
  --strict       Default. Missing tooling for detected checks is treated as a failure.
  --best-effort  Missing tooling becomes a warning, but failed checks still fail.
EOF
}

print_repair_hint() {
  echo "Repair: inspect this result file in .agent/runs/<timestamp>/ and follow docs/agent/repair-failed-run.md"
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

echo "== Agent Repo Harness Verification =="
echo "Mode: $mode"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_python() {
  if have_cmd python3; then
    printf '%s\n' "python3"
    return 0
  fi
  if have_cmd python; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

repo_defined_checks_found=0

failures=0
warnings=0
checks_run=0

mark_warning() {
  local reason="$1"

  echo "WARN: $reason"
  warnings=$((warnings + 1))
}

handle_missing_tool() {
  local label="$1"

  echo
  echo "RUN: $label"
  if [ "$mode" = "strict" ]; then
    echo "FAIL: $label"
    echo "Reason: required tool or dependency is unavailable."
    failures=$((failures + 1))
  else
    echo "WARN: $label"
    echo "Reason: required tool or dependency is unavailable."
    warnings=$((warnings + 1))
  fi
}

run_check() {
  local label="$1"
  shift

  echo
  echo "RUN: $label"
  checks_run=$((checks_run + 1))
  if "$@"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

resolve_verification_path() {
  local task_file=".agent/task.yml"
  local script_dir
  local reader
  local python_bin
  local profile=""

  script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  reader="$script_dir/lib/read-yaml.py"
  if ! python_bin="$(find_python)"; then
    echo "ERROR: python is required to read verification configuration" >&2
    return 1
  fi
  if [ -f "$task_file" ]; then
    profile="$("$python_bin" "$reader" "$task_file" \
      task.verification_profile --optional)" || return 1
  fi
  if [ -n "$profile" ]; then
    printf '%s\n' "verification.profiles.$profile.required"
    return 0
  fi
  printf '%s\n' "verification.required"
}

extract_required_verification_entries() {
  local config_file="$1"
  local verification_path="$2"
  local script_dir
  local reader
  local python_bin

  script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  reader="$script_dir/lib/read-yaml.py"

  if [ ! -f "$reader" ]; then
    echo "ERROR: YAML reader not found: $reader" >&2
    return 1
  fi

  if ! python_bin="$(find_python)"; then
    echo "ERROR: python is required to read .agent/harness.yml" >&2
    return 1
  fi

  # JSON lines preserve multiline command values; tab-separated rows do not.
  "$python_bin" "$reader" "$config_file" "$verification_path" \
    --optional --list-fields-jsonl name command
}

run_configured_verification_checks() {
  local config_file="$1"
  local verification_path
  local selected_profile
  local entries
  local entry_json
  local label
  local command_string
  local python_bin

  if ! verification_path="$(resolve_verification_path)"; then
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: could not resolve verification command path"
    failures=$((failures + 1))
    return 0
  fi
  if ! entries="$(extract_required_verification_entries "$config_file" "$verification_path")"; then
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: could not read $verification_path from $config_file"
    failures=$((failures + 1))
    return 0
  fi
  if [ -z "$entries" ] && [ "$verification_path" != "verification.required" ]; then
    selected_profile="${verification_path#verification.profiles.}"
    selected_profile="${selected_profile%.required}"
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: selected verification profile has no commands: $selected_profile"
    failures=$((failures + 1))
    return 0
  fi
  if [ -z "$entries" ]; then
    return 0
  fi

  repo_defined_checks_found=1
  echo
  echo "== Repo-defined verification commands =="
  echo "Config: $config_file"
  echo "Repo-defined verification commands found."
  case "$verification_path" in
    verification.profiles.*.required)
      selected_profile="${verification_path#verification.profiles.}"
      selected_profile="${selected_profile%.required}"
      echo "Selected verification profile: $selected_profile"
      ;;
  esac

  if ! python_bin="$(find_python)"; then
    echo "FAIL: repo-defined verification config"
    echo "Reason: python is required to decode verification commands"
    failures=$((failures + 1))
    return 0
  fi

  while IFS= read -r entry_json; do
    [ -n "${entry_json:-}" ] || continue

    if ! label="$(printf '%s\n' "$entry_json" | "$python_bin" -c 'import json,sys; print(json.load(sys.stdin)["name"])')"; then
      echo "FAIL: repo-defined verification config"
      echo "Reason: could not decode verification command name"
      failures=$((failures + 1))
      continue
    fi
    if ! command_string="$(printf '%s\n' "$entry_json" | "$python_bin" -c 'import json,sys; print(json.load(sys.stdin)["command"])')"; then
      echo "FAIL: repo-defined verification config"
      echo "Reason: could not decode verification command"
      failures=$((failures + 1))
      continue
    fi

    [ -n "${label:-}" ] || continue
    [ -n "${command_string:-}" ] || continue

    echo "COMMAND: $command_string"
    # Commands come from repo-owned config and may contain shell syntax.
    # Running them through bash -lc keeps parsing centralized without adding
    # external YAML or command parsing dependencies.
    run_check "$label" bash -lc "$command_string"
  done <<EOF
$entries
EOF
}

run_shell_syntax_checks() {
  local file
  local found=0
  local status=0

  while IFS= read -r -d '' file; do
    found=1
    if ! bash -n "$file"; then
      status=1
    fi
  done < <(find scripts -maxdepth 1 -type f -name "*.sh" -print0)

  [ "$found" -eq 1 ] && [ "$status" -eq 0 ]
}

run_gofmt_check() {
  local output

  output="$(gofmt -l .)"
  if [ -n "$output" ]; then
    printf '%s\n' "$output"
    return 1
  fi

  return 0
}

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

echo
echo "== Git diff stat =="
if [ "$in_git_repo" -eq 1 ]; then
  git diff --stat
else
  mark_warning "not a git repository"
fi

echo
echo "== Detect and run common checks =="

if [ -f .agent/harness.yml ]; then
  run_configured_verification_checks .agent/harness.yml
fi

if [ -d scripts ] && find scripts -maxdepth 1 -type f -name "*.sh" | grep -q .; then
  run_check "bash -n scripts/*.sh" run_shell_syntax_checks
fi

if [ "$repo_defined_checks_found" -eq 1 ]; then
  echo
  echo "SKIP: language heuristics because repo-defined verification commands are authoritative"
else
  if [ -f package.json ]; then
    echo "Detected Node project"
    if have_cmd npm; then
      run_check "npm run lint --if-present" npm run lint --if-present
      run_check "npm run build --if-present" npm run build --if-present
      run_check "npm test --if-present" npm test --if-present
    else
      handle_missing_tool "npm project checks"
    fi
  fi

  if [ -f go.mod ]; then
    echo "Detected Go project"
    if have_cmd go; then
      run_check "gofmt -l ." run_gofmt_check
      run_check "go test ./..." go test ./...
    else
      handle_missing_tool "go project checks"
    fi
  fi

  if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
    echo "Detected Python project"
    if have_cmd python3; then
      run_check "python3 -m compileall ." python3 -m compileall .
    elif have_cmd python; then
      run_check "python -m compileall ." python -m compileall .
    else
      handle_missing_tool "python compile check"
    fi

    if have_cmd pytest; then
      run_check "pytest" pytest
    else
      handle_missing_tool "pytest"
    fi

    if have_cmd ruff; then
      run_check "ruff check ." ruff check .
    else
      handle_missing_tool "ruff"
    fi
  fi

  if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
    echo "Detected Docker Compose config"
    if have_cmd docker; then
      run_check "docker compose config" docker compose config
    else
      handle_missing_tool "docker compose config"
    fi
  fi
fi

if [ "$checks_run" -eq 0 ]; then
  mark_warning "no verification checks were detected"
fi

echo
echo "== Verification summary =="
echo "Mode: $mode"
echo "Checks run: $checks_run"
echo "Failures: $failures"
echo "Warnings: $warnings"

if [ "$failures" -gt 0 ]; then
  echo "HARNESS_VERIFY_RESULT=fail"
  echo "HARNESS_CHECKS_RUN=$checks_run"
  echo "HARNESS_FAILURES=$failures"
  echo "HARNESS_WARNINGS=$warnings"
  print_repair_hint
  echo "Verification failed."
  exit 1
fi

if [ "$warnings" -gt 0 ]; then
  echo "HARNESS_VERIFY_RESULT=warn"
  echo "HARNESS_CHECKS_RUN=$checks_run"
  echo "HARNESS_FAILURES=$failures"
  echo "HARNESS_WARNINGS=$warnings"
  echo "Verification completed with warnings."
  exit 0
fi

echo "HARNESS_VERIFY_RESULT=pass"
echo "HARNESS_CHECKS_RUN=$checks_run"
echo "HARNESS_FAILURES=$failures"
echo "HARNESS_WARNINGS=$warnings"
echo "Verification passed."
