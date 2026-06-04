#!/usr/bin/env bash
set -euo pipefail

echo "== Agent Repo Harness Preflight =="

failures=0

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

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
echo "== Dependencies =="
if have_cmd python3; then
  echo "OK: python ($(python3 --version 2>&1))"
elif have_cmd python; then
  echo "OK: python ($(python --version 2>&1))"
else
  echo "MISSING: python is required for harness YAML validation"
  failures=$((failures + 1))
fi

echo
echo "== Harness files =="
for f in \
  AGENTS.md \
  CLAUDE.md \
  agent.md \
  handoff.md \
  .agent/harness.yml \
  .agent/policy.yml \
  .agent/task.yml \
  docs/agent/known-issues.md \
  docs/agent/discoveries.md
do
  if [ -f "$f" ]; then
    echo "FOUND $f"
  else
    echo "MISSING $f"
  fi
done

echo
echo "== Scripts =="
find scripts -maxdepth 1 -type f -name "*.sh" -print 2>/dev/null || true

echo
echo "== Audit command =="
if [ -f scripts/agent-audit.sh ]; then
  echo "FOUND scripts/agent-audit.sh"
else
  echo "SKIP: scripts/agent-audit.sh not found"
fi

echo
echo "== Optional evidence gates =="
if [ -f scripts/check-architecture-evidence.sh ]; then
  if ! bash scripts/check-architecture-evidence.sh; then
    echo "WARN: architecture evidence is incomplete; scripts/agent-finish.sh will enforce it when required."
  fi
else
  echo "SKIP: scripts/check-architecture-evidence.sh not found"
fi

echo
echo "== Episode metadata =="
if [ -f scripts/validate-episode.sh ]; then
  if ! bash scripts/validate-episode.sh; then
    echo "WARN: episode metadata is invalid; scripts/agent-finish.sh will still write finish evidence."
  fi
else
  echo "SKIP: scripts/validate-episode.sh not found"
fi

if [ "$failures" -gt 0 ]; then
  echo "PREFLIGHT_RESULT=fail"
  exit 1
fi

echo "PREFLIGHT_RESULT=pass"
