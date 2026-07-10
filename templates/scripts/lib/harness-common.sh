#!/usr/bin/env bash
set -euo pipefail

harness_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

harness_find_python() {
  if harness_have_cmd python3; then
    printf '%s\n' python3
    return 0
  fi
  if harness_have_cmd python; then
    printf '%s\n' python
    return 0
  fi
  return 1
}

harness_make_temp_file() {
  local run_dir="$1"
  local stem="$2"
  mktemp "$run_dir/.${stem}.XXXXXX"
}

harness_atomic_replace() {
  local source="$1"
  local destination="$2"
  mv "$source" "$destination"
}
