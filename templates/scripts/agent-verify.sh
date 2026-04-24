#!/usr/bin/env bash
set -euo pipefail

mode="${1:-best-effort}"

case "$mode" in
  strict|best-effort)
    ;;
  *)
    echo "ERROR: unsupported mode: $mode"
    echo "Usage: $0 [strict|best-effort]"
    exit 2
    ;;
esac

echo "== Agent Repo Harness Verification =="
echo "Mode: $mode"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

failures=0
skips=0

run_check() {
  local label="$1"
  local command="$2"

  echo
  echo "RUN: $label"
  if bash -lc "$command"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    failures=$((failures + 1))
  fi
}

skip_check() {
  local reason="$1"

  echo "SKIP: $reason"
  skips=$((skips + 1))
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
  echo "SKIP: not a git repository"
fi

echo
echo "== Detect and run common checks =="

if [ -f package.json ]; then
  echo "Detected Node project"
  if have_cmd npm; then
    run_check "npm run lint --if-present" "npm run lint --if-present"
    run_check "npm run build --if-present" "npm run build --if-present"
    run_check "npm test --if-present" "npm test --if-present"
  else
    skip_check "npm not installed"
  fi
fi

if [ -f go.mod ]; then
  echo "Detected Go project"
  if have_cmd go; then
    run_check "gofmt -l ." "gofmt -l ."
    run_check "go test ./..." "go test ./..."
  else
    skip_check "go not installed"
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  echo "Detected Python project"
  if have_cmd python3; then
    run_check "python3 -m compileall ." "python3 -m compileall ."
  elif have_cmd python; then
    run_check "python -m compileall ." "python -m compileall ."
  else
    skip_check "python not installed"
  fi

  if have_cmd pytest; then
    run_check "pytest" "pytest"
  else
    skip_check "pytest not installed"
  fi

  if have_cmd ruff; then
    run_check "ruff check ." "ruff check ."
  else
    skip_check "ruff not installed"
  fi
fi

if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  echo "Detected Docker Compose config"
  if have_cmd docker; then
    run_check "docker compose config" "docker compose config >/dev/null"
  else
    skip_check "docker not installed"
  fi
fi

echo
echo "== Verification summary =="
echo "Failures: $failures"
echo "Skips: $skips"

if [ "$mode" = "strict" ] && [ "$skips" -gt 0 ]; then
  echo "STRICT MODE: skipped checks are treated as failures."
  exit 1
fi

if [ "$failures" -gt 0 ]; then
  echo "Verification failed."
  exit 1
fi

echo "Verification completed."
