#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-config.sh [HARNESS_FILE] [POLICY_FILE]

Defaults:
  HARNESS_FILE  .agent/harness.yml
  POLICY_FILE   .agent/policy.yml

Performs dependency-light structural checks using scripts/lib/read-yaml.py.
EOF
}

harness_file="${1:-.agent/harness.yml}"
policy_file="${2:-.agent/policy.yml}"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

failures=0

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_python() {
  if have_cmd python3; then
    printf '%s\n' "python3"
    return 0
  fi
  if have_cmd python; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
yaml_reader="$script_dir/lib/read-yaml.py"
python_bin=""

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "FAIL: missing $file"
    failures=$((failures + 1))
    return 1
  fi
  echo "FOUND: $file"
}

require_key() {
  local file="$1"
  local key="$2"
  if ! "$python_bin" "$yaml_reader" "$file" "$key" >/dev/null 2>&1; then
    echo "FAIL: $file missing key: $key"
    failures=$((failures + 1))
    return 1
  fi
  echo "OK: $file contains $key"
}

echo "== Harness Config Validation =="

if [ ! -f "$yaml_reader" ]; then
  echo "FAIL: missing YAML reader: $yaml_reader"
  failures=$((failures + 1))
elif ! python_bin="$(find_python)"; then
  echo "FAIL: python is required for config validation"
  failures=$((failures + 1))
fi

require_file "$harness_file" || true
require_file "$policy_file" || true

if [ -f "$harness_file" ] && [ -n "$python_bin" ] && [ -f "$yaml_reader" ]; then
  require_key "$harness_file" "name"
  require_key "$harness_file" "version"
  require_key "$harness_file" "paths"
  require_key "$harness_file" "scripts"
  require_key "$harness_file" "verification"
fi

if [ -f "$policy_file" ] && [ -n "$python_bin" ] && [ -f "$yaml_reader" ]; then
  require_key "$policy_file" "version"
  require_key "$policy_file" "default_mode"
  require_key "$policy_file" "risk_files"
  require_key "$policy_file" "rules"
fi

if [ "$failures" -gt 0 ]; then
  echo "CONFIG_VALIDATION_RESULT=fail"
  exit 1
fi

echo "CONFIG_VALIDATION_RESULT=pass"
