#!/usr/bin/env bash
set -euo pipefail

echo "== Agent Repo Harness Preflight =="

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

echo
echo "== Git status =="
if [ "$in_git_repo" -eq 1 ]; then
  git status --short || true
else
  echo "SKIP: not a git repository"
fi

echo
echo "== Project markers =="
find . -maxdepth 3 \( \
  -name "package.json" -o \
  -name "go.mod" -o \
  -name "pyproject.toml" -o \
  -name "requirements.txt" -o \
  -name "Cargo.toml" -o \
  -name "docker-compose.yml" -o \
  -name "compose.yml" -o \
  -name "Dockerfile" \
\) -print 2>/dev/null || true

echo
echo "== Harness files =="
for f in agent.md handoff.md .agent/harness.yml .agent/policy.yml docs/agent/known-issues.md docs/agent/discoveries.md; do
  if [ -f "$f" ]; then
    echo "FOUND $f"
  else
    echo "MISSING $f"
  fi
done

echo
echo "== Scripts =="
find scripts -maxdepth 1 -type f -name "*.sh" -print 2>/dev/null || true
