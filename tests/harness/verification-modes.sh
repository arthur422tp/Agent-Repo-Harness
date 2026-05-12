#!/usr/bin/env bash
set -euo pipefail

echo "== Warning-mode verification semantics =="
rm -rf "$warnings_root"
mkdir -p "$warnings_root"
(
  cd "$warnings_root"
  verify_log="$warnings_root/agent-verify-warnings.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=warn"
  assert_contains "$verify_log" "Verification completed with warnings."
)
pass "warning-mode verification semantics"

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
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=fail"
  assert_contains "$verify_log" "Verification failed."
)
pass "failure-mode verification semantics"

echo
