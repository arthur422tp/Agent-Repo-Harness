#!/usr/bin/env bash
set -euo pipefail

if [ -z "${tmp_root:-}" ]; then
  source "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/lib.sh"
fi

release_integrity_root="$tmp_root/release-integrity"
rm -rf "$release_integrity_root"
mkdir -p "$release_integrity_root"

make_release_repo() {
  local root="$1"
  local version="$2"
  local unreleased_entry="${3:-}"

  rm -rf "$root"
  mkdir -p "$root/ci" "$root/docs"
  cp "$repo_root/ci/check-release-integrity.sh" \
    "$root/ci/check-release-integrity.sh"
  chmod +x "$root/ci/check-release-integrity.sh"
  printf '%s\n' "$version" >"$root/VERSION"
  {
    printf '%s\n' '# Changelog' '' '## Unreleased' ''
    if [ -n "$unreleased_entry" ]; then
      printf '%s\n' '### Changed' '' "- $unreleased_entry" ''
    fi
    printf '%s\n' "## v$version - Fixture release"
  } >"$root/CHANGELOG.md"
  printf '%s\n' \
    '# Public Packaging' \
    '' \
    "## v$version release checklist" \
    >"$root/docs/public-packaging.md"
  git -C "$root" init -q
  git -C "$root" config user.name "Harness Test"
  git -C "$root" config user.email "harness-test@example.invalid"
  git -C "$root" add .
  git -C "$root" commit -q -m "fixture release state"
}

assert_marker_once() {
  local file="$1"
  local marker="$2"
  local count
  count="$(grep -Fxc -- "$marker" "$file" || true)"
  if [ "$count" -ne 1 ]; then
    echo "ERROR: expected one marker '$marker', got $count"
    cat "$file"
    exit 1
  fi
}

echo
echo "== Release integrity accepts untagged development HEAD =="
development_root="$release_integrity_root/development"
make_release_repo "$development_root" "1.2.3"
bash "$development_root/ci/check-release-integrity.sh" \
  --repo-root "$development_root" >"$development_root/result.log" 2>&1
assert_marker_once "$development_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=pass"
pass "release integrity accepts untagged development HEAD"

echo
echo "== Release integrity accepts matching strict tag =="
strict_root="$release_integrity_root/strict"
make_release_repo "$strict_root" "1.2.3"
git -C "$strict_root" tag v1.2.3
bash "$strict_root/ci/check-release-integrity.sh" \
  --repo-root "$strict_root" --tag v1.2.3 \
  >"$strict_root/result.log" 2>&1
assert_marker_once "$strict_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=pass"
pass "release integrity accepts matching strict tag"

echo
echo "== Release integrity rejects malformed VERSION =="
invalid_root="$release_integrity_root/invalid-version"
make_release_repo "$invalid_root" "1.2.3"
printf '%s\n' '1.2' >"$invalid_root/VERSION"
if bash "$invalid_root/ci/check-release-integrity.sh" \
  --repo-root "$invalid_root" >"$invalid_root/result.log" 2>&1
then
  echo "ERROR: malformed VERSION passed"
  exit 1
fi
assert_contains "$invalid_root/result.log" \
  "VERSION must contain one stable MAJOR.MINOR.PATCH value"
assert_marker_once "$invalid_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects malformed VERSION"

echo
echo "== Release integrity rejects missing changelog heading =="
missing_changelog_root="$release_integrity_root/missing-changelog"
make_release_repo "$missing_changelog_root" "1.2.3"
printf '%s\n' '# Changelog' '## Unreleased' \
  >"$missing_changelog_root/CHANGELOG.md"
if bash "$missing_changelog_root/ci/check-release-integrity.sh" \
  --repo-root "$missing_changelog_root" \
  >"$missing_changelog_root/result.log" 2>&1
then
  echo "ERROR: missing changelog release heading passed"
  exit 1
