# Release Baseline Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add repository-only release metadata checks, a real prior-release upgrade proof, and one release-readiness entrypoint without changing installed harness runtime contracts.

**Architecture:** Keep ordinary source validation independent from external publishing state. Implement three focused `ci/` scripts: one validates version/tag/document metadata, one proves installer behavior across a prior stable tag, and one composes those checks with canonical validation and sandbox smoke. Hermetic harness suites exercise the scripts with temporary Git repositories; the final rollout also runs against the real `v0.1.1` tag.

**Tech Stack:** Bash 3.2-compatible shell, Git, standard Unix tools (`awk`, `grep`, `find`, `tar`), existing `tests/harness/lib.sh` assertions, GitHub Actions.

## Global Constraints

- Keep Agent-Repo-Harness a repo-local completion harness; do not add sandbox, provider-runtime, tracing, or semantic-correctness claims.
- New `ci/` scripts and test suites are repository-maintenance tooling and must not be copied by `install-agent-harness.sh`.
- Do not change `agent-finish.sh` CLI options, strict/best-effort semantics, gate order, result filenames, JSON fields, or installed task/evidence contracts.
- Preserve installer default-skip, `--force`, `--backup`, dry-run, and target-owned-file behavior.
- Use only Bash 3.2-compatible syntax in repository shell scripts; do not add `jq`, `yq`, PyYAML, Node, Ruby, or GNU-only command requirements.
- Treat `git`, `tar`, and full Git history as release-maintenance dependencies only, not installed-target runtime dependencies.
- Every new result-producing script must print exactly one final result marker on pass or fail.
- A missing sandbox runner remains an explicit documented skip; never relabel it as an isolation pass.
- Do not create or push a tag, GitHub Release, repository description, topic, or published artifact.
- Keep generated `.agent/` evidence untracked.
- Update this plan's checkboxes as each step is proven; include the plan file in every task commit so recorded task status matches evidence.

## File Structure

Create:

- `ci/check-release-integrity.sh`: validates `VERSION`, versioned docs, development HEAD tag state, and strict release-tag state.
- `ci/release-upgrade-smoke.sh`: exports a prior tag and proves default reinstall, forced backup upgrade, target-owned preservation, schema completeness, and installed lifecycle commands.
- `ci/release-readiness.sh`: composes integrity, canonical validation, upgrade smoke, sandbox smoke, and one final readiness marker.
- `tests/harness/release-integrity.sh`: hermetic metadata and orchestration contract cases using temporary Git repositories.
- `tests/harness/release-upgrade.sh`: hermetic synthetic-tag upgrade cases, including missing-tag and shallow-history failures.

Modify:

- `validate-harness.sh`: sources the two new hermetic test suites.
- `.github/workflows/ci.yml`: keeps normal validation and adds tag/manual full-history release readiness.
- `docs/versioning.md`: documents development versus strict tag modes and the supported upgrade command.
- `docs/public-packaging.md`: separates locally proven readiness from external publishing actions.
- `CHANGELOG.md`: records release-integrity tooling under `Unreleased`.
- `handoff.md`: records exact rollout commands, real prior tag, markers, and sandbox state.
- `docs/superpowers/plans/2026-07-15-release-baseline-integrity.md`: tracks proof-backed task status.

No installed template, schema, public runtime script, adapter, or README file changes in this plan.

---

### Task 1: Repository Release Integrity Contract

**Files:**
- Create: `tests/harness/release-integrity.sh`
- Create: `ci/check-release-integrity.sh`
- Modify: `validate-harness.sh:30-38`
- Modify: `docs/superpowers/plans/2026-07-15-release-baseline-integrity.md`

**Interfaces:**
- Produces: `bash ci/check-release-integrity.sh [--repo-root PATH] [--tag vMAJOR.MINOR.PATCH]`.
- Produces: exactly one `RELEASE_INTEGRITY_RESULT=pass|fail` final marker.
- Consumes: `VERSION`, `CHANGELOG.md`, `docs/public-packaging.md`, and Git tags at HEAD.
- Mode contract: no `--tag` means development mode; `--tag` means strict tag mode.

- [x] **Step 1: Add the hermetic release-integrity suite**

Create `tests/harness/release-integrity.sh` with this independently runnable
test harness and initial cases:

