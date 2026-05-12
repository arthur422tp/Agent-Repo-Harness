#!/usr/bin/env bash
set -euo pipefail

echo "== Validate Agent-Repo-Harness =="

cd "$repo_root"

echo
echo "== Shell syntax =="
run_shell_format_checks
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
  docs/config-format.md \
  docs/codex-usage.md \
  docs/superpowers-integration.md \
  schemas/harness.schema.json \
  schemas/policy.schema.json \
  schemas/task.schema.json \
  schemas/handoff.schema.json \
  schemas/acceptance.schema.json \
  schemas/review.schema.json \
  templates/scripts/validate-config.sh \
  templates/scripts/validate-task.sh \
  templates/scripts/lib/read-yaml.py \
  templates/scripts/check-doc-links.sh \
  templates/scripts/check-tdd-evidence.sh \
  templates/scripts/check-acceptance.sh \
  templates/scripts/check-review-evidence.sh \
  templates/.agent/tdd-evidence.yml \
  templates/.agent/acceptance.yml \
  templates/.agent/review.yml \
  templates/scripts/validate-subagent-packet.sh \
  templates/.agent/subagent-packet.yml \
  templates/.agent/subagent-runs/README.md \
  templates/.agent/subagent-runs/.gitkeep \
  templates/docs/agent/subagent-result-template.md \
  templates/docs/agent/review.md \
  templates/scripts/validate-subagent-run.sh \
  tests/fixtures/validate-harness/broken-doc-links.md \
  tests/fixtures/validate-harness/subagent-packet-valid.yml \
  tests/fixtures/validate-harness/task-invalid-types.yml \
  tests/fixtures/validate-harness/task-root-status.yml \
  tests/fixtures/validate-harness/tdd-evidence-complete.yml \
  tests/fixtures/validate-harness/verification-required-bad.yml \
  tests/fixtures/validate-harness/verification-required-multiline.yml \
  tests/fixtures/validate-harness/verification-required.yml \
  tests/fixtures/validate-harness/yaml-reader-harness.yml \
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
echo "== Repository doc links =="
bash templates/scripts/check-doc-links.sh "$repo_root"
pass "repository doc links"

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
  .agent/acceptance.yml \
  .agent/review.yml \
  .agent/tdd-evidence.yml \
  .agent/subagent-packet.yml \
  .agent/subagent-runs/README.md \
  .agent/subagent-runs/.gitkeep \
  docs/agent/subagent-result-template.md \
  docs/agent/review.md \
  scripts/agent-preflight.sh \
  scripts/agent-finish.sh \
  scripts/check-agent-md.sh \
  scripts/check-policy.sh \
  scripts/check-scope.sh \
  scripts/check-tdd-evidence.sh \
  scripts/check-acceptance.sh \
  scripts/check-review-evidence.sh \
  scripts/agent-verify.sh \
  scripts/lib/read-yaml.py \
  scripts/check-doc-links.sh \
  scripts/validate-config.sh \
  scripts/validate-task.sh \
  scripts/validate-subagent-packet.sh \
  scripts/validate-subagent-run.sh
do
  assert_exists "$target_root/$required_path"
done
pass "required files installed"

assert_contains "$target_root/AGENTS.md" "## Context Loading Policy"
assert_contains "$target_root/AGENTS.md" "Start compact: read summaries and task boundaries before raw source."
assert_contains "$target_root/AGENTS.md" "Expand only for files directly relevant to the current task."
assert_contains "$target_root/CLAUDE.md" "## Context Loading Policy"
assert_contains "$target_root/CLAUDE.md" "Start compact: read summaries and task boundaries before raw source."
assert_contains "$target_root/CLAUDE.md" "Expand only for files directly relevant to the current task."
assert_contains "$target_root/agent.md" "## Context Loading"
assert_contains "$target_root/agent.md" "Keep this file compact enough to read at task start."
assert_contains "$repo_root/skills/repo-context-bootstrap/SKILL.md" "Build compact context before broad source inspection."

