#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-scope.sh [--strict|--warn] [TASK_FILE]

Modes:
  --strict  Default. Scope violations exit non-zero.
  --warn    Print scope violations but exit 0.
  -h, --help
            Show this help text.
EOF
}

print_repair_hint() {
  echo "Repair: inspect this result file in .agent/runs/<timestamp>/ and follow docs/agent/repair-failed-run.md"
}

mode="strict"
task_file=".agent/task.yml"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict)
      mode="strict"
      ;;
    --warn)
      mode="warn"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ "$task_file" != ".agent/task.yml" ]; then
        echo "ERROR: multiple task files provided"
        usage
        exit 2
      fi
      task_file="$1"
      ;;
  esac
  shift
done

if [ ! -f "$task_file" ]; then
  echo "== Scope Gate =="
  echo "Mode: $mode"
  echo "SKIP: task file not found at $task_file"
  echo "Scope check skipped."
  exit 0
fi

is_harness_runtime_path() {
  case "$1" in
    .agent/runs/*|.agent/audits/*|.agent/command-runs/*|.agent/sandbox-runs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

count_untracked_lines() {
  local total=0
  local file
  local lines

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      continue
    fi

    if [ -f "$file" ]; then
      lines="$(wc -l < "$file" | tr -d '[:space:]')"
      total=$((total + ${lines:-0}))
    fi
  done <<EOF
$changed_files
EOF

  echo "$total"
}

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
reader="$script_dir/lib/read-yaml.py"
python_bin=""

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for scope config reads"
  exit 1
fi

read_task_value() {
  local path="$1"
  local output

  if output="$("$python_bin" "$reader" "$task_file" "$path" --optional 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: could not read $path from $task_file" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_task_list() {
  local path="$1"
  local raw
  local output

  raw="$(read_task_value "$path")"
  case "$raw" in
    ""|null|"{}")
      return 0
      ;;
  esac

  if output="$(printf '%s\n' "$raw" | "$python_bin" -c '
import json
import sys

value = json.load(sys.stdin)
if not isinstance(value, list):
    raise SystemExit("expected list")
for item in value:
    if item is None:
        continue
    print(item)
' 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: $task_file $path must be a list, empty map, null, or missing" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

tracked_changed_files="$(git diff --name-only HEAD 2>/dev/null || true)"
untracked_changed_files="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
included_untracked_files=""
ignored_runtime_files=""

while IFS= read -r file; do
  [ -n "$file" ] || continue
  if is_harness_runtime_path "$file"; then
    ignored_runtime_files="${ignored_runtime_files}${ignored_runtime_files:+
}$file"
  else
    included_untracked_files="${included_untracked_files}${included_untracked_files:+
}$file"
  fi
done <<EOF
$untracked_changed_files
EOF

changed_files="$({
  printf '%s\n' "$tracked_changed_files"
  printf '%s\n' "$included_untracked_files"
} | awk 'NF' | sort -u)"
changed_count=0
violations=0

if [ -n "$changed_files" ]; then
  changed_count="$(printf '%s\n' "$changed_files" | awk 'NF { count++ } END { print count + 0 }')"
fi

echo "== Scope Gate =="
echo "Task file: $task_file"
echo "Mode: $mode"
if [ -n "$ignored_runtime_files" ]; then
  echo "Ignored untracked harness runtime files:"
  printf '%s\n' "$ignored_runtime_files" | sed 's/^/- /'
fi
echo "Changed file count: $changed_count"

if [ -z "$changed_files" ]; then
  echo "No changed files detected."
  echo "Scope check passed."
  exit 0
fi

allowed_patterns="$(read_task_list task.allowed_paths)"
forbidden_patterns="$(read_task_list task.forbidden_paths)"
max_changed_files="$(read_task_value task.max_changed_files)"
max_diff_lines="$(read_task_value task.max_diff_lines)"

case "$max_changed_files" in
  ""|null|~)
    max_changed_files=""
    ;;
esac

case "$max_diff_lines" in
  ""|null|~)
    max_diff_lines=""
    ;;
esac

if [ -n "$allowed_patterns" ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    matched=0
    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      if [[ "$file" == $pattern ]]; then
        matched=1
        break
      fi
    done <<EOF
$allowed_patterns
EOF

    if [ "$matched" -ne 1 ]; then
      if [ "$violations" -eq 0 ]; then
        echo
        echo "Violations:"
      fi
      violations=$((violations + 1))
      echo "- $file is outside allowed_paths"
    fi
  done <<EOF
$changed_files
EOF
fi

if [ -n "$forbidden_patterns" ]; then
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if [[ "$file" == $pattern ]]; then
        if [ "$violations" -eq 0 ]; then
          echo
          echo "Violations:"
        fi
        violations=$((violations + 1))
        echo "- $file matches forbidden_paths pattern $pattern"
      fi
    done <<EOF
$changed_files
EOF
  done <<EOF
$forbidden_patterns
EOF
fi

if [ -n "$max_changed_files" ] && [ "$changed_count" -gt "$max_changed_files" ]; then
  if [ "$violations" -eq 0 ]; then
    echo
    echo "Violations:"
  fi
  violations=$((violations + 1))
  echo "- changed file count $changed_count exceeds max_changed_files $max_changed_files"
fi

tracked_diff_lines="$(
  {
    git diff --numstat HEAD 2>/dev/null || true
  } | awk '{ add += $1; del += $2 } END { print add + del + 0 }'
)"
untracked_diff_lines="$(count_untracked_lines)"
total_diff_lines=$((tracked_diff_lines + untracked_diff_lines))
echo "Approx changed lines: $total_diff_lines"

if [ -n "$max_diff_lines" ] && [ "$total_diff_lines" -gt "$max_diff_lines" ]; then
  if [ "$violations" -eq 0 ]; then
    echo
    echo "Violations:"
  fi
  violations=$((violations + 1))
  echo "- changed line count $total_diff_lines exceeds max_diff_lines $max_diff_lines"
fi

if [ "$violations" -eq 0 ]; then
  echo "Scope check passed."
  exit 0
fi

if [ "$mode" = "warn" ]; then
  echo "Scope check warned."
  exit 0
fi

echo "Scope check failed."
print_repair_hint
exit 1
