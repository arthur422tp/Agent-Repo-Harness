#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  lifecycle_repo_root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
  export PYTHONDONTWRITEBYTECODE=1
  # shellcheck source=tests/harness/lib.sh
  source "$lifecycle_repo_root/tests/harness/lib.sh"
fi

echo
echo "== Bootstrap verification profile finish lifecycle =="
rm -rf "$verification_lifecycle_root"
mkdir -p "$verification_lifecycle_root"
git init -q "$verification_lifecycle_root"
(
  cd "$verification_lifecycle_root"
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf '%s\n' "# Verification Lifecycle Fixture" > README.md
  git add README.md
  git commit -q -m "Initialize fixture"

  install_log="$tmp_root/verification-lifecycle-install.log"
  first_finish_log="$tmp_root/verification-lifecycle-first-finish.log"
  second_finish_log="$tmp_root/verification-lifecycle-second-finish.log"
  bash "$repo_root/install-agent-harness.sh" --force \
    "$verification_lifecycle_root" > "$install_log" 2>&1
  printf '%s\n' \
    '# Agent Map' \
    '' \
    '## Project Overview' \
    'Exercise staged verification.' \
    '' \
    '## Architecture Map' \
    '- src/: package source' \
    '- scripts/: harness scripts' \
    '' \
    '## Common Commands' \
    '- bash scripts/agent-finish.sh --best-effort' \
    '' \
    '## Verification' \
    '- bootstrap profile only' \
    '' \
    '## Risk Areas' \
    '- staged verification drift' \
    '' \
    '## Agent Rules' \
    '- keep runtime evidence untracked' \
    > agent.md
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  printf '%s\n' \
    'task:' \
    '  status: "in_progress"' \
    '  goal: "Create the package baseline"' \
    '  current_task: "Task 1: package baseline"' \
    '  verification_profile: "bootstrap"' \
    '  allowed_paths:' \
    '    - "src/**"' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_scope_check: true' \
    '    requires_policy_check: true' \
    '    requires_verification: true' \
    '    expects_handoff_update: true' \
    '    requires_tdd_evidence: false' \
    '    requires_acceptance_check: false' \
    '    requires_review_evidence: false' \
    '    requires_architecture_evidence: false' \
    '    requires_failure_attribution: false' \
    '    requires_intervention_record: false' \
    '    requires_sandbox_verification: false' \
    '    requires_command_ledger: false' \
    '    requires_subagent_evidence: false' \
    > .agent/task.yml
  git add AGENTS.md CLAUDE.md agent.md handoff.md .agent docs scripts schemas .gitignore
  git commit -q -m "Install staged verification harness"

  mkdir -p src/ops_rulekit
  printf '%s\n' '__version__ = "0.1.0"' > src/ops_rulekit/__init__.py

  bash scripts/agent-finish.sh --best-effort > "$first_finish_log" 2>&1
  assert_contains "$first_finish_log" "Selected verification profile: bootstrap"
  assert_contains "$first_finish_log" "BOOTSTRAP_PROFILE_RAN"
  assert_not_contains "$first_finish_log" "DEFAULT_SUITE_RAN"
  assert_not_contains "$first_finish_log" "pytest"
  assert_not_contains "$first_finish_log" "ruff check ."
  assert_contains "$first_finish_log" "AGENT_FINISH_RESULT=pass"

  bash scripts/agent-finish.sh --best-effort > "$second_finish_log" 2>&1
  assert_contains "$second_finish_log" "AGENT_FINISH_RESULT=pass"
  assert_contains "$second_finish_log" "Scope check passed."

  run_count="$(find .agent/runs -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
  if [ "$run_count" -lt 2 ]; then
    echo "ERROR: expected two finish evidence directories, got $run_count"
    exit 1
  fi
)
pass "bootstrap verification profile finish lifecycle"
