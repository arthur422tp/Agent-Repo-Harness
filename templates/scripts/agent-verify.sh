#!/usr/bin/env bash
set -euo pipefail

echo "== Agent Repo Harness Verification =="

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

echo
echo "== Git diff stat =="
if [ "$in_git_repo" -eq 1 ]; then
  git diff --stat || true
else
  echo "SKIP: not a git repository"
fi

echo
echo "== Detect and run common checks =="

if [ -f package.json ]; then
  echo "Detected Node project"
  if have_cmd npm; then
    npm run lint --if-present || true
    npm run build --if-present || true
    npm test --if-present || true
  else
    echo "SKIP: npm not installed"
  fi
fi

if [ -f go.mod ]; then
  echo "Detected Go project"
  if have_cmd go; then
    gofmt -l . || true
    go test ./... || true
  else
    echo "SKIP: go not installed"
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  echo "Detected Python project"
  if have_cmd python3; then
    python3 -m compileall . || true
  elif have_cmd python; then
    python -m compileall . || true
  else
    echo "SKIP: python not installed"
  fi

  if have_cmd pytest; then
    pytest || true
  else
    echo "SKIP: pytest not installed"
  fi

  if have_cmd ruff; then
    ruff check . || true
  else
    echo "SKIP: ruff not installed"
  fi
fi

if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  echo "Detected Docker Compose config"
  if have_cmd docker; then
    docker compose config >/dev/null || true
  else
    echo "SKIP: docker not installed"
  fi
fi

echo
echo "Verification completed."
