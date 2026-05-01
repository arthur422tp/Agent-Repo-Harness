#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-config.sh [HARNESS_FILE] [POLICY_FILE]

Defaults:
  HARNESS_FILE  .agent/harness.yml
  POLICY_FILE   .agent/policy.yml

Performs dependency-light structural checks. If ruby is available, also checks
YAML syntax.
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
  if ! grep -Eq "^[[:space:]]*$key:" "$file"; then
    echo "FAIL: $file missing key: $key"
    failures=$((failures + 1))
    return 1
  fi
  echo "OK: $file contains $key"
}

check_yaml() {
  if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }' "$@" >/dev/null
    echo "OK: YAML syntax"
  else
    echo "WARN: ruby unavailable; skipped YAML syntax check"
  fi
}

echo "== Harness Config Validation =="

require_file "$harness_file" || true
require_file "$policy_file" || true

if [ -f "$harness_file" ]; then
  require_key "$harness_file" "name"
  require_key "$harness_file" "version"
  require_key "$harness_file" "paths"
  require_key "$harness_file" "scripts"
  require_key "$harness_file" "verification"
fi

if [ -f "$policy_file" ]; then
  require_key "$policy_file" "version"
  require_key "$policy_file" "default_mode"
  require_key "$policy_file" "risk_files"
  require_key "$policy_file" "rules"
fi

if [ -f "$harness_file" ] && [ -f "$policy_file" ]; then
  check_yaml "$harness_file" "$policy_file"
fi

if [ "$failures" -gt 0 ]; then
  echo "CONFIG_VALIDATION_RESULT=fail"
  exit 1
fi

echo "CONFIG_VALIDATION_RESULT=pass"
