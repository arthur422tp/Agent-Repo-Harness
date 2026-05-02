#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-validate.XXXXXX")"
target_root="$tmp_root/target"
warnings_root="$tmp_root/warnings"
failure_root="$tmp_root/failure"
scope_skip_root="$tmp_root/scope-skip"
scope_pass_root="$tmp_root/scope-pass"
scope_max_files_root="$tmp_root/scope-max-files"
scope_outside_root="$tmp_root/scope-outside"
scope_forbidden_root="$tmp_root/scope-forbidden"
policy_strict_root="$tmp_root/policy-strict"
verify_config_root="$tmp_root/verify-config"
finish_strict_root="$tmp_root/finish-strict"
finish_nongit_root="$tmp_root/finish-nongit"

cleanup() {
  rm -rf "$tmp_root"
}

trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

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

assert_file_contains() {
  local root="$1"
  local name="$2"
  local expected="$3"
  local file

  file="$(find "$root/.agent/runs" -type f -name "$name" | head -n 1)"
  if [ -z "$file" ]; then
    echo "ERROR: expected run evidence file named: $name"
    exit 1
  fi

  assert_contains "$file" "$expected"
}

assert_run_evidence_files() {
  local root="$1"
  local file

  for file in \
    finish-summary.md \
    check-agent-md-result.txt \
    scope-result.txt \
    policy-result.txt \
    verify-result.txt \
    changed-files.txt \
    git-diff-stat.txt
  do
    if ! find "$root/.agent/runs" -type f -name "$file" | grep -q .; then
      echo "ERROR: expected run evidence file named: $file"
      exit 1
    fi
  done
}

run_yaml_syntax_checks() {
  local yaml_files=()
  local file

  while IFS= read -r -d '' file; do
    yaml_files+=("$file")
  done < <(find templates/.agent examples -type f -name "*.yml" -print0)

  if [ "${#yaml_files[@]}" -eq 0 ]; then
    echo "ERROR: no YAML files found for validation"
    exit 1
  fi

  ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }' "${yaml_files[@]}"
}

run_json_syntax_checks() {
  local json_files=()
  local file

  while IFS= read -r -d '' file; do
    json_files+=("$file")
  done < <(find schemas -type f -name "*.json" -print0)

  if [ "${#json_files[@]}" -eq 0 ]; then
    echo "ERROR: no JSON schema files found for validation"
    exit 1
  fi

  ruby -rjson -e 'ARGV.each { |f| JSON.parse(File.read(f)) }' "${json_files[@]}"
}

run_shell_header_checks() {
  local file
  local first_line
  local second_line

  while IFS= read -r file; do
    first_line="$(sed -n '1p' "$file")"
    second_line="$(sed -n '2p' "$file")"

    if [ "$first_line" != "#!/usr/bin/env bash" ]; then
      echo "ERROR: missing bash shebang in $file"
      exit 1
    fi

    if [ "$second_line" != "set -euo pipefail" ]; then
      echo "ERROR: missing set -euo pipefail in $file"
      exit 1
    fi
  done < <(find . -type f -name "*.sh" -not -path "./.git/*" | sort)
}

echo "== Validate Agent-Repo-Harness =="

cd "$repo_root"