```bash
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
assert_contains "$invalid_root/result.log" "VERSION must contain one stable MAJOR.MINOR.PATCH value"
assert_marker_once "$invalid_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects malformed VERSION"

echo
echo "== Release integrity rejects missing versioned docs =="
missing_docs_root="$release_integrity_root/missing-docs"
make_release_repo "$missing_docs_root" "1.2.3"
printf '%s\n' '# Changelog' '## Unreleased' >"$missing_docs_root/CHANGELOG.md"
if bash "$missing_docs_root/ci/check-release-integrity.sh" \
  --repo-root "$missing_docs_root" >"$missing_docs_root/result.log" 2>&1
then
  echo "ERROR: missing changelog release heading passed"
  exit 1
fi
assert_contains "$missing_docs_root/result.log" "CHANGELOG.md is missing a v1.2.3 release heading"
assert_marker_once "$missing_docs_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects missing versioned docs"

echo
echo "== Release integrity rejects tag mismatch and duplicate stable tags =="
tag_root="$release_integrity_root/tag-mismatch"
make_release_repo "$tag_root" "1.2.3"
git -C "$tag_root" tag v1.2.3
git -C "$tag_root" tag v9.9.9
if bash "$tag_root/ci/check-release-integrity.sh" \
  --repo-root "$tag_root" >"$tag_root/result.log" 2>&1
then
  echo "ERROR: duplicate stable tags passed"
  exit 1
fi
assert_contains "$tag_root/result.log" "multiple stable release tags point at HEAD"
assert_marker_once "$tag_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "release integrity rejects tag mismatch and duplicate stable tags"

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
assert_contains "$unreleased_root/result.log" "strict tag mode requires an empty Unreleased section"
assert_marker_once "$unreleased_root/result.log" \
  "RELEASE_INTEGRITY_RESULT=fail"
pass "strict tag mode rejects unreleased notes"
```

- [x] **Step 2: Source the suite from canonical validation**

Add this line in `validate-harness.sh` immediately after
`sandbox-ci-smoke.sh` and before application fixtures:

```bash
source "$repo_root/tests/harness/release-integrity.sh"
```

- [x] **Step 3: Run the red phase and record the expected missing-script failure**

Run:

```bash
bash tests/harness/release-integrity.sh
```

Expected: nonzero. The first case must fail because
`ci/check-release-integrity.sh` does not exist. Record the command, exit status,
and first relevant failure immediately below this step before checking it off.

Recorded 2026-07-16:

- Command: `bash tests/harness/release-integrity.sh`
- Exit status: `1`
- First relevant failure:
  `cp: /Users/arthuryu/Desktop/Agent-Repo-Harness/ci/check-release-integrity.sh: No such file or directory`

- [x] **Step 4: Commit the red release-integrity contract**

```bash
git add tests/harness/release-integrity.sh validate-harness.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "test: define release integrity contract"
```

- [x] **Step 5: Implement the repository integrity checker**

Create `ci/check-release-integrity.sh`:

```bash
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
stable_tag_count="$(printf '%s\n' "$stable_tags" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
if [ "$stable_tag_count" -gt 1 ]; then
  die "multiple stable release tags point at HEAD"
fi
if [ "$stable_tag_count" -eq 1 ] && [ "$stable_tags" != "v$version" ]; then
  die "HEAD tag $stable_tags does not match VERSION $version"
fi

if [ -n "$requested_tag" ]; then
  printf '%s\n' "$requested_tag" | \
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
```

Make it executable:

```bash
chmod +x ci/check-release-integrity.sh
```

- [x] **Step 6: Run focused green verification**

Run:

```bash
bash tests/harness/release-integrity.sh
bash -n ci/check-release-integrity.sh tests/harness/release-integrity.sh
```

Expected: all release-integrity cases print `PASS`, and shell syntax exits 0.

Recorded 2026-07-16:

- `bash tests/harness/release-integrity.sh`: exit `0`, nine contract cases
  passed.
- `bash -n ci/check-release-integrity.sh tests/harness/release-integrity.sh`:
  exit `0`.
- `bash ci/check-release-integrity.sh`: exit `0` with
  `RELEASE_INTEGRITY_RESULT=pass` in development mode.

- [x] **Step 7: Commit the passing integrity checker**

```bash
git add ci/check-release-integrity.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "feat: validate release metadata integrity"
```

---

### Task 2: Real Prior-Release Upgrade Proof

**Files:**
- Create: `tests/harness/release-upgrade.sh`
- Create: `ci/release-upgrade-smoke.sh`
- Modify: `validate-harness.sh:30-40`
- Modify: `docs/superpowers/plans/2026-07-15-release-baseline-integrity.md`

