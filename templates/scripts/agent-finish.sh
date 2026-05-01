#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-finish.sh [--strict|--best-effort]

Modes:
  --strict       Default. Run all completion gates in blocking mode.
  --best-effort  Run scope and policy gates in warning mode, and verification
                 in best-effort mode.
  -h, --help     Show this help text.
EOF
}

mode="strict"
mode_arg="--strict"

case "${1:-}" in
  "")
    ;;
  --strict)
    mode="strict"
    mode_arg="--strict"
    ;;
  --best-effort)
    mode="best-effort"
    mode_arg="--best-effort"
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

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
run_dir=".agent/runs/$timestamp"
summary_file="$run_dir/finish-summary.md"
failures=0

mkdir -p "$run_dir"

write_summary_header() {
  {
    echo "# Agent Finish Summary"
    echo
    echo "- Timestamp: $timestamp"
    echo "- Mode: $mode"
    echo "- Command: scripts/agent-finish.sh $mode_arg"
    echo
    echo "## Gate Results"
    echo
  } >"$summary_file"
}

run_gate() {
  local label="$1"
  shift
  local log_file="$run_dir/$label.log"

  echo
  echo "RUN: $label"
  if "$@" >"$log_file" 2>&1; then
    cat "$log_file"
    {
      echo "- PASS: $label"
      echo "  - Log: $log_file"
    } >>"$summary_file"
  else
    cat "$log_file"
    {
      echo "- FAIL: $label"
      echo "  - Log: $log_file"
    } >>"$summary_file"
    failures=$((failures + 1))
  fi
}

echo "== Agent Finish Gate =="
echo "Mode: $mode"
echo "Run directory: $run_dir"

write_summary_header

if [ "$mode" = "strict" ]; then
  run_gate "check-agent-md" bash scripts/check-agent-md.sh agent.md
  run_gate "check-scope" bash scripts/check-scope.sh --strict
  run_gate "check-policy" bash scripts/check-policy.sh --strict
  run_gate "agent-verify" bash scripts/agent-verify.sh --strict
else
  run_gate "check-agent-md" bash scripts/check-agent-md.sh agent.md
  run_gate "check-scope" bash scripts/check-scope.sh --warn
  run_gate "check-policy" bash scripts/check-policy.sh --warn
  run_gate "agent-verify" bash scripts/agent-verify.sh --best-effort
fi

{
  echo
  echo "## Notes"
  echo
  echo "- TODO: Add optional machine-readable JSON output in a later pass."
  echo "- JSON format should include timestamp, mode, command, gate names, exit codes, log paths, and final result."
} >>"$summary_file"

if [ "$failures" -gt 0 ]; then
  {
    echo
    echo "## Result"
    echo
    echo "AGENT_FINISH_RESULT=fail"
  } >>"$summary_file"
  echo "AGENT_FINISH_RESULT=fail"
  echo "Agent finish gates failed."
  echo "Summary: $summary_file"
  exit 1
fi

{
  echo
  echo "## Result"
  echo
  echo "AGENT_FINISH_RESULT=pass"
} >>"$summary_file"

echo "AGENT_FINISH_RESULT=pass"
echo "Agent finish gates passed."
echo "Summary: $summary_file"
