#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
from_tag=""
keep_temp=0
result="fail"
work_root=""

cleanup() {
  status=$?
  if [ -n "$work_root" ] && [ -d "$work_root" ]; then
    if [ "$keep_temp" -eq 1 ]; then
      printf '%s\n' "Release upgrade temp: $work_root"
    else
      rm -rf "$work_root"
    fi
  fi
  printf '%s\n' "RELEASE_UPGRADE_RESULT=$result"
  exit "$status"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: release-upgrade-smoke.sh [--repo-root PATH] --from-tag vMAJOR.MINOR.PATCH [--keep-temp]
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  expected="$2"
  grep -Fq -- "$expected" "$file" || \
    die "expected $file to contain: $expected"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      [ "$#" -ge 2 ] || die "--repo-root requires a path"
      repo_root="$2"
      shift 2
      ;;
    --from-tag)
      [ "$#" -ge 2 ] || die "--from-tag requires a value"
      from_tag="$2"
      shift 2
      ;;
    --keep-temp)
      keep_temp=1
      shift
      ;;
    -h|--help)
      usage
      result="pass"
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$from_tag" ] || die "--from-tag is required"
printf '%s\n' "$from_tag" | \
  grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || \
  die "--from-tag must be vMAJOR.MINOR.PATCH"
git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || \
  die "release upgrade smoke requires a Git repository"
shallow="$(git -C "$repo_root" rev-parse --is-shallow-repository 2>/dev/null)" || \
  die "cannot inspect Git history"
[ "$shallow" = "false" ] || \
  die "release upgrade smoke requires full Git history"
git -C "$repo_root" rev-parse "$from_tag^{commit}" >/dev/null 2>&1 || \
  die "requested prior release tag not found: $from_tag"
[ -f "$repo_root/install-agent-harness.sh" ] || \
  die "current installer not found"
[ -d "$repo_root/templates" ] || die "current templates not found"
[ -d "$repo_root/schemas" ] || die "current schemas not found"
command -v tar >/dev/null 2>&1 || die "tar is required"

work_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-release-upgrade.XXXXXX")" || \
  die "cannot create release upgrade temp directory"
previous_source="$work_root/previous-source"
target="$work_root/target"
mkdir -p "$previous_source" "$target"

if ! git -C "$repo_root" archive "$from_tag" | tar -x -C "$previous_source"; then
  die "failed to export prior release package: $from_tag"
fi
[ -f "$previous_source/install-agent-harness.sh" ] || \
  die "prior release has no installer: $from_tag"

git -C "$target" init -q
git -C "$target" config user.name "Harness Release Smoke"
git -C "$target" config user.email "harness-release-smoke@example.invalid"
bash "$previous_source/install-agent-harness.sh" "$target" \
  >"$work_root/previous-install.log" 2>&1 || \
  die "prior release installation failed: $from_tag"
git -C "$target" add .
git -C "$target" commit -q -m "install $from_tag baseline"

printf '%s\n' 'PRE_UPGRADE_AGENT_SENTINEL' >>"$target/AGENTS.md"
printf '%s\n' 'PRE_UPGRADE_SCHEMA_SENTINEL' \
  >>"$target/schemas/policy.schema.json"
printf '%s\n' '{"target_owned":true}' \
  >"$target/schemas/target-owned.schema.json"
cp "$target/AGENTS.md" "$work_root/AGENTS.before"
cp "$target/schemas/policy.schema.json" "$work_root/policy.before"
cp "$target/schemas/target-owned.schema.json" "$work_root/target-owned.before"

bash "$repo_root/install-agent-harness.sh" "$target" \
  >"$work_root/default-reinstall.log" 2>&1 || \
  die "current default reinstall failed"
cmp -s "$work_root/AGENTS.before" "$target/AGENTS.md" || \
  die "default reinstall overwrote AGENTS.md"
cmp -s "$work_root/policy.before" "$target/schemas/policy.schema.json" || \
  die "default reinstall overwrote policy schema"
cmp -s "$work_root/target-owned.before" \
  "$target/schemas/target-owned.schema.json" || \
  die "default reinstall changed target-owned schema"
printf '%s\n' "PASS: default reinstall preserves managed sentinels"

bash "$repo_root/install-agent-harness.sh" --force --backup "$target" \
  >"$work_root/forced-upgrade.log" 2>&1 || \
  die "current forced backup upgrade failed"
cmp -s "$repo_root/templates/AGENTS.md" "$target/AGENTS.md" || \
  die "forced upgrade did not install current AGENTS.md"
assert_contains "$target/AGENTS.md.bak" "PRE_UPGRADE_AGENT_SENTINEL"
cmp -s "$repo_root/schemas/policy.schema.json" \
  "$target/schemas/policy.schema.json" || \
  die "forced upgrade did not install current policy schema"
assert_contains "$target/schemas/policy.schema.json.bak" \
  "PRE_UPGRADE_SCHEMA_SENTINEL"
cmp -s "$work_root/target-owned.before" \
  "$target/schemas/target-owned.schema.json" || \
  die "forced upgrade changed target-owned schema"
printf '%s\n' "PASS: forced upgrade preserves backups and target-owned files"

find "$repo_root/schemas" -type f -name '*.schema.json' \
  ! -path "$repo_root/schemas/*/*" -print | LC_ALL=C sort |
while IFS= read -r schema_path; do
  schema_name="$(basename "$schema_path")"
  cmp -s "$schema_path" "$target/schemas/$schema_name" || \
    die "current public schema missing or stale after upgrade: $schema_name"
done
printf '%s\n' "PASS: current public schema set is installed"

(
  cd "$target" || exit 1
  bash scripts/agent-preflight.sh >"$work_root/preflight.log" 2>&1
  bash scripts/agent-verify.sh --best-effort >"$work_root/verify.log" 2>&1
  bash scripts/agent-finish.sh --best-effort >"$work_root/finish.log" 2>&1
) || die "installed upgrade lifecycle command failed"
assert_contains "$work_root/preflight.log" "PREFLIGHT_RESULT=pass"
assert_contains "$work_root/verify.log" "HARNESS_VERIFY_RESULT=pass"
assert_contains "$work_root/finish.log" "AGENT_FINISH_RESULT=pass"
printf '%s\n' "PASS: installed upgrade lifecycle"

printf '%s\n' "Prior release: $from_tag"
result="pass"