**Interfaces:**
- Produces: `bash ci/release-upgrade-smoke.sh [--repo-root PATH] --from-tag vMAJOR.MINOR.PATCH [--keep-temp]`.
- Produces: exactly one `RELEASE_UPGRADE_RESULT=pass|fail` final marker.
- Consumes: a full Git checkout, the prior tag's installer package, and the current installer package.
- Guarantees: default reinstall preservation, forced backup replacement, target-owned preservation, public schema completeness, and installed preflight/verify/finish success.

- [x] **Step 1: Add the synthetic cross-release test repository**

Create `tests/harness/release-upgrade.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${tmp_root:-}" ]; then
  source "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/lib.sh"
fi

release_upgrade_root="$tmp_root/release-upgrade"
fixture_repo="$release_upgrade_root/repository"
rm -rf "$release_upgrade_root"
mkdir -p "$fixture_repo/templates/scripts" "$fixture_repo/schemas" \
  "$fixture_repo/ci"

cat >"$fixture_repo/install-agent-harness.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
target="${1:?target required}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
mkdir -p "$target/scripts" "$target/schemas"
cp -R "$script_dir/templates/." "$target/"
cp "$script_dir/schemas/"*.schema.json "$target/schemas/"
find "$target/scripts" -type f -name '*.sh' -exec chmod +x {} \;
SH
chmod +x "$fixture_repo/install-agent-harness.sh"
printf '%s\n' '# Fixture AGENTS' >"$fixture_repo/templates/AGENTS.md"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
  >"$fixture_repo/templates/scripts/agent-preflight.sh"
cp "$fixture_repo/templates/scripts/agent-preflight.sh" \
  "$fixture_repo/templates/scripts/agent-verify.sh"
cp "$fixture_repo/templates/scripts/agent-preflight.sh" \
  "$fixture_repo/templates/scripts/agent-finish.sh"
printf '%s\n' '{"fixture":true}' \
  >"$fixture_repo/schemas/policy.schema.json"

git -C "$fixture_repo" init -q
git -C "$fixture_repo" config user.name "Harness Test"
git -C "$fixture_repo" config user.email "harness-test@example.invalid"
git -C "$fixture_repo" add .
git -C "$fixture_repo" commit -q -m "previous release"
git -C "$fixture_repo" tag v0.1.0

cp "$repo_root/install-agent-harness.sh" "$fixture_repo/install-agent-harness.sh"
rm -rf "$fixture_repo/templates" "$fixture_repo/schemas"
cp -R "$repo_root/templates" "$fixture_repo/templates"
cp -R "$repo_root/schemas" "$fixture_repo/schemas"
cp "$repo_root/ci/release-upgrade-smoke.sh" \
  "$fixture_repo/ci/release-upgrade-smoke.sh"
chmod +x "$fixture_repo/install-agent-harness.sh" \
  "$fixture_repo/ci/release-upgrade-smoke.sh"
git -C "$fixture_repo" add .
git -C "$fixture_repo" commit -q -m "current release"

echo
echo "== Release upgrade smoke accepts a synthetic prior tag =="
if ! bash "$fixture_repo/ci/release-upgrade-smoke.sh" \
  --repo-root "$fixture_repo" --from-tag v0.1.0 \
  >"$release_upgrade_root/pass.log" 2>&1
then
  cat "$release_upgrade_root/pass.log"
  exit 1
fi
assert_contains "$release_upgrade_root/pass.log" \
  "PASS: default reinstall preserves managed sentinels"
assert_contains "$release_upgrade_root/pass.log" \
  "PASS: forced upgrade preserves backups and target-owned files"
assert_contains "$release_upgrade_root/pass.log" \
  "PASS: installed upgrade lifecycle"
assert_contains "$release_upgrade_root/pass.log" \
  "RELEASE_UPGRADE_RESULT=pass"
pass "release upgrade smoke accepts a synthetic prior tag"

echo
echo "== Release upgrade smoke rejects a missing prior tag =="
if bash "$fixture_repo/ci/release-upgrade-smoke.sh" \
  --repo-root "$fixture_repo" --from-tag v9.9.9 \
  >"$release_upgrade_root/missing.log" 2>&1
then
  echo "ERROR: missing prior tag passed"
  exit 1
fi
assert_contains "$release_upgrade_root/missing.log" \
  "requested prior release tag not found: v9.9.9"
assert_contains "$release_upgrade_root/missing.log" \
  "RELEASE_UPGRADE_RESULT=fail"
pass "release upgrade smoke rejects a missing prior tag"

echo
echo "== Release upgrade smoke rejects shallow history =="
shallow_repo="$release_upgrade_root/shallow"
git clone -q --depth 1 "file://$fixture_repo" "$shallow_repo"
if bash "$shallow_repo/ci/release-upgrade-smoke.sh" \
  --repo-root "$shallow_repo" --from-tag v0.1.0 \
  >"$release_upgrade_root/shallow.log" 2>&1
then
  echo "ERROR: shallow history passed"
  exit 1
fi
assert_contains "$release_upgrade_root/shallow.log" \
  "release upgrade smoke requires full Git history"
assert_contains "$release_upgrade_root/shallow.log" \
  "RELEASE_UPGRADE_RESULT=fail"
pass "release upgrade smoke rejects shallow history"
```

