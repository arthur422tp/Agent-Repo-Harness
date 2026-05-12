#!/usr/bin/env bash
set -euo pipefail

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
pass "scope skip semantics"

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
pass "scope pass semantics"

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
pass "scope max_changed_files failure"

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
pass "scope allowed-path failure"

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
pass "scope forbidden-path failure"

echo
echo "== Scope gate malformed task YAML failure =="
rm -rf "$scope_malformed_root"
mkdir -p "$scope_malformed_root/.agent" "$scope_malformed_root/src/retry"
git init -q "$scope_malformed_root"
(
  cd "$scope_malformed_root"
  printf 'task:\n\tallowed_paths:\n\t  - "src/retry/**"\n' > .agent/task.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .agent/task.yml
  git commit -q -m "Add malformed task config"
  printf '%s\n' 'line one' > src/retry/worker.js
  scope_log="$scope_malformed_root/scope-malformed.log"
  if bash "$repo_root/templates/scripts/check-scope.sh" >"$scope_log" 2>&1; then
    echo "ERROR: expected scope failure for malformed task YAML"
    exit 1
  fi
  assert_contains "$scope_log" "ERROR:"
  assert_contains "$scope_log" "tabs are not supported for indentation"
)
pass "scope malformed task YAML failure"

echo
