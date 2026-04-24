#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
target_root="/tmp/test-agent-harness-target"
warnings_root="/tmp/test-agent-harness-warnings"
failure_root="/tmp/test-agent-harness-failure"
scope_skip_root="/tmp/test-agent-harness-scope-skip"
scope_pass_root="/tmp/test-agent-harness-scope-pass"
scope_max_files_root="/tmp/test-agent-harness-scope-max-files"
scope_outside_root="/tmp/test-agent-harness-scope-outside"
scope_forbidden_root="/tmp/test-agent-harness-scope-forbidden"
policy_strict_root="/tmp/test-agent-harness-policy-strict"
verify_config_root="/tmp/test-agent-harness-verify-config"

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "ERROR: expected output to contain: $expected"
    echo "File: $file"
    exit 1
  fi
}

assert_exists() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "ERROR: expected path to exist: $path"
    exit 1
  fi
}

echo "== Validate Agent-Repo-Harness =="

cd "$repo_root"

echo
echo "== Shell syntax =="
bash -n install-agent-harness.sh
bash -n validate-harness.sh
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
  assert_exists "$target_root/.agent/task.yml"
  assert_exists "$target_root/scripts/check-scope.sh"
  scope_log="$target_root/check-scope-fresh-install.log"
  bash scripts/check-scope.sh >"$scope_log" 2>&1
  assert_contains "$scope_log" "Scope check passed."
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
echo "== Scope gate skip semantics =="
rm -rf "$scope_skip_root"
mkdir -p "$scope_skip_root"
git init -q "$scope_skip_root"
(
  cd "$scope_skip_root"
  scope_log="$scope_skip_root/scope-skip.log"
  bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1
  assert_contains "$scope_log" "SKIP: task file not found"
  assert_contains "$scope_log" "Scope check skipped."
)

echo
echo "== Scope gate pass semantics =="
rm -rf "$scope_pass_root"
mkdir -p "$scope_pass_root/.agent" "$scope_pass_root/src/retry"
git init -q "$scope_pass_root"
(
  cd "$scope_pass_root"
  printf '%s\n' \
    'task:' \
    '  allowed_paths:' \
    '    - "src/retry/**"' \
    '  max_changed_files: 2' \
    '  max_diff_lines: 50' \
    > .agent/task.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .agent/task.yml
  git commit -q -m "Add task config"
  printf '%s\n' 'line one' > src/retry/worker.js
  scope_log="/tmp/test-agent-harness-scope-pass.log"
  bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1
  assert_contains "$scope_log" "Scope check passed."
)

echo
echo "== Scope gate max_changed_files failure =="
rm -rf "$scope_max_files_root"
mkdir -p "$scope_max_files_root/.agent" "$scope_max_files_root/src/retry"
git init -q "$scope_max_files_root"
(
  cd "$scope_max_files_root"
  printf '%s\n' \
    'task:' \
    '  max_changed_files: 1' \
    > .agent/task.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .agent/task.yml
  git commit -q -m "Add task config"
  printf '%s\n' 'line one' > src/retry/worker.js
  printf '%s\n' 'line two' > src/retry/helper.js
  scope_log="/tmp/test-agent-harness-scope-max-files.log"
  if bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1; then
    echo "ERROR: expected scope failure for max_changed_files"
    exit 1
  fi
  assert_contains "$scope_log" "exceeds max_changed_files"
  assert_contains "$scope_log" "Scope check failed."
)

echo
echo "== Scope gate allowed-path failure =="
rm -rf "$scope_outside_root"
mkdir -p "$scope_outside_root/.agent" "$scope_outside_root/src/auth"
git init -q "$scope_outside_root"
(
  cd "$scope_outside_root"
  printf '%s\n' \
    'task:' \
    '  allowed_paths:' \
    '    - "src/retry/**"' \
    > .agent/task.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .agent/task.yml
  git commit -q -m "Add task config"
  printf '%s\n' 'line one' > src/auth/session.js
  scope_log="/tmp/test-agent-harness-scope-outside.log"
  if bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1; then
    echo "ERROR: expected scope failure for out-of-scope file"
    exit 1
  fi
  assert_contains "$scope_log" "outside allowed_paths"
  assert_contains "$scope_log" "Scope check failed."
)

echo
echo "== Scope gate forbidden-path failure =="
rm -rf "$scope_forbidden_root"
mkdir -p "$scope_forbidden_root/.agent" "$scope_forbidden_root/src/billing"
git init -q "$scope_forbidden_root"
(
  cd "$scope_forbidden_root"
  printf '%s\n' \
    'task:' \
    '  forbidden_paths:' \
    '    - "src/billing/**"' \
    > .agent/task.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .agent/task.yml
  git commit -q -m "Add task config"
  printf '%s\n' 'line one' > src/billing/invoice.js
  scope_log="/tmp/test-agent-harness-scope-forbidden.log"
  if bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1; then
    echo "ERROR: expected scope failure for forbidden file"
    exit 1
  fi
  assert_contains "$scope_log" "matches forbidden_paths"
  assert_contains "$scope_log" "Scope check failed."
)

echo
echo "== Strict policy semantics =="
rm -rf "$policy_strict_root"
mkdir -p "$policy_strict_root/.agent" "$policy_strict_root/src/auth"
git init -q "$policy_strict_root"
(
  cd "$policy_strict_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' 'line one' > src/auth/login.js
  strict_log="$policy_strict_root/policy-strict.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$strict_log" 2>&1; then
    echo "ERROR: expected strict policy failure without approval"
    exit 1
  fi
  assert_contains "$strict_log" "Strict policy gate failed."

  strict_approved_log="$policy_strict_root/policy-strict-approved.log"
  AGENT_APPROVED_HIGH_RISK=1 bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$strict_approved_log" 2>&1
  assert_contains "$strict_approved_log" "High-risk approval detected from environment."
  assert_contains "$strict_approved_log" "Strict policy gate passed with approval."
)

echo
echo "== Repo-defined verification commands =="
rm -rf "$verify_config_root"
mkdir -p "$verify_config_root/.agent"
(
  cd "$verify_config_root"
  printf '%s\n' \
    'verification:' \
    '  required:' \
    '    - name: shell-check' \
    '      command: bash -n scripts/check-policy.sh' \
    > .agent/harness.yml
  mkdir -p scripts
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  chmod +x scripts/check-policy.sh
  verify_log="$verify_config_root/agent-verify-config.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "Repo-defined verification commands found."
  assert_contains "$verify_log" "RUN: shell-check"
  assert_contains "$verify_log" "PASS: shell-check"
)

echo
echo "Validation completed."
