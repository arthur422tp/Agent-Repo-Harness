#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-agent-harness.sh [--dry-run] [--force] [--backup] TARGET_REPO

Copies the contents of templates/ into TARGET_REPO.

Options:
  --dry-run   Show planned actions without copying files
  --force     Allow overwriting existing files
  --backup    Create .bak copies before overwriting existing files
  -h, --help  Show this help text
EOF
}

dry_run=0
force=0
backup=0
target=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --force)
      force=1
      ;;
    --backup)
      backup=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -n "$target" ]; then
        echo "ERROR: multiple target paths provided"
        exit 1
      fi
      target="$1"
      ;;
  esac
  shift
done

if [ -z "$target" ]; then
  usage
  exit 1
fi

case "$target" in
  /|".")
    echo "ERROR: refusing dangerous target path: $target"
    exit 1
    ;;
esac

if [ ! -d "$target" ]; then
  echo "ERROR: target repo does not exist: $target"
  exit 1
fi

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
template_root="$script_dir/templates"
schema_root="$script_dir/schemas"

if [ ! -d "$template_root" ]; then
  echo "ERROR: template directory not found: $template_root"
  exit 1
fi

if [ ! -d "$schema_root" ]; then
  echo "ERROR: schema directory not found: $schema_root"
  exit 1
fi

schema_paths=()
while IFS= read -r -d '' schema_path; do
  schema_paths[${#schema_paths[@]}]="$schema_path"
done < <(
  find "$schema_root" \
    -type f \
    -name "*.schema.json" \
    ! -path "$schema_root/*/*" \
    -print0 | LC_ALL=C sort -z
)

if [ "${#schema_paths[@]}" -eq 0 ]; then
  echo "ERROR: no public schema files found in: $schema_root"
  exit 1
fi

copy_path() {
  local source="$1"
  local destination="$2"

  if [ -e "$destination" ] && [ "$force" -ne 1 ]; then
    echo "SKIP existing: $destination"
    return 0
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "DRY-RUN copy: $source -> $destination"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  if [ -e "$destination" ] && [ "$backup" -eq 1 ]; then
    cp -p "$destination" "$destination.bak"
    echo "BACKUP: $destination.bak"
  fi
  cp -p "$source" "$destination"
  echo "COPIED: $destination"
}

ensure_runtime_ignores() {
  local ignore_file="$target/.gitignore"
  local entry
  local missing=""

  for entry in \
    ".agent/runs/" \
    ".agent/audits/" \
    ".agent/command-runs/" \
    ".agent/sandbox-runs/"
  do
    if [ ! -f "$ignore_file" ] || ! grep -Fqx -- "$entry" "$ignore_file"; then
      missing="${missing}${missing:+
}$entry"
    fi
  done
  if [ -z "$missing" ]; then
    echo "UNCHANGED: $ignore_file already ignores harness runtime evidence"
    return 0
  fi
  if [ "$dry_run" -eq 1 ]; then
    printf '%s\n' "$missing" | sed "s|^|DRY-RUN append to $ignore_file: |"
    return 0
  fi
  if [ -f "$ignore_file" ] && [ -s "$ignore_file" ]; then
    printf '\n' >> "$ignore_file"
  fi
  printf '%s\n' "# Agent-Repo-Harness runtime evidence" >> "$ignore_file"
  printf '%s\n' "$missing" >> "$ignore_file"
  echo "UPDATED: $ignore_file"
}

echo "Installing Agent-Repo-Harness templates into $target"

while IFS= read -r -d '' path; do
  rel="${path#"$template_root"/}"
  dest="$target/$rel"

  if [ -d "$path" ]; then
    if [ "$dry_run" -eq 1 ]; then
      echo "DRY-RUN mkdir: $dest"
    else
      mkdir -p "$dest"
    fi
    continue
  fi

  copy_path "$path" "$dest"
done < <(find "$template_root" -mindepth 1 -print0 | sort -z)

for schema_path in "${schema_paths[@]}"; do
  schema_name="$(basename "$schema_path")"
  copy_path "$schema_path" "$target/schemas/$schema_name"
done

ensure_runtime_ignores

if [ -d "$target/scripts" ] && \
  find "$target/scripts" -type f -name "*.sh" | grep -q .
then
  while IFS= read -r -d '' script; do
    chmod +x "$script"
  done < <(find "$target/scripts" -type f -name "*.sh" -print0)
fi

echo "Install complete."
echo
echo "Next:"
escaped_target="$(printf '%q' "$target")"
echo "1. cd $escaped_target"
echo "2. Review .agent/task.yml and adjust the task goal/scope."
echo "3. Run bash scripts/agent-finish.sh --best-effort."
echo "Advanced gates, policy approval, adapters, and subagent workflows are documented in README.md and docs/."