- [x] **Step 2: Source the upgrade suite from canonical validation**

Add immediately after the release-integrity suite in `validate-harness.sh`:

```bash
source "$repo_root/tests/harness/release-upgrade.sh"
```

- [x] **Step 3: Run and record the red phase**

Run:

```bash
bash tests/harness/release-upgrade.sh
```

Expected: nonzero because `ci/release-upgrade-smoke.sh` does not exist. Record
the exact exit status and first relevant failure under this step.

Recorded 2026-07-16: `bash tests/harness/release-upgrade.sh` exited `1` at
`cp: /Users/arthuryu/Desktop/Agent-Repo-Harness/ci/release-upgrade-smoke.sh: No such file or directory`.

- [x] **Step 4: Commit the red upgrade contract**

```bash
git add tests/harness/release-upgrade.sh validate-harness.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "test: define prior release upgrade contract"
```

- [x] **Step 5: Implement the prior-release upgrade smoke**

Create `ci/release-upgrade-smoke.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x ci/release-upgrade-smoke.sh
```

- [x] **Step 6: Run focused green verification**

```bash
bash tests/harness/release-upgrade.sh
bash -n ci/release-upgrade-smoke.sh tests/harness/release-upgrade.sh
```

Expected: synthetic upgrade passes; missing-tag and shallow-history cases fail
for their asserted reasons while the suite exits 0.

Recorded 2026-07-16:

- `bash tests/harness/release-upgrade.sh`: exit `0`; synthetic upgrade,
  missing-tag rejection, and shallow-history rejection all passed.
- The implementation asserts the public `PREFLIGHT_RESULT=pass` marker used by
  `agent-preflight.sh`, rather than the lower-level config validator marker.
- Schema enumeration uses portable newline-delimited `find | sort` over
  repository-controlled schema filenames; it does not require GNU `sort -z`.

- [x] **Step 7: Commit the passing upgrade proof**

```bash
git add ci/release-upgrade-smoke.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "feat: prove prior release upgrades"
```

---

### Task 3: Release Readiness Orchestration And CI

**Files:**
- Create: `ci/release-readiness.sh`
- Modify: `tests/harness/release-integrity.sh`
- Modify: `.github/workflows/ci.yml:3-27`
- Modify: `docs/superpowers/plans/2026-07-15-release-baseline-integrity.md`

**Interfaces:**
- Produces: `bash ci/release-readiness.sh [--repo-root PATH] [--from-tag vMAJOR.MINOR.PATCH] [--tag vMAJOR.MINOR.PATCH] [--keep-temp]`.
- Produces: exactly one `RELEASE_READINESS_RESULT=pass|fail` final marker.
- Consumes: Task 1 integrity checker and Task 2 upgrade smoke, plus `validate-harness.sh` and `ci/sandbox-smoke.sh`.
- Tag discovery: newest stable tag numerically lower than `VERSION`; prerelease and equal/higher tags are excluded.

- [x] **Step 1: Extend the integrity suite with hermetic orchestration cases**

Append this block to `tests/harness/release-integrity.sh`:

