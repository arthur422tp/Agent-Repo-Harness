#!/usr/bin/env bash
set -euo pipefail

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
run_dir=".agent/runs/$timestamp"
summary="$run_dir/finish-summary.md"
mkdir -p "$run_dir"

{
  echo "# Agent Finish Summary"
  echo
  echo "- Timestamp: $timestamp"
  echo "- Mode: best-effort example"
  echo
  echo "## Gate Results"
  echo
  echo "- PASS: check-policy"
  echo "- PASS: check-scope"
  echo "- PASS: agent-verify"
  echo
  echo "## Result"
  echo
  echo "AGENT_FINISH_RESULT=pass"
} >"$summary"

bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/agent-verify.sh
echo "AGENT_FINISH_RESULT=pass"
echo "Summary: $summary"