echo
echo "== Shell syntax =="
bash -n install-agent-harness.sh
bash -n validate-harness.sh
bash -n templates/scripts/agent-finish.sh
for f in templates/scripts/*.sh; do
  bash -n "$f"
done
for f in examples/universal-minimal-repo/scripts/*.sh; do
  bash -n "$f"
done
run_shell_header_checks
pass "shell syntax checks"

echo
echo "== YAML syntax =="
if command -v ruby >/dev/null 2>&1; then
  run_yaml_syntax_checks
  pass "YAML syntax checks"
else
  echo "WARN: ruby unavailable; skipped YAML syntax checks"
fi

echo
echo "== JSON syntax =="
if command -v ruby >/dev/null 2>&1; then
  run_json_syntax_checks
  pass "JSON schema syntax checks"
else
  echo "WARN: ruby unavailable; skipped JSON syntax checks"
fi

echo
echo "== Required repository files =="
for required_path in \
  templates/AGENTS.md \
  templates/CLAUDE.md \
  adapters/codex/AGENTS.md \
  adapters/codex/codex-start-prompt.md \
  adapters/claude-code/CLAUDE.md \
  adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md \
  adapters/claude-code/.claude/skills/policy-gate/SKILL.md \
  adapters/claude-code/.claude/skills/verification-gate/SKILL.md \
  adapters/claude-code/.claude/skills/handoff-update/SKILL.md \
  adapters/claude-code/.claude/skills/subagent-context-packet/SKILL.md \
  docs/agent-support-matrix.md \
  docs/codex-usage.md \
  schemas/harness.schema.json \
  schemas/policy.schema.json \
  schemas/task.schema.json \
  schemas/handoff.schema.json \
  templates/scripts/validate-config.sh \
  templates/scripts/validate-task.sh \
  examples/universal-minimal-repo/AGENTS.md \
  examples/universal-minimal-repo/CLAUDE.md \
  examples/universal-minimal-repo/.agent/harness.yml \
  examples/universal-minimal-repo/.agent/policy.yml \
  examples/universal-minimal-repo/.agent/task.yml
do
  assert_exists "$repo_root/$required_path"
done
pass "new universal harness files present"

echo
echo "== Fresh install target =="
mkdir -p "$target_root"
git init -q "$target_root"

dry_run_log="$tmp_root/install-dry-run.log"
bash install-agent-harness.sh --dry-run "$target_root" >"$dry_run_log" 2>&1
assert_contains "$dry_run_log" "DRY-RUN copy:"
assert_contains "$dry_run_log" "Install complete."
pass "installer dry run"

bash install-agent-harness.sh "$target_root"
pass "installer copy"

echo
echo "== Installed target checks =="
for required_path in \
  AGENTS.md \
  CLAUDE.md \
  agent.md \
  handoff.md \
  .agent/harness.yml \
  .agent/policy.yml \
  .agent/task.yml \
  scripts/agent-preflight.sh \
  scripts/agent-finish.sh \
  scripts/check-agent-md.sh \
  scripts/check-policy.sh \
  scripts/check-scope.sh \
  scripts/agent-verify.sh \
  scripts/validate-config.sh \
  scripts/validate-task.sh
do
  assert_exists "$target_root/$required_path"
done
pass "required files installed"

(
  cd "$target_root"
  bash scripts/agent-preflight.sh
  bash scripts/validate-config.sh
  bash scripts/validate-task.sh
  bash scripts/check-agent-md.sh agent.md
  verify_log="$target_root/agent-verify-pass.log"
  bash scripts/agent-verify.sh --best-effort >"$verify_log" 2>&1
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
  assert_contains "$verify_log" "Verification passed."
  finish_log="$target_root/agent-finish-pass.log"
  bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=pass"
  assert_contains "$finish_log" "Agent finish gates passed."
  assert_contains "$finish_log" "Summary: .agent/runs/"
  finish_summary_count="$(find "$target_root/.agent/runs" -type f -name "finish-summary.md" | wc -l | tr -d '[:space:]')"
  if [ "$finish_summary_count" -lt 1 ]; then
    echo "ERROR: expected agent-finish.sh to create finish-summary.md"
    exit 1
  fi
  assert_run_evidence_files "$target_root"
  assert_file_contains "$target_root" "finish-summary.md" "Overall result: pass"
  assert_file_contains "$target_root" "finish-summary.md" "Run directory: .agent/runs/"
  assert_file_contains "$target_root" "finish-summary.md" "check-agent-md-result.txt"
  assert_file_contains "$target_root" "finish-summary.md" "scope-result.txt"
  assert_file_contains "$target_root" "check-agent-md-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "scope-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "policy-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "verify-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "changed-files.txt" "agent-finish-pass.log"
  assert_file_contains "$target_root" "git-diff-stat.txt" "# Git diff stat"
  bash scripts/check-policy.sh .agent/policy.yml
  bash scripts/collect-context.sh >/dev/null
  assert_exists "$target_root/.agent/task.yml"
  assert_exists "$target_root/scripts/check-scope.sh"
  scope_log="$target_root/check-scope-fresh-install.log"
  bash scripts/check-scope.sh >"$scope_log" 2>&1
  assert_contains "$scope_log" "Scope check passed."
)
pass "installed script smoke checks"

echo
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
pass "strict policy semantics"

echo
echo "== Repo-defined verification commands =="
mkdir -p "$verify_config_root/.agent"
git init -q "$verify_config_root"
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
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
)
pass "repo-defined verification commands"

echo
echo "== Finish gate strict scope failure =="
rm -rf "$finish_strict_root"
mkdir -p "$finish_strict_root/.agent" "$finish_strict_root/scripts" "$finish_strict_root/src/billing"
git init -q "$finish_strict_root"
(
  cd "$finish_strict_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  forbidden_paths:' \
    '    - "src/billing/**"' \
    > .agent/task.yml
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent/task.yml .agent/policy.yml scripts
  git commit -q -m "Add harness files"
  printf '%s\n' 'line one' > src/billing/invoice.js
  finish_log="$finish_strict_root/agent-finish-strict-failure.log"
  if bash scripts/agent-finish.sh --strict >"$finish_log" 2>&1; then
    echo "ERROR: expected finish gate strict failure"
    exit 1
  fi
  assert_contains "$finish_log" "Scope check failed."
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=fail"
  finish_summary_count="$(find "$finish_strict_root/.agent/runs" -type f -name "finish-summary.md" | wc -l | tr -d '[:space:]')"
  if [ "$finish_summary_count" -lt 1 ]; then
    echo "ERROR: expected failing finish gate to create finish-summary.md"
    exit 1
  fi
  assert_contains "$finish_log" "Run directory: .agent/runs/"
  assert_run_evidence_files "$finish_strict_root"
  assert_file_contains "$finish_strict_root" "finish-summary.md" "Overall result: fail"
  assert_file_contains "$finish_strict_root" "finish-summary.md" "check-scope"
  assert_file_contains "$finish_strict_root" "finish-summary.md" "check-agent-md-result.txt"
  assert_file_contains "$finish_strict_root" "check-agent-md-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "scope-result.txt" "Exit status: 1"
  assert_file_contains "$finish_strict_root" "policy-result.txt" "Exit status: 0"
  assert_file_contains "$finish_strict_root" "verify-result.txt" "Exit status: 0"
)
pass "finish gate strict scope failure"

echo
echo "== Finish gate without git repository =="
rm -rf "$finish_nongit_root"
mkdir -p "$finish_nongit_root/.agent" "$finish_nongit_root/scripts"
(
  cd "$finish_nongit_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  chmod +x scripts/*.sh
  finish_log="$finish_nongit_root/agent-finish-nongit.log"
  bash scripts/agent-finish.sh --best-effort >"$finish_log" 2>&1
  assert_contains "$finish_log" "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$finish_nongit_root" "changed-files.txt" "Not inside a git repository"
  assert_file_contains "$finish_nongit_root" "git-diff-stat.txt" "Not inside a git repository"
)
pass "finish gate without git repository"

echo
echo "== Universal minimal example smoke =="
example_root="$tmp_root/universal-minimal-repo"
cp -R examples/universal-minimal-repo "$example_root"
(
  cd "$example_root"
  bash scripts/agent-preflight.sh
  bash scripts/validate-config.sh
  bash scripts/validate-task.sh
  bash scripts/check-policy.sh
  bash scripts/check-scope.sh
  bash scripts/agent-verify.sh
  example_finish_log="$tmp_root/universal-minimal-finish.log"
  bash scripts/agent-finish.sh >"$example_finish_log" 2>&1
  assert_contains "$example_finish_log" "AGENT_FINISH_RESULT=pass"
  assert_contains "$example_finish_log" "Summary: .agent/runs/"
)
pass "universal minimal example smoke"

echo
echo "PASS: validation completed"