```bash
make_readiness_repo() {
  local root="$1"

  rm -rf "$root"
  mkdir -p "$root/ci" "$root/docs"
  cp "$repo_root/ci/check-release-integrity.sh" \
    "$root/ci/check-release-integrity.sh"
  cp "$repo_root/ci/release-readiness.sh" \
    "$root/ci/release-readiness.sh"
  chmod +x "$root/ci/"*.sh
  printf '%s\n' '1.2.2' >"$root/VERSION"
  printf '%s\n' '# Changelog' '' '## Unreleased' '' \
    '## v1.2.2 - Previous' >"$root/CHANGELOG.md"
  printf '%s\n' '# Public Packaging' '' \
    '## v1.2.2 release checklist' >"$root/docs/public-packaging.md"
  git -C "$root" init -q
  git -C "$root" config user.name "Harness Test"
  git -C "$root" config user.email "harness-test@example.invalid"
  git -C "$root" add .
  git -C "$root" commit -q -m "previous release"
  git -C "$root" tag v1.2.2

  printf '%s\n' '1.2.3' >"$root/VERSION"
  printf '%s\n' '# Changelog' '' '## Unreleased' '' \
    '## v1.2.3 - Current' '' '## v1.2.2 - Previous' \
    >"$root/CHANGELOG.md"
  printf '%s\n' '# Public Packaging' '' \
    '## v1.2.3 release checklist' >"$root/docs/public-packaging.md"
  cat >"$root/validate-harness.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'VALIDATE_FIXTURE=pass'
SH
  cat >"$root/ci/release-upgrade-smoke.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${READINESS_FIXTURE_ROOT:?}/upgrade-args.txt"
printf '%s\n' 'RELEASE_UPGRADE_RESULT=pass'
SH
  cat >"$root/ci/sandbox-smoke.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'SANDBOX_CI_SMOKE_RESULT=skip'
SH
  chmod +x "$root/validate-harness.sh" "$root/ci/"*.sh
  git -C "$root" add .
  git -C "$root" commit -q -m "current development"
}

echo
echo "== Release readiness composes development checks =="
readiness_root="$release_integrity_root/readiness"
make_readiness_repo "$readiness_root"
READINESS_FIXTURE_ROOT="$readiness_root" \
  bash "$readiness_root/ci/release-readiness.sh" \
    --repo-root "$readiness_root" \
    >"$readiness_root/result.log" 2>&1
assert_contains "$readiness_root/result.log" "VALIDATE_FIXTURE=pass"
assert_contains "$readiness_root/result.log" "SANDBOX_CI_SMOKE_RESULT=skip"
assert_contains "$readiness_root/upgrade-args.txt" "--from-tag v1.2.2"
assert_marker_once "$readiness_root/result.log" \
  "RELEASE_READINESS_RESULT=pass"
pass "release readiness composes development checks"

echo
echo "== Release readiness composes strict tag checks =="
git -C "$readiness_root" tag v1.2.3
READINESS_FIXTURE_ROOT="$readiness_root" \
  bash "$readiness_root/ci/release-readiness.sh" \
    --repo-root "$readiness_root" --tag v1.2.3 \
    >"$readiness_root/strict.log" 2>&1
assert_contains "$readiness_root/strict.log" "Release mode: strict tag v1.2.3"
assert_marker_once "$readiness_root/strict.log" \
  "RELEASE_READINESS_RESULT=pass"
pass "release readiness composes strict tag checks"

echo
echo "== Release readiness propagates child failure =="
cat >"$readiness_root/validate-harness.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'VALIDATE_FIXTURE=fail'
exit 1
SH
chmod +x "$readiness_root/validate-harness.sh"
if READINESS_FIXTURE_ROOT="$readiness_root" \
  bash "$readiness_root/ci/release-readiness.sh" \
    --repo-root "$readiness_root" \
    >"$readiness_root/fail.log" 2>&1
then
  echo "ERROR: child validation failure passed"
  exit 1
fi
assert_contains "$readiness_root/fail.log" "canonical validation failed"
assert_marker_once "$readiness_root/fail.log" \
  "RELEASE_READINESS_RESULT=fail"
pass "release readiness propagates child failure"
```

- [x] **Step 2: Run and record the orchestration red phase**

Run:

```bash
bash tests/harness/release-integrity.sh
```

Expected: existing integrity cases pass, then readiness fixture setup fails
because `ci/release-readiness.sh` does not exist. Record the first failure.

Recorded 2026-07-16: the nine integrity cases passed, then
`bash tests/harness/release-integrity.sh` exited `1` at
`cp: /Users/arthuryu/Desktop/Agent-Repo-Harness/ci/release-readiness.sh: No such file or directory`.

- [x] **Step 3: Commit the red orchestration contract**

```bash
git add tests/harness/release-integrity.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "test: define release readiness orchestration"
```

- [x] **Step 4: Implement the readiness orchestrator**

Create `ci/release-readiness.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x ci/release-readiness.sh
```

- [x] **Step 5: Run focused orchestration verification**