(
  cd "$target_root"
  preflight_log="$target_root/agent-preflight.log"
  bash scripts/agent-preflight.sh >"$preflight_log" 2>&1
  assert_contains "$preflight_log" "== Dependencies =="
  assert_contains "$preflight_log" "OK: python"
  bash scripts/validate-config.sh
  bash scripts/validate-task.sh
  bash scripts/check-doc-links.sh
  subagent_empty_log="$target_root/subagent-packet-empty.log"
  if bash scripts/validate-subagent-packet.sh >"$subagent_empty_log" 2>&1; then
    echo "ERROR: expected empty subagent packet validation failure"
    exit 1
  fi
  assert_contains "$subagent_empty_log" "SUBAGENT_PACKET_RESULT=fail"
  assert_contains "$subagent_empty_log" "task_id must be non-empty"
  copy_fixture subagent-packet-valid.yml .agent/subagent-packet.yml
  bash scripts/validate-subagent-packet.sh
  subagent_invalid_role_log="$target_root/subagent-packet-invalid-role.log"
  sed -e 's/role: "implementer"/role: "invalid_role"/' \
    .agent/subagent-packet.yml > .agent/subagent-packet-invalid-role.yml
  if bash scripts/validate-subagent-packet.sh \
    .agent/subagent-packet-invalid-role.yml >"$subagent_invalid_role_log" 2>&1
  then
    echo "ERROR: expected invalid role validation failure"
    exit 1
  fi
  assert_contains "$subagent_invalid_role_log" "role must be one of"
  assert_contains "$subagent_invalid_role_log" "SUBAGENT_PACKET_RESULT=fail"
  subagent_run_missing_arg_log="$target_root/subagent-run-missing-arg.log"
  if bash scripts/validate-subagent-run.sh >"$subagent_run_missing_arg_log" 2>&1; then
    echo "ERROR: expected missing subagent run argument validation failure"
    exit 1
  fi
  assert_contains "$subagent_run_missing_arg_log" "Usage: validate-subagent-run.sh RUN_DIR"
  assert_contains "$subagent_run_missing_arg_log" "SUBAGENT_RUN_RESULT=fail"
  subagent_run_missing_dir_log="$target_root/subagent-run-missing-dir.log"
  if bash scripts/validate-subagent-run.sh \
    .agent/subagent-runs/missing >"$subagent_run_missing_dir_log" 2>&1
  then
    echo "ERROR: expected missing subagent run directory validation failure"
    exit 1
  fi
  assert_contains "$subagent_run_missing_dir_log" "run directory does not exist"
  assert_contains "$subagent_run_missing_dir_log" "SUBAGENT_RUN_RESULT=fail"
  mkdir -p .agent/subagent-runs/invalid-status
  cp .agent/subagent-packet.yml .agent/subagent-runs/invalid-status/packet.yml
  printf '%s\n' "# Result" > .agent/subagent-runs/invalid-status/result.md
  printf '%s\n' "INVALID" > .agent/subagent-runs/invalid-status/status.txt
  subagent_run_invalid_status_log="$target_root/subagent-run-invalid-status.log"
  if bash scripts/validate-subagent-run.sh \
    .agent/subagent-runs/invalid-status >"$subagent_run_invalid_status_log" 2>&1
  then
    echo "ERROR: expected invalid subagent run status validation failure"
    exit 1
  fi
  assert_contains "$subagent_run_invalid_status_log" "status.txt must contain exactly one of"
  assert_contains "$subagent_run_invalid_status_log" "SUBAGENT_RUN_RESULT=fail"
  mkdir -p .agent/subagent-runs/20260502-120000-implementer-phase-1-4
  cp .agent/subagent-packet.yml \
    .agent/subagent-runs/20260502-120000-implementer-phase-1-4/packet.yml
  printf '%s\n' "# Subagent Result" \
    > .agent/subagent-runs/20260502-120000-implementer-phase-1-4/result.md
  printf '%s\n' "DONE" \
    > .agent/subagent-runs/20260502-120000-implementer-phase-1-4/status.txt
  subagent_run_valid_log="$target_root/subagent-run-valid.log"
  bash scripts/validate-subagent-run.sh \
    .agent/subagent-runs/20260502-120000-implementer-phase-1-4 \
    >"$subagent_run_valid_log" 2>&1
  assert_contains "$subagent_run_valid_log" "SUBAGENT_RUN_RESULT=pass"
  bash scripts/check-agent-md.sh agent.md
  verify_log="$target_root/agent-verify-pass.log"
  bash scripts/agent-verify.sh --best-effort >"$verify_log" 2>&1
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
  assert_contains "$verify_log" "Verification passed."
  copy_fixture tdd-evidence-complete.yml .agent/tdd-evidence.yml
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
  assert_finish_summary_contract "$target_root" "pass"
  assert_contains "$finish_log" "Run directory: .agent/runs/"
  assert_file_contains "$target_root" "check-agent-md-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "check-agent-md-result.txt" "Output:"
  assert_file_contains "$target_root" "scope-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "scope-result.txt" "Output:"
  assert_file_contains "$target_root" "policy-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "policy-result.txt" "Output:"
  assert_file_contains "$target_root" "tdd-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "tdd-evidence-result.txt" "Output:"
  assert_file_contains "$target_root" "acceptance-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "acceptance-result.txt" "Acceptance check is not required."
  assert_file_contains "$target_root" "review-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "review-result.txt" "Review evidence is not required."
  assert_file_contains "$target_root" "verify-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "verify-result.txt" "Output:"
  assert_file_contains "$target_root" "changed-files.txt" "AGENTS.md"
  assert_file_not_contains "$target_root" "changed-files.txt" ".agent/runs/"
  assert_file_not_contains "$target_root" "changed-files.txt" "agent-finish-pass.log"
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
