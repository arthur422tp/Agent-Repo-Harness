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

list_changed_files() {
  {
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | awk 'NF' | sort -u
}

extract_task_list() {
  local key="$1"

  awk -v target="$key" '
    /^task:/ { in_task=1; next }
    in_task && /^[^[:space:]]/ { in_task=0 }
    in_task && $0 ~ ("^[[:space:]]*" target ":[[:space:]]*$") { in_list=1; next }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      print line
      next
    }
    in_list && $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*-/ { in_list=0 }
  ' "$task_file"
}

extract_task_scalar() {
  local key="$1"

  awk -v target="$key" '
    /^task:/ { in_task=1; next }
    in_task && /^[^[:space:]]/ { in_task=0 }
    in_task && $0 ~ ("^[[:space:]]*" target ":[[:space:]]*") {
      line=$0
      sub("^[[:space:]]*" target ":[[:space:]]*", "", line)
      gsub(/"/, "", line)
      print line
      exit
    }
  ' "$task_file"
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

changed_files="$(list_changed_files)"
changed_count=0
violations=0

if [ -n "$changed_files" ]; then
  changed_count="$(printf '%s\n' "$changed_files" | awk 'NF { count++ } END { print count + 0 }')"
fi

echo "== Scope Gate =="
echo "Task file: $task_file"
echo "Mode: $mode"
echo "Changed file count: $changed_count"

if [ -z "$changed_files" ]; then
  echo "No changed files detected."
  echo "Scope check passed."
  exit 0
fi

allowed_patterns="$(extract_task_list allowed_paths)"
forbidden_patterns="$(extract_task_list forbidden_paths)"
max_changed_files="$(extract_task_scalar max_changed_files)"
max_diff_lines="$(extract_task_scalar max_diff_lines)"

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
exit 1