```bash
bash tests/harness/release-integrity.sh
bash -n ci/release-readiness.sh tests/harness/release-integrity.sh
```

Expected: development composition, strict tag composition, and child failure
propagation cases all print `PASS`.

- [x] **Step 6: Add explicit tag/manual release readiness to GitHub Actions**

Replace `.github/workflows/ci.yml` with:

```yaml
name: CI

on:
  push:
  pull_request:
  workflow_dispatch:
    inputs:
      from_tag:
        description: Stable prior release tag, for example v0.1.1
        required: false
        type: string

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash validate-harness.sh
      - name: Sandbox smoke
        run: bash ci/sandbox-smoke.sh
      - name: Verify universal adapter files are tracked
        run: |
          test -f templates/AGENTS.md
          test -f templates/CLAUDE.md
          test -f adapters/codex/AGENTS.md
          test -f adapters/codex/codex-start-prompt.md
          test -f adapters/claude-code/CLAUDE.md
          test -f docs/codex-usage.md
          test -f docs/agent-support-matrix.md
          test -f schemas/harness.schema.json
          test -f schemas/policy.schema.json
          test -f schemas/task.schema.json
          test -f schemas/handoff.schema.json

  release-readiness:
    if: startsWith(github.ref, 'refs/tags/v') || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run release readiness
        env:
          INPUT_FROM_TAG: ${{ inputs.from_tag }}
        run: |
          args=()
          if [ -n "$INPUT_FROM_TAG" ]; then
            args+=(--from-tag "$INPUT_FROM_TAG")
          fi
          case "$GITHUB_REF" in
            refs/tags/*)
              args+=(--tag "${GITHUB_REF#refs/tags/}")
              ;;
          esac
          bash ci/release-readiness.sh "${args[@]}"
```

- [x] **Step 7: Verify workflow syntax and focused suites**

```bash
bash -n ci/check-release-integrity.sh \
  ci/release-upgrade-smoke.sh \
  ci/release-readiness.sh
bash tests/harness/release-integrity.sh
bash tests/harness/release-upgrade.sh
bash validate-harness.sh
```

Expected: shell syntax exits 0; focused suites pass; canonical validation ends
with `PASS: productization examples and stability contract` and exit 0.

Recorded 2026-07-16:

- `bash -n ci/check-release-integrity.sh ci/release-upgrade-smoke.sh ci/release-readiness.sh tests/harness/release-integrity.sh`: exit `0`.
- `bash tests/harness/release-integrity.sh`: exit `0`, including development,
  strict-tag, and child-failure orchestration cases.
- `bash tests/harness/release-upgrade.sh`: exit `0`.
- `bash validate-harness.sh`: exit `0`, ending with
  `PASS: productization examples and stability contract`.

- [x] **Step 8: Commit orchestration and CI wiring**

```bash
git add ci/release-readiness.sh tests/harness/release-integrity.sh \
  .github/workflows/ci.yml \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "ci: add release readiness workflow"
```

---

### Task 4: Versioning Guidance And Final Release Evidence

**Files:**
- Modify: `tests/harness/release-integrity.sh`
- Modify: `docs/versioning.md:1-12`
- Modify: `docs/public-packaging.md:21-43`
- Modify: `CHANGELOG.md:3-13`
- Modify: `handoff.md:1-24`
- Modify: `docs/superpowers/plans/2026-07-15-release-baseline-integrity.md`

**Interfaces:**
- Consumes: all three repository-maintenance scripts and their final markers.
- Produces: truthful local-versus-external release documentation and exact rollout evidence.
- Final real-history command: `bash ci/release-readiness.sh --from-tag v0.1.1`.

- [x] **Step 1: Add executable documentation assertions**

Append these assertions to `tests/harness/release-integrity.sh`:

```bash
echo
echo "== Release documentation distinguishes local and external state =="
assert_contains "$repo_root/docs/versioning.md" \
  "bash ci/release-readiness.sh --from-tag v0.1.1"
assert_contains "$repo_root/docs/versioning.md" \
  "--force --backup"
assert_contains "$repo_root/docs/public-packaging.md" \
  "### Locally Verifiable Readiness"
assert_contains "$repo_root/docs/public-packaging.md" \
  "### External Publishing Actions"
assert_contains "$repo_root/docs/public-packaging.md" \
  "RELEASE_READINESS_RESULT=pass"
assert_contains "$repo_root/CHANGELOG.md" \
  "Add repository-only release integrity and prior-release upgrade checks."
pass "release documentation distinguishes local and external state"
```

