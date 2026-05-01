#!/usr/bin/env bash
set -euo pipefail

echo "== Example Preflight =="
for f in AGENTS.md CLAUDE.md agent.md handoff.md .agent/policy.yml .agent/task.yml; do
  if [ -f "$f" ]; then
    echo "FOUND $f"
  else
    echo "MISSING $f"
  fi
done
