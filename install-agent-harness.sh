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

if [ ! -d "$template_root" ]; then
  echo "ERROR: template directory not found: $template_root"
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

if [ -d "$target/scripts" ]; then
  chmod +x "$target"/scripts/*.sh 2>/dev/null || true
fi

echo "Install complete."
echo
echo "Next steps:"
echo "1. Review $target/agent.md and fill in repo-specific facts."
echo "2. Review $target/.agent/policy.yml and customize risk patterns."
echo "3. Run: cd $target && bash scripts/agent-preflight.sh"
echo "4. Run: cd $target && bash scripts/check-agent-md.sh agent.md"
echo "5. Run: cd $target && bash scripts/agent-verify.sh"
