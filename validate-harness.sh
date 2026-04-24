#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
target_root="/tmp/test-agent-harness-target"
warnings_root="/tmp/test-agent-harness-warnings"
failure_root="/tmp/test-agent-harness-failure"

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "ERROR: expected output to contain: $expected"
    echo "File: $file"
    exit 1
  fi
}

echo "== Validate Agent-Repo-Harness =="

cd "$repo_root"

echo
echo "== Shell syntax =="
bash -n install-agent-harness.sh
for f in templates/scripts/*.sh; do
  bash -n "$f"
done

echo
echo "== Fresh install target =="
rm -rf "$target_root"
mkdir -p "$target_root"
git init -q "$target_root"

bash install-agent-harness.sh "$target_root"

echo
echo "== Installed target checks =="
(
  cd "$target_root"
  bash scripts/agent-preflight.sh
  bash scripts/check-agent-md.sh agent.md
  verify_log="$target_root/agent-verify-pass.log"
  bash scripts/agent-verify.sh >"$verify_log" 2>&1
  assert_contains "$verify_log" "Verification passed."
  bash scripts/check-policy.sh .agent/policy.yml
  bash scripts/collect-context.sh >/dev/null
)

echo
echo "== Warning-mode verification semantics =="
rm -rf "$warnings_root"
mkdir -p "$warnings_root"
(
  cd "$warnings_root"
  verify_log="$warnings_root/agent-verify-warnings.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "Verification completed with warnings."
)

echo
echo "== Failure-mode verification semantics =="
rm -rf "$failure_root"
mkdir -p "$failure_root/scripts"
cp templates/scripts/check-policy.sh "$failure_root/scripts/check-policy.sh"
chmod +x "$failure_root"/scripts/*.sh
printf '%s\n' '#!/usr/bin/env bash' 'if' >"$failure_root/scripts/bad.sh"
(
  cd "$failure_root"
  verify_log="$failure_root/agent-verify-failure.log"
  if bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1; then
    echo "ERROR: expected verification failure"
    exit 1
  fi
  assert_contains "$verify_log" "Verification failed."
)

echo
echo "Validation completed."
