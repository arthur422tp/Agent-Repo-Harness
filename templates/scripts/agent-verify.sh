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

extract_required_verification_entries() {
  local config_file="$1"

  awk '
    /^verification:/ { in_verification=1; next }
    in_verification && /^[^[:space:]]/ { in_verification=0 }
    in_verification && /^[[:space:]]*required:[[:space:]]*$/ { in_required=1; next }
    in_required && substr($0, 1, 4) == "    " && $0 ~ /-[[:space:]]+name:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      name=line
      next
    }
    in_required && substr($0, 1, 6) == "      " && $0 ~ /command:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*command:[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      printf "%s\t%s\n", name, line
      next
    }
    in_required && /^[[:space:]]{2}[A-Za-z0-9_]+:/ { in_required=0 }
  ' "$config_file"
}

run_configured_verification_checks() {
  local config_file="$1"
  local entries
  local label
  local command_string

  entries="$(extract_required_verification_entries "$config_file")"
  if [ -z "$entries" ]; then
    return 0
  fi

  repo_defined_checks_found=1
  echo
  echo "== Repo-defined verification commands =="
  echo "Config: $config_file"
  echo "Repo-defined verification commands found."

  while IFS=$'\t' read -r label command_string; do
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
