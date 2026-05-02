#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-subagent-packet.sh [PACKET_FILE]

Default:
  PACKET_FILE  .agent/subagent-packet.yml

Performs lightweight structural checks for controller-agent to subagent
handoff packets. This gate is intentionally not part of agent-finish.sh yet.
EOF
}

packet_file=".agent/subagent-packet.yml"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    packet_file="$1"
    ;;
esac

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

trim_value() {
  sed \
    -e 's/[[:space:]]*#.*$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e 's/^"//' \
    -e 's/"$//'
}

extract_scalar() {
  local key="$1"

  awk -v key="$key" '
    $0 ~ ("^" key ":[[:space:]]*") {
      line=$0
      sub("^[^:]+:[[:space:]]*", "", line)
      print line
      exit
    }
  ' "$packet_file" | trim_value
}

extract_nonempty_list_entries() {
  local section="$1"

  awk -v section="$section" '
    /^[^[:space:]][^:]*:/ {
      current=$0
      sub(/:.*/, "", current)
      in_section=(current == section)
      next
    }
    in_section && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      print line
    }
  ' "$packet_file" | trim_value | sed '/^$/d'
}

extract_status_enum_entries() {
  awk '
    /^expected_output_contract:/ {
      in_contract=1
      in_status=0
      next
    }
    /^[^[:space:]][^:]*:/ {
      if (in_contract) {
        exit
      }
    }
    in_contract && /^[[:space:]]+status_enum:[[:space:]]*$/ {
      in_status=1
      next
    }
    in_status && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      print line
    }
    in_status && /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/ {
      exit
    }
  ' "$packet_file" | trim_value | sed '/^$/d'
}

require_scalar() {
  local key="$1"
  local value

  value="$(extract_scalar "$key")"
  if [ -z "$value" ]; then
    fail "$key must be non-empty"
  else
    echo "OK: $key"
  fi
}

require_role() {
  local role

  role="$(extract_scalar "role")"
  case "$role" in
    implementer|spec_reviewer|quality_reviewer|verifier|researcher)
      echo "OK: role"
      ;;
    "")
      fail "role must be non-empty"
      ;;
    *)
      fail "role must be one of: implementer, spec_reviewer, quality_reviewer, verifier, researcher"
      ;;
  esac
}

require_nonempty_list() {
  local section="$1"

  if [ -z "$(extract_nonempty_list_entries "$section")" ]; then
    fail "$section must include at least one non-empty entry"
  else
    echo "OK: $section"
  fi
}

require_status_enum_value() {
  local required_status="$1"

  if extract_status_enum_entries | grep -Fxq "$required_status"; then
    echo "OK: expected_output_contract.status_enum includes $required_status"
  else
    fail "expected_output_contract.status_enum must include $required_status"
  fi
}

echo "== Subagent Packet Validation =="
echo "Packet file: $packet_file"

if [ ! -f "$packet_file" ]; then
  fail "missing $packet_file"
else
  require_scalar "task_id"
  require_role
  require_scalar "task_text"
  require_nonempty_list "allowed_paths"
  require_nonempty_list "verification_required"
  require_status_enum_value "DONE"
  require_status_enum_value "DONE_WITH_CONCERNS"
  require_status_enum_value "NEEDS_CONTEXT"
  require_status_enum_value "BLOCKED"
fi

if [ "$failures" -gt 0 ]; then
  echo "SUBAGENT_PACKET_RESULT=fail"
  exit 1
fi

echo "SUBAGENT_PACKET_RESULT=pass"
