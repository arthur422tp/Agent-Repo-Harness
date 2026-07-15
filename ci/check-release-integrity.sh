#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
requested_tag=""
result="fail"

emit_result() {
  printf '%s\n' "RELEASE_INTEGRITY_RESULT=$result"
}
trap emit_result EXIT

usage() {
  cat <<'EOF'
Usage: check-release-integrity.sh [--repo-root PATH] [--tag vMAJOR.MINOR.PATCH]
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      [ "$#" -ge 2 ] || die "--repo-root requires a path"
      repo_root="$2"
      shift 2
      ;;
    --tag)
      [ "$#" -ge 2 ] || die "--tag requires a value"
      requested_tag="$2"
      shift 2
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

[ -d "$repo_root" ] || die "repository root does not exist: $repo_root"
[ -f "$repo_root/VERSION" ] || die "VERSION not found: $repo_root/VERSION"
[ -f "$repo_root/CHANGELOG.md" ] || die "CHANGELOG.md not found"
[ -f "$repo_root/docs/public-packaging.md" ] || \
  die "docs/public-packaging.md not found"
git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || \
  die "release integrity requires a Git repository"

version_line_count="$(wc -l <"$repo_root/VERSION" | tr -d '[:space:]')"
version="$(sed -n '1p' "$repo_root/VERSION")"
case "$version" in
  *[!0-9.]*|.*|*..*|*.)
    die "VERSION must contain one stable MAJOR.MINOR.PATCH value"
    ;;
esac
if [ "$version_line_count" -ne 1 ] || \
  ! printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
then
  die "VERSION must contain one stable MAJOR.MINOR.PATCH value"
fi

version_pattern="${version//./\\.}"
grep -Eq "^## v${version_pattern}([[:space:]-]|$)" \
  "$repo_root/CHANGELOG.md" || \
  die "CHANGELOG.md is missing a v$version release heading"
grep -Eq "^## v${version_pattern} release checklist$" \
  "$repo_root/docs/public-packaging.md" || \
  die "docs/public-packaging.md is missing the v$version release checklist heading"

stable_tags="$(
  git -C "$repo_root" tag --points-at HEAD |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true
)"
stable_tag_count="$(
  printf '%s\n' "$stable_tags" |
    sed '/^$/d' |
    wc -l |
    tr -d '[:space:]'
)"
if [ "$stable_tag_count" -gt 1 ]; then
  die "multiple stable release tags point at HEAD"
fi
if [ "$stable_tag_count" -eq 1 ] && [ "$stable_tags" != "v$version" ]; then
  die "HEAD tag $stable_tags does not match VERSION $version"
fi

if [ -n "$requested_tag" ]; then
  printf '%s\n' "$requested_tag" |
    grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || \
    die "--tag must be vMAJOR.MINOR.PATCH"
  [ "$requested_tag" = "v$version" ] || \
    die "requested tag $requested_tag does not match VERSION $version"
  tag_commit="$(
    git -C "$repo_root" rev-parse "$requested_tag^{commit}" 2>/dev/null
  )" || die "requested tag not found: $requested_tag"
  head_commit="$(git -C "$repo_root" rev-parse HEAD)" || \
    die "cannot resolve HEAD"
  [ "$tag_commit" = "$head_commit" ] || \
    die "requested tag $requested_tag does not point at HEAD"
  unreleased_entries="$(
    awk '
      /^## Unreleased[[:space:]]*$/ { active=1; next }
      active && /^## / { exit }
      active && /^[[:space:]]*[-*][[:space:]]+/ { print }
    ' "$repo_root/CHANGELOG.md"
  )"
  [ -z "$unreleased_entries" ] || \
    die "strict tag mode requires an empty Unreleased section"
fi

printf '%s\n' "Release metadata: v$version"
if [ -n "$requested_tag" ]; then
  printf '%s\n' "Release mode: strict tag $requested_tag"
else
  printf '%s\n' "Release mode: development"
fi
result="pass"