- [x] **Step 2: Run and record the documentation red phase**

```bash
bash tests/harness/release-integrity.sh
```

Expected: nonzero at the first missing new documentation phrase. Record the
failure and do not weaken the assertion.

Recorded 2026-07-16: `bash tests/harness/release-integrity.sh` exited `1`
after all behavioral cases passed; the first missing phrase was
`bash ci/release-readiness.sh --from-tag v0.1.1` in `docs/versioning.md`.

- [x] **Step 3: Commit the red documentation contract**

```bash
git add tests/harness/release-integrity.sh \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "test: define release documentation contract"
```

- [x] **Step 4: Expand versioning and upgrade guidance**

Replace `docs/versioning.md` with:

```markdown
# Versioning And Upgrades

`VERSION` is the stable version represented by the current source package.
`CHANGELOG.md` records user-visible changes between released versions.

Development branches may contain entries under `Unreleased` without carrying
a release tag. A strict release-tag check requires `vMAJOR.MINOR.PATCH` to
match `VERSION`, point at HEAD, and have no remaining release entries under
`Unreleased`.

Run local release readiness against an explicit prior stable release:

```bash
bash ci/release-readiness.sh --from-tag v0.1.1
```

Installed repositories should review `CHANGELOG.md`, commit their current
harness baseline, preview the update, and then use the public installer:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh --force --backup /path/to/target-repo
```

The default installer preserves existing files. `--force --backup` replaces
harness-managed paths while retaining their previous contents as `.bak` files.
Target-owned files are not deleted. Review the resulting diff and rerun the
installed preflight, verification, and finish commands before committing the
upgrade.

Releases in the `v0.x` series may still change templates and workflow
conventions as the harness matures. Backward compatibility is best-effort
before v1.0 and follows `docs/stability-contract.md`.
```

- [x] **Step 5: Separate local readiness from external publishing actions**

Keep the existing `## v0.2.0 release checklist` heading in
`docs/public-packaging.md`. Replace its checklist and `Before Publishing`
section with:

```markdown
### Locally Verifiable Readiness

- [x] `VERSION` is `0.2.0` and matching version headings exist.
- [x] `bash validate-harness.sh` passes locally.
- [x] Public schema installation matches the current source schema set.
- [x] Runtime boundaries and intended-stable interfaces are documented.
- [x] Repository-only release integrity and prior-release upgrade checks are wired into canonical validation.
- [x] `bash ci/release-readiness.sh --from-tag v0.1.1` emits `RELEASE_READINESS_RESULT=pass`; preserve its explicit sandbox pass or skip marker in handoff evidence.

### External Publishing Actions

- [ ] CI is passing on the published default branch.
- [ ] Set the GitHub description.
- [ ] Set the GitHub topics.
- [ ] Create the GitHub release tag `v0.2.0` only from a strict-tag-ready commit.
- [ ] Verify the README renders correctly on GitHub.
- [ ] Verify the CI badge points to `.github/workflows/ci.yml`.
- [ ] Create GitHub release notes from the matching `CHANGELOG.md` section.
```

Do not change any external checkbox to checked from local evidence.

- [x] **Step 6: Record the user-visible maintenance change**

Add this bullet under `CHANGELOG.md` → `Unreleased` → `Changed`:

```markdown
- Add repository-only release integrity and prior-release upgrade checks.
```

- [x] **Step 7: Run the real prior-release readiness proof**

Run:

```bash
bash ci/release-readiness.sh --from-tag v0.1.1 \
  > /tmp/agent-harness-release-readiness.log 2>&1
status=$?
printf 'exit=%s\n' "$status"
grep -E '^(RELEASE_|SANDBOX_CI_SMOKE_RESULT=)' \
  /tmp/agent-harness-release-readiness.log
```

Expected:

- exit `0`;
- `RELEASE_INTEGRITY_RESULT=pass`;
- `RELEASE_UPGRADE_RESULT=pass`;
- `SANDBOX_CI_SMOKE_RESULT=pass` or the documented `skip`;
- `RELEASE_READINESS_RESULT=pass`.

If the command fails, stop and fix the failing contract before editing
`handoff.md` or checking the local readiness item.

Recorded 2026-07-16: exit `0` with
`RELEASE_INTEGRITY_RESULT=pass`, `RELEASE_UPGRADE_RESULT=pass`,
`SANDBOX_CI_SMOKE_RESULT=skip`, and `RELEASE_READINESS_RESULT=pass`.
The sandbox marker is an explicit skip because Docker or Podman is unavailable.