fi
assert_contains "$missing_changelog_root/result.log" \
  "CHANGELOG.md is missing a v1.2.3 release heading"
assert_marker_once "$missing_changelog_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects missing changelog heading"

echo
echo "== Release integrity rejects missing public checklist heading =="
missing_checklist_root="$release_integrity_root/missing-checklist"
make_release_repo "$missing_checklist_root" "1.2.3"
printf '%s\n' '# Public Packaging' \
  >"$missing_checklist_root/docs/public-packaging.md"
if bash "$missing_checklist_root/ci/check-release-integrity.sh" \
  --repo-root "$missing_checklist_root" \
  >"$missing_checklist_root/result.log" 2>&1
then
  echo "ERROR: missing public checklist heading passed"
  exit 1
fi
assert_contains "$missing_checklist_root/result.log" \
  "docs/public-packaging.md is missing the v1.2.3 release checklist heading"
assert_marker_once "$missing_checklist_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects missing public checklist heading"

echo
echo "== Release integrity rejects a mismatched stable tag =="
mismatch_root="$release_integrity_root/tag-mismatch"
make_release_repo "$mismatch_root" "1.2.3"
git -C "$mismatch_root" tag v9.9.9
if bash "$mismatch_root/ci/check-release-integrity.sh" \
  --repo-root "$mismatch_root" >"$mismatch_root/result.log" 2>&1
then
  echo "ERROR: mismatched stable tag passed"
  exit 1
fi
assert_contains "$mismatch_root/result.log" \
  "HEAD tag v9.9.9 does not match VERSION 1.2.3"
assert_marker_once "$mismatch_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects a mismatched stable tag"

echo
echo "== Release integrity rejects duplicate stable tags =="
duplicate_root="$release_integrity_root/duplicate-tags"
make_release_repo "$duplicate_root" "1.2.3"
git -C "$duplicate_root" tag v1.2.3
git -C "$duplicate_root" tag v9.9.9
if bash "$duplicate_root/ci/check-release-integrity.sh" \
  --repo-root "$duplicate_root" >"$duplicate_root/result.log" 2>&1
then
  echo "ERROR: duplicate stable tags passed"
  exit 1
fi
assert_contains "$duplicate_root/result.log" \
  "multiple stable release tags point at HEAD"
assert_marker_once "$duplicate_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects duplicate stable tags"

echo
echo "== Strict tag mode rejects a requested tag away from HEAD =="
away_root="$release_integrity_root/tag-away-from-head"
make_release_repo "$away_root" "1.2.3"
git -C "$away_root" tag v1.2.3
printf '%s\n' 'after tag' >"$away_root/after-tag.txt"
git -C "$away_root" add after-tag.txt
git -C "$away_root" commit -q -m "move HEAD after tag"
if bash "$away_root/ci/check-release-integrity.sh" \
  --repo-root "$away_root" --tag v1.2.3 \
  >"$away_root/result.log" 2>&1
then
  echo "ERROR: requested tag away from HEAD passed"
  exit 1
fi
assert_contains "$away_root/result.log" \
  "requested tag v1.2.3 does not point at HEAD"
assert_marker_once "$away_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "strict tag mode rejects a requested tag away from HEAD"

echo
echo "== Strict tag mode rejects unreleased notes =="
unreleased_root="$release_integrity_root/unreleased"
make_release_repo "$unreleased_root" "1.2.3" "not yet released"
git -C "$unreleased_root" tag v1.2.3
if bash "$unreleased_root/ci/check-release-integrity.sh" \
  --repo-root "$unreleased_root" --tag v1.2.3 \
  >"$unreleased_root/result.log" 2>&1
then
  echo "ERROR: strict tag accepted Unreleased entries"
  exit 1
fi
assert_contains "$unreleased_root/result.log" \
  "strict tag mode requires an empty Unreleased section"
assert_marker_once "$unreleased_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "strict tag mode rejects unreleased notes"
