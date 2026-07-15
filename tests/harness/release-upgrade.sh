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
bash "$fixture_repo/ci/release-upgrade-smoke.sh" \
  --repo-root "$fixture_repo" --from-tag v0.1.0 \
  >"$release_upgrade_root/pass.log" 2>&1
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
