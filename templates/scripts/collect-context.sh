#!/usr/bin/env bash
set -euo pipefail

mode="compact"
if [ "${1:-}" = "--full" ]; then
  mode="full"
elif [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: collect-context.sh [--full]"
  echo "Default compact mode prints startup-critical context only."
  exit 0
elif [ "${1:-}" != "" ]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: collect-context.sh [--full]" >&2
  exit 2
fi

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

line_limit=80
if [ "$mode" = "full" ]; then
  line_limit=200
fi

show_file() {
  local file="$1"
  local title="$2"
  local required="${3:-optional}"

  echo
  echo "== $title =="
  if [ -f "$file" ]; then
    sed -n "1,${line_limit}p" "$file"
  elif [ "$required" = "required" ]; then
    echo "MISSING: $file"
  else
    echo "SKIP: $file not found"
  fi
}

echo "== Context Loading Policy =="
echo "Mode: $mode"
echo "Start compact. Expand only to files directly relevant to the current task."
echo "Use --full when debugging stale repo memory, policy drift, or handoff gaps."

echo
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

show_file "agent.md" "agent.md" required
show_file "handoff.md" "handoff.md" required
show_file ".agent/task.yml" "Task Scope" required
show_file ".agent/policy.yml" "Policy" required

if [ "$mode" = "full" ]; then
  show_file "docs/agent/known-issues.md" "Known Issues"
  show_file "docs/agent/discoveries.md" "Discoveries"
fi
