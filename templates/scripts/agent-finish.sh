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

case "${1:-}" in
  "")
    ;;
  --strict)
    mode="strict"
    ;;
  --best-effort)
    mode="best-effort"
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

echo "== Agent Finish Gate =="
echo "Mode: $mode"

if [ "$mode" = "strict" ]; then
  bash scripts/check-agent-md.sh agent.md
  bash scripts/check-scope.sh --strict
  bash scripts/check-policy.sh --strict
  bash scripts/agent-verify.sh --strict
else
  bash scripts/check-agent-md.sh agent.md
  bash scripts/check-scope.sh --warn
  bash scripts/check-policy.sh --warn
  bash scripts/agent-verify.sh --best-effort
fi

echo "AGENT_FINISH_RESULT=pass"
echo "Agent finish gates passed."
