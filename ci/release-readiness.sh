#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
from_tag=""
requested_tag=""
keep_temp=0
result="fail"

emit_result() {
  printf '%s\n' "RELEASE_READINESS_RESULT=$result"
}
trap emit_result EXIT

usage() {
  cat <<'EOF'
Usage: release-readiness.sh [--repo-root PATH] [--from-tag vMAJOR.MINOR.PATCH] [--tag vMAJOR.MINOR.PATCH] [--keep-temp]
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

is_lower_version() {
  candidate="${1#v}"
  current="$2"
  old_ifs="$IFS"
  IFS=.
  set -- $candidate
  c_major="$1" c_minor="$2" c_patch="$3"
  set -- $current
  v_major="$1" v_minor="$2" v_patch="$3"
  IFS="$old_ifs"
  [ "$c_major" -lt "$v_major" ] || {
    [ "$c_major" -eq "$v_major" ] && [ "$c_minor" -lt "$v_minor" ]
  } || {
    [ "$c_major" -eq "$v_major" ] && [ "$c_minor" -eq "$v_minor" ] && \
      [ "$c_patch" -lt "$v_patch" ]
  }
}

discover_previous_tag() {
  current_version="$(sed -n '1p' "$repo_root/VERSION")"
  while IFS= read -r candidate_tag; do
    printf '%s\n' "$candidate_tag" | \
      grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || continue
    if is_lower_version "$candidate_tag" "$current_version"; then
      printf '%s\n' "$candidate_tag"
      return 0
    fi
  done < <(git -C "$repo_root" tag --sort=-version:refname)
  return 1
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
    --tag)
      [ "$#" -ge 2 ] || die "--tag requires a value"
      requested_tag="$2"
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

integrity_args=(--repo-root "$repo_root")
if [ -n "$requested_tag" ]; then
  integrity_args+=(--tag "$requested_tag")
fi
bash "$repo_root/ci/check-release-integrity.sh" "${integrity_args[@]}" || \
  die "release integrity check failed"

if [ -z "$from_tag" ]; then
  from_tag="$(discover_previous_tag)" || \
    die "no stable prior release tag is lower than VERSION"
fi

bash "$repo_root/validate-harness.sh" || die "canonical validation failed"

upgrade_args=(--repo-root "$repo_root" --from-tag "$from_tag")
if [ "$keep_temp" -eq 1 ]; then
  upgrade_args+=(--keep-temp)
fi
bash "$repo_root/ci/release-upgrade-smoke.sh" "${upgrade_args[@]}" || \
  die "prior release upgrade smoke failed"

bash "$repo_root/ci/sandbox-smoke.sh" || die "sandbox smoke failed"

if [ -n "$requested_tag" ]; then
  printf '%s\n' "Release readiness mode: strict tag $requested_tag"
else
  printf '%s\n' "Release readiness mode: development"
fi
printf '%s\n' "Previous release: $from_tag"
result="pass"
