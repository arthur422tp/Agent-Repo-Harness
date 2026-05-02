#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-subagent-run.sh RUN_DIR

Validates optional subagent run evidence:
  RUN_DIR/packet.yml
  RUN_DIR/result.md
  RUN_DIR/status.txt
EOF
}

run_dir="${1:-}"
failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

echo "== Subagent Run Validation =="

if [ -z "$run_dir" ]; then
  usage
  fail "missing RUN_DIR argument"
  echo "SUBAGENT_RUN_RESULT=fail"
  exit 1
fi

echo "Run directory: $run_dir"

if [ ! -d "$run_dir" ]; then
  fail "run directory does not exist: $run_dir"
else
  for required_file in packet.yml result.md status.txt; do
    if [ -f "$run_dir/$required_file" ]; then
      echo "OK: $required_file"
    else
      fail "missing $run_dir/$required_file"
    fi
  done

  if [ -f "$run_dir/status.txt" ]; then
    status_line_count="$(awk 'END { print NR }' "$run_dir/status.txt")"
    status="$(sed -n '1p' "$run_dir/status.txt")"
    if [ "$status_line_count" -ne 1 ]; then
      fail "status.txt must contain exactly one line"
    else
      case "$status" in
        DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)
          echo "OK: status.txt"
          ;;
        *)
          fail "status.txt must contain exactly one of: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED"
          ;;
      esac
    fi
  fi

  packet_validator="scripts/validate-subagent-packet.sh"
  if [ -f "$run_dir/packet.yml" ] && \
    [ -f "$packet_validator" ] && \
    { [ -x "$packet_validator" ] || [ -r "$packet_validator" ]; }
  then
    if bash "$packet_validator" "$run_dir/packet.yml"; then
      echo "OK: packet.yml"
    else
      fail "packet.yml failed $packet_validator"
    fi
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "SUBAGENT_RUN_RESULT=fail"
  exit 1
fi

echo "SUBAGENT_RUN_RESULT=pass"
