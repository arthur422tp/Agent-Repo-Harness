#!/usr/bin/env bash
set -euo pipefail

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

show_file() {
  local file="$1"
  local title="$2"

  echo
  echo "== $title =="
  if [ -f "$file" ]; then
    sed -n '1,160p' "$file"
  else
    echo "MISSING: $file"
  fi
}

echo "== Git status =="
if [ "$in_git_repo" -eq 1 ]; then
  git status --short || true
else
  echo "SKIP: not a git repository"
fi

echo
echo "== Recent commits =="
if [ "$in_git_repo" -eq 1 ]; then
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git log --oneline -5
  else
    echo "SKIP: no commits yet"
  fi
else
  echo "SKIP: not a git repository"
fi

show_file "agent.md" "agent.md"
show_file "handoff.md" "handoff.md"
show_file "docs/agent/known-issues.md" "Known Issues"
show_file "docs/agent/discoveries.md" "Discoveries"
show_file ".agent/policy.yml" "Policy"
