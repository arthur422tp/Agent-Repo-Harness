#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  task_profile_repo_root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
  export PYTHONDONTWRITEBYTECODE=1
  # shellcheck source=tests/harness/lib.sh
  source "$task_profile_repo_root/tests/harness/lib.sh"
  repo_root="$task_profile_repo_root"
  fixture_root="$repo_root/tests/fixtures/validate-harness"
fi

setup_profile_root() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/.agent" "$root/scripts/lib" "$root/scripts"
  cp "$repo_root/templates/scripts/agent-task-profile.sh" "$root/scripts/agent-task-profile.sh"
  cp "$repo_root/templates/scripts/validate-task.sh" "$root/scripts/validate-task.sh"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" "$root/scripts/lib/read-yaml.py"
  chmod +x "$root/scripts"/*.sh
}

echo "== Minimal task profile =="
setup_profile_root "$task_profile_minimal_root"
(
  cd "$task_profile_minimal_root"
  bash scripts/agent-task-profile.sh minimal \
    --goal "Update docs." \
    --current-task "Clarify README." \
    --allowed "README.md" \
    --forbidden "schemas/**" > profile.log 2>&1
  assert_contains profile.log "AGENT_TASK_PROFILE_RESULT=pass"
  assert_contains .agent/task.yml 'goal: "Update docs."'
  assert_contains .agent/task.yml "requires_tdd_evidence: false"
  assert_contains .agent/task.yml "requires_acceptance_check: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "minimal task profile"

echo
echo "== Standard task profile =="
setup_profile_root "$task_profile_standard_root"
(
  cd "$task_profile_standard_root"
  bash scripts/agent-task-profile.sh standard \
    --goal "Add behavior." \
    --current-task "Implement helper." \
    --allowed "templates/scripts/**" \
    --allowed "tests/harness/**" > profile.log 2>&1
  assert_contains .agent/task.yml "requires_tdd_evidence: true"
  assert_contains .agent/task.yml "requires_acceptance_check: true"
  assert_contains .agent/task.yml "requires_review_evidence: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "standard task profile"

echo
echo "== Task profile selects verification stage =="
task_profile_verification_root="$tmp_root/task-profile-verification"
setup_profile_root "$task_profile_verification_root"
(
  cd "$task_profile_verification_root"
  bash scripts/agent-task-profile.sh standard \
    --goal "Build package baseline." \
    --current-task "Create package import." \
    --verification-profile bootstrap \
    --allowed "src/**" > profile.log 2>&1
  assert_contains .agent/task.yml 'verification_profile: "bootstrap"'
  assert_contains profile.log "Verification profile: bootstrap"
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  bash scripts/validate-task.sh .agent/task.yml .agent/harness.yml > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "task profile selects verification stage"

echo
echo "== High-risk selected gates =="
setup_profile_root "$task_profile_high_risk_root"
(
  cd "$task_profile_high_risk_root"
  bash scripts/agent-task-profile.sh high-risk \
    --goal "Change protected workflow." \
    --current-task "Update policy path." \
    --allowed ".agent/policy.yml" \
    --architecture \
    --review \
    --command-ledger > profile.log 2>&1
  assert_contains .agent/task.yml "requires_tdd_evidence: true"
  assert_contains .agent/task.yml "requires_acceptance_check: true"
  assert_contains .agent/task.yml "requires_review_evidence: true"
  assert_contains .agent/task.yml "requires_architecture_evidence: true"
  assert_contains .agent/task.yml "requires_command_ledger: true"
  assert_contains .agent/task.yml "requires_sandbox_verification: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "high-risk selected gates"

echo
echo "== Dry-run does not write =="
setup_profile_root "$task_profile_dry_run_root"
(
  cd "$task_profile_dry_run_root"
  bash scripts/agent-task-profile.sh minimal --goal "Preview only." --allowed "README.md" --dry-run > dry-run.log 2>&1
  assert_contains dry-run.log "task:"
  assert_contains dry-run.log "AGENT_TASK_PROFILE_RESULT=pass"
  if [ -f .agent/task.yml ]; then
    echo "ERROR: dry-run wrote .agent/task.yml"
    exit 1
  fi
)
pass "dry-run does not write"

echo
echo "== Existing task profile rewrite warns =="
task_profile_rewrite_root="$tmp_root/task-profile-rewrite"
setup_profile_root "$task_profile_rewrite_root"
(
  cd "$task_profile_rewrite_root"
  printf '%s\n' 'task:' '  custom_field: "preserve manually if needed"' > .agent/task.yml
  bash scripts/agent-task-profile.sh standard \
    --goal "Regenerate task." \
    --current-task "Use generated profile." \
    --allowed "templates/scripts/**" > rewrite.log 2>&1
  assert_contains rewrite.log "WARN: rewriting existing task file: .agent/task.yml"
  assert_contains rewrite.log "AGENT_TASK_PROFILE_RESULT=pass"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "existing task profile rewrite warns"

echo
echo "== Invalid profile fails =="
setup_profile_root "$task_profile_invalid_root"
(
  cd "$task_profile_invalid_root"
  if bash scripts/agent-task-profile.sh risky --goal "Bad profile." > invalid.log 2>&1; then
    echo "ERROR: expected invalid profile failure"
    exit 1
  fi
  assert_contains invalid.log "ERROR: unsupported profile: risky"
)
pass "invalid profile fails"
