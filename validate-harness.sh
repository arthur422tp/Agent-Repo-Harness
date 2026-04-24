#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
target_root="/tmp/test-agent-harness-target"

echo "== Validate Agent-Repo-Harness =="

cd "$repo_root"

echo
echo "== Shell syntax =="
bash -n install-agent-harness.sh
for f in templates/scripts/*.sh; do
  bash -n "$f"
done

echo
echo "== Fresh install target =="
rm -rf "$target_root"
mkdir -p "$target_root"

bash install-agent-harness.sh "$target_root"

echo
echo "== Installed target checks =="
(
  cd "$target_root"
  bash scripts/agent-preflight.sh
  bash scripts/check-agent-md.sh agent.md
  bash scripts/agent-verify.sh
  bash scripts/check-policy.sh .agent/policy.yml
  bash scripts/collect-context.sh >/dev/null
)

echo
echo "Validation completed."
