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

validate_verification_profiles() {
  local profiles_json

  profiles_json="$("$python_bin" "$yaml_reader" "$harness_file" \
    verification.profiles --optional 2>&1)" || {
      echo "FAIL: $harness_file could not read verification.profiles"
      failures=$((failures + 1))
      return 0
    }
  if [ -z "$profiles_json" ]; then
    return 0
  fi
  if printf '%s\n' "$profiles_json" | "$python_bin" -c '
import json
import re
import sys
profiles = json.load(sys.stdin)
if not isinstance(profiles, dict):
    raise SystemExit("verification.profiles must be a map")
for name, profile in profiles.items():
    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", name) is None:
        raise SystemExit(f"invalid verification profile name: {name}")
    if not isinstance(profile, dict):
        raise SystemExit(f"verification profile {name} must be a map")
    required = profile.get("required")
    if not isinstance(required, list) or not required:
        raise SystemExit(f"verification profile {name}.required must be a non-empty list")
    for entry in required:
        if not isinstance(entry, dict):
            raise SystemExit(f"verification profile {name} entry must be a map")
        if not isinstance(entry.get("name"), str) or not entry["name"]:
            raise SystemExit(f"verification profile {name} entry name must be non-empty")
        if not isinstance(entry.get("command"), str) or not entry["command"]:
            raise SystemExit(f"verification profile {name} entry command must be non-empty")
'; then
    echo "OK: $harness_file verification profiles are valid"
  else
    echo "FAIL: $harness_file verification profiles are invalid"
    failures=$((failures + 1))
  fi
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
  validate_verification_profiles
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
