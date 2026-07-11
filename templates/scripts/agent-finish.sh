#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
common_lib="$script_dir/lib/harness-common.sh"
if [ ! -f "$common_lib" ]; then
  echo "ERROR: required internal library not found: $common_lib" >&2
  exit 1
fi
source "$script_dir/lib/harness-common.sh"
summary_lib="$script_dir/lib/finish-summary.sh"
if [ ! -f "$summary_lib" ]; then
  echo "ERROR: required internal library not found: $summary_lib" >&2
  exit 1
fi
source "$script_dir/lib/finish-summary.sh"
registry_lib="$script_dir/lib/gate-registry.sh"
if [ ! -f "$registry_lib" ]; then
  echo "ERROR: required internal library not found: $registry_lib" >&2
  exit 1
fi
source "$script_dir/lib/gate-registry.sh"
runner_lib="$script_dir/lib/finish-runner.sh"
if [ ! -f "$runner_lib" ]; then
  echo "ERROR: required internal library not found: $runner_lib" >&2
  exit 1
fi
source "$script_dir/lib/finish-runner.sh"

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

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
run_dir=".agent/runs/$timestamp"
summary_file="$run_dir/finish-summary.md"
summary_json_file="$run_dir/finish-summary.json"
start_epoch="$(date -u +%s)"
elapsed_seconds=0
resource_status="0"
resource_result_file="$run_dir/resource-envelope-result.txt"
episode_summary_json_file="$run_dir/episode-summary.json"
changed_files_file="$run_dir/changed-files.txt"
diff_stat_file="$run_dir/git-diff-stat.txt"
failures=0

mkdir -p "$run_dir"

python_bin=""
if ! python_bin="$(harness_find_python)"; then
  echo "ERROR: python is required for finish evidence writes"
  exit 1
fi

write_git_evidence() {
  local changed_files
  local diff_stat

  {
    echo "# Changed files"
    echo
    if ! command -v git >/dev/null 2>&1; then
      echo "git is unavailable; changed files could not be collected."
    elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a git repository; changed files could not be collected."
    else
      changed_files="$(
        {
          git diff --name-only HEAD 2>/dev/null || true
          git ls-files --others --exclude-standard 2>/dev/null || true
        } | awk '
          NF &&
          $0 !~ /^\.agent\/runs\// &&
          $0 !~ /^agent-finish-.*\.log$/
        ' | sort -u
      )"
      if [ -n "$changed_files" ]; then
        printf '%s\n' "$changed_files"
      else
        echo "No changed files detected."
      fi
    fi
  } >"$changed_files_file"

  {
    echo "# Git diff stat"
    echo
    if ! command -v git >/dev/null 2>&1; then
      echo "git is unavailable; diff stat could not be collected."
    elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a git repository; diff stat could not be collected."
    else
      diff_stat="$(git diff --stat HEAD 2>/dev/null || git diff --stat 2>/dev/null || true)"
      if [ -n "$diff_stat" ]; then
        printf '%s\n' "$diff_stat"
      else
        echo "No tracked diff detected."
      fi
    fi
  } >"$diff_stat_file"
}

read_harness_value() {
  local path="$1"
  local reader="scripts/lib/read-yaml.py"

  if [ ! -f ".agent/harness.yml" ]; then
    return 0
  fi
  if [ -z "${python_bin:-}" ]; then
    return 0
  fi
  if [ ! -f "$reader" ]; then
    return 0
  fi

  "$python_bin" "$reader" ".agent/harness.yml" "$path" --optional 2>/dev/null || true
}

count_changed_files() {
  if [ ! -f "$changed_files_file" ]; then
    printf '%s\n' 0
    return 0
  fi

  awk '
    NF &&
    $0 !~ /^#/ &&
    $0 != "No changed files detected." &&
    $0 !~ /^git is unavailable/ &&
    $0 !~ /^Not inside a git repository/ {
      count++
    }
    END { print count + 0 }
  ' "$changed_files_file"
}

check_resource_envelope() {
  local max_finish_seconds
  local max_changed_files
  local changed_count
  local resource_failures=0

  max_finish_seconds="$(read_harness_value "runtime.resource_limits.max_finish_seconds")"
  max_changed_files="$(read_harness_value "runtime.resource_limits.max_changed_files")"
  max_finish_seconds="${max_finish_seconds:-0}"
  max_changed_files="${max_changed_files:-0}"

  {
    echo "Check: resource-envelope"
    echo "Command: scripts/agent-finish.sh $mode_arg"
    echo
    if [ "$max_finish_seconds" = "0" ] && [ "$max_changed_files" = "0" ]; then
      echo "Resource envelope is disabled."
    else
      changed_count="$(count_changed_files)"
      echo "Configured limits:"
      echo "- max_finish_seconds: $max_finish_seconds"
      echo "- max_changed_files: $max_changed_files"
      echo "- elapsed_seconds: $elapsed_seconds"
      echo "- changed_files: $changed_count"

      if [ "$max_finish_seconds" != "0" ] && [ "$elapsed_seconds" -gt "$max_finish_seconds" ]; then
        echo "ERROR: elapsed seconds $elapsed_seconds exceeds limit $max_finish_seconds"
        resource_failures=$((resource_failures + 1))
      fi
      if [ "$max_changed_files" != "0" ] && [ "$changed_count" -gt "$max_changed_files" ]; then
        echo "ERROR: changed files $changed_count exceeds limit $max_changed_files"
        resource_failures=$((resource_failures + 1))
      fi
    fi
  } >"$resource_result_file"

  if [ "$resource_failures" -gt 0 ]; then
    resource_status=1
    failures=$((failures + 1))
    echo "Resource envelope failed."
    cat "$resource_result_file"
    return 1
  fi

  resource_status=0
  cat "$resource_result_file"
  return 0
}

echo "== Agent Finish Gate =="
echo "Mode: $mode"
echo "Run directory: $run_dir"

finish_init_gate_registry
finish_validate_gate_registry
finish_run_registered_gates "$mode" "$run_dir" || true

write_git_evidence
elapsed_seconds=$(($(date -u +%s) - start_epoch))
check_resource_envelope || true
finish_set_gate_status resource-envelope "$resource_status"

if [ "$failures" -gt 0 ]; then
  finish_write_markdown_summary "fail"
  finish_write_json_summary "fail"
  finish_write_episode_summary "fail"
  echo "AGENT_FINISH_RESULT=fail"
  echo "Agent finish gates failed."
  echo "Run directory: $run_dir"
  echo "Summary: $summary_file"
  exit 1
fi

finish_write_markdown_summary "pass"
finish_write_json_summary "pass"
finish_write_episode_summary "pass"

echo "AGENT_FINISH_RESULT=pass"
echo "Agent finish gates passed."
echo "Run directory: $run_dir"
echo "Summary: $summary_file"