- [x] **Step 8: Update handoff with exact evidence**

Replace `handoff.md` with this structure, substituting only the actual sandbox
marker captured in Step 7:

```markdown
# handoff.md

## Current State

Release metadata integrity, prior-release upgrade behavior, and release
readiness orchestration are implemented as repository-maintenance checks.
Installed harness runtime contracts are unchanged.

## Verification

- `bash tests/harness/release-integrity.sh`: PASS
- `bash tests/harness/release-upgrade.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: `DOC_LINKS_RESULT=pass`
- `git diff --check`: PASS
- `bash validate-harness.sh`: PASS
- `bash ci/release-readiness.sh --from-tag v0.1.1`: `RELEASE_READINESS_RESULT=pass`
- Prior release: `v0.1.1`
- Sandbox smoke: copy the exact `SANDBOX_CI_SMOKE_RESULT=pass|skip` marker from the readiness log

## Compatibility

- New release scripts stay under `ci/` and are not installed into targets.
- Installer default skip, `--force`, `--backup`, and target-owned preservation remain compatible.
- Stable finish CLI, gate order, and evidence JSON contracts are unchanged.

## External State

- No tag or GitHub Release was created.
- Default-branch CI and GitHub repository metadata remain externally verified actions.

## Next Action

Review the release-baseline commits, then decide separately whether to publish
or continue with the next scoped stability sub-project.
```

The final handoff must contain the actual sandbox marker, not the literal
`pass|skip` alternatives.

- [x] **Step 9: Run the complete verification matrix**

```bash
bash tests/harness/release-integrity.sh
bash tests/harness/release-upgrade.sh
bash templates/scripts/check-doc-links.sh .
git diff --check
bash validate-harness.sh
bash ci/release-readiness.sh --from-tag v0.1.1
git status --short
```

Expected: every command exits 0; both focused suites print their final `PASS`
lines; doc links emit `DOC_LINKS_RESULT=pass`; canonical validation passes;
real readiness emits `RELEASE_READINESS_RESULT=pass`; Git status lists only
the files in this task plus untracked `.agent/` before commit.

Recorded 2026-07-16: both focused suites, doc links, `git diff --check`,
canonical validation, and real `v0.1.1` readiness exited `0`. Final readiness
again emitted integrity `pass`, upgrade `pass`, sandbox `skip`, and readiness
`pass`; pre-commit status contained only Task 4 files and untracked `.agent/`.

- [x] **Step 10: Audit the approved boundary**

Run:

```bash
git diff --name-only HEAD~1..HEAD
git diff --name-only main...HEAD
git status --short
```

Review the full branch diff and prove:

- no `templates/`, `schemas/`, public runtime, adapter, or README file changed;
- `.agent/` remains untracked;
- no release tag was created;
- external publishing boxes remain unchecked.

If any condition is false, remove the out-of-scope change or request a separate
design approval before continuing.

Recorded 2026-07-16: the complete `main` diff contains only `.github/`, `ci/`,
release tests, canonical test wiring, approved documentation, and this design
and plan. No template, schema, installed runtime, adapter, or README path
changed; HEAD has no release tag; external publishing boxes remain unchecked;
`.agent/` remains untracked.

- [x] **Step 11: Commit documentation and final evidence**

```bash
git add tests/harness/release-integrity.sh docs/versioning.md \
  docs/public-packaging.md CHANGELOG.md handoff.md \
  docs/superpowers/plans/2026-07-15-release-baseline-integrity.md
git commit -m "docs: record release baseline readiness"
```

- [ ] **Step 12: Verify the committed result**

```bash
bash templates/scripts/check-doc-links.sh .
git diff --check
bash validate-harness.sh
bash ci/release-readiness.sh --from-tag v0.1.1
git status --short --branch
git log --oneline main..HEAD
```

Expected: all verification commands exit 0; status shows only untracked
`.agent/`; commit history shows the task-scoped red/green commits plus design
and plan commits; no tag, push, or GitHub Release action has occurred.

---

## Completion Evidence

Do not fill this section from expectation. During execution, record:

- each red-phase command, exit status, and first relevant failure;
- each focused green command and result marker;
- the exact real prior tag used;
- canonical validation exit status;
- real release-readiness markers, including the sandbox pass or skip state;
- final branch diff and status;
- commit hashes for each task boundary.

The plan is complete only when every checkbox is checked from current evidence,
the committed result has been re-verified, and `.agent/` remains untracked.
