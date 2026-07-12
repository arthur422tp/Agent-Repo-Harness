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
  docs/agent-support-matrix.md \
  docs/config-format.md \
  docs/codex-usage.md \
  docs/agent/gate-guide.md \
  docs/agent/architecture-sensors.md \
  docs/handoff.md \
  docs/superpowers-integration.md \
  schemas/harness.schema.json \
  schemas/policy.schema.json \
  schemas/task.schema.json \
  schemas/handoff.schema.json \
  schemas/acceptance.schema.json \
  schemas/evidence-ref.schema.json \
  schemas/review.schema.json \
  schemas/architecture.schema.json \
  schemas/episode.schema.json \
  schemas/failure-attribution.schema.json \
  schemas/interventions.schema.json \
  templates/scripts/validate-config.sh \
  templates/scripts/validate-task.sh \
  templates/scripts/validate-episode.sh \
  templates/scripts/agent-audit.sh \
  templates/scripts/agent-task-profile.sh \
  templates/scripts/lib/read-yaml.py \
  templates/scripts/lib/policy-approval.sh \
  templates/scripts/check-doc-links.sh \
  templates/scripts/check-tdd-evidence.sh \
  templates/scripts/validate-handoff.sh \
  templates/scripts/agent-evidence-bind.sh \
  templates/scripts/check-acceptance.sh \
  templates/scripts/check-evidence-refs.py \
  templates/scripts/check-review-evidence.sh \
  templates/scripts/check-architecture-evidence.sh \
  templates/scripts/check-command-ledger.sh \
  templates/scripts/check-failure-attribution.sh \
  templates/scripts/check-interventions.sh \
  templates/scripts/check-sandbox-evidence.sh \
  templates/scripts/check-subagent-evidence.sh \
  templates/.agent/handoff.yml \
  templates/.agent/tdd-evidence.yml \
  templates/.agent/approvals/high-risk-approved.yml \
  templates/.agent/acceptance.yml \
  templates/.agent/review.yml \
  templates/.agent/architecture.yml \
  templates/.agent/episode.yml \
  templates/.agent/failure-attribution.yml \
  templates/.agent/interventions.yml \
  templates/scripts/validate-subagent-packet.sh \
  templates/.agent/subagent-packet.yml \
  templates/.agent/subagent-runs/README.md \
  templates/.agent/subagent-runs/.gitkeep \
  templates/docs/agent/context-loading.md \
  templates/docs/agent/policy-approval.md \
  templates/docs/agent/subagent-result-template.md \
  templates/docs/agent/review.md \
  templates/docs/agent/episode-package.md \
  templates/docs/agent/failure-attribution.md \
  templates/docs/agent/interventions.md \
  templates/docs/agent/entropy-audit.md \
  templates/docs/agent/architecture-sensors.md \
  templates/scripts/check-import-boundaries.py \
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
  examples/strict-tdd-task.yml \
  examples/rag-contract-system/pyproject.toml \
  examples/rag-contract-system/src/contract_rag/cli.py \
  examples/rag-contract-system/evals/cases.json \
  examples/rag-contract-system/tests/test_chunker.py \
  examples/rag-contract-system/tests/test_retriever.py \
  examples/rag-contract-system/tests/test_pipeline.py \
  examples/rag-contract-system/tests/test_security.py \
  examples/rag-contract-system/tests/test_evals.py \
  examples/rag-contract-system/adoption/minimal-task.yml \
  examples/rag-contract-system/adoption/standard-task.yml \
  examples/rag-contract-system/adoption/high-risk-task.yml \
  examples/rag-contract-system/adoption/scenarios.md \
  examples/rag-contract-system/adoption/report.md \
  examples/universal-minimal-repo/AGENTS.md \
  examples/universal-minimal-repo/CLAUDE.md \
  examples/universal-minimal-repo/.agent/harness.yml \
  examples/universal-minimal-repo/.agent/policy.yml \
  examples/universal-minimal-repo/.agent/task.yml \
  examples/universal-minimal-repo/.agent/architecture.yml \
  examples/universal-minimal-repo/scripts/agent-sandbox-run.sh \
  examples/universal-minimal-repo/scripts/check-sandbox-evidence.sh
do
  assert_exists "$repo_root/$required_path"
done
pass "new universal harness files present"

assert_installer_completion_block() {
  local log_file="$1"
  local target_path="$2"
  local expected_block
  local actual_block

  expected_block=$(cat <<EOF
Install complete.

Next:
1. cd $(printf '%q' "$target_path")
2. Review .agent/task.yml and adjust the task goal/scope.
3. Run bash scripts/agent-finish.sh --best-effort.
Advanced gates, policy approval, adapters, and subagent workflows are documented in README.md and docs/.
EOF
)

  actual_block="$(awk 'found {print} /^Install complete\.$/{found=1; print}' "$log_file")"

  if [ "$actual_block" != "$expected_block" ]; then
    echo "ERROR: installer completion block mismatch"
    echo "--- expected ---"
    printf '%s\n' "$expected_block"
    echo "--- actual ---"
    printf '%s\n' "$actual_block"
    echo "--- full log ---"
    cat "$log_file"
    return 1
  fi

  if grep -Fq "Next steps:" "$log_file"; then
    echo "ERROR: old installer completion trailer was present"
    echo "--- full log ---"
    cat "$log_file"
    return 1
  fi
}

write_public_schema_basenames() {
  local schema_dir="$1"
  local output_file="$2"

  find "$schema_dir" \
    -type f \
    -name "*.schema.json" \
    ! -path "$schema_dir/*/*" \
    -exec basename {} \; | LC_ALL=C sort >"$output_file"
}

assert_schema_sets_equal() {
  local expected_file="$1"
  local actual_file="$2"

  if ! cmp -s "$expected_file" "$actual_file"; then
    echo "ERROR: installed public schema set does not match source"
    diff -u "$expected_file" "$actual_file" || true
    exit 1
  fi
}

echo
echo "== Fresh install target =="
target_root="$tmp_root/install target"
mkdir -p "$target_root"
git init -q "$target_root"
printf '%s\n' 'dist/' > "$target_root/.gitignore"

dry_run_log="$tmp_root/install-dry-run.log"
source_schema_names="$tmp_root/source-schema-names.txt"
write_public_schema_basenames "$repo_root/schemas" "$source_schema_names"
bash install-agent-harness.sh --dry-run "$target_root" >"$dry_run_log" 2>&1
assert_contains "$dry_run_log" "DRY-RUN copy:"
assert_installer_completion_block "$dry_run_log" "$target_root"
while IFS= read -r schema_name; do
  assert_contains "$dry_run_log" \
    "DRY-RUN copy: $repo_root/schemas/$schema_name -> $target_root/schemas/$schema_name"
  assert_not_exists "$target_root/schemas/$schema_name"
done <"$source_schema_names"
pass "installer dry run"

install_log="$tmp_root/install.log"
if ! bash install-agent-harness.sh "$target_root" >"$install_log" 2>&1; then
  echo "ERROR: installer copy failed"
  echo "--- full log ---"
  cat "$install_log"
  exit 1
fi
assert_installer_completion_block "$install_log" "$target_root"
pass "installer copy"
assert_contains "$target_root/.gitignore" "dist/"
assert_contains "$target_root/.gitignore" ".agent/runs/"
assert_contains "$target_root/.gitignore" ".agent/audits/"
assert_contains "$target_root/.gitignore" ".agent/command-runs/"
assert_contains "$target_root/.gitignore" ".agent/sandbox-runs/"

installed_schema_names="$tmp_root/installed-schema-names.txt"
write_public_schema_basenames \
  "$target_root/schemas" \
  "$installed_schema_names"
assert_schema_sets_equal "$source_schema_names" "$installed_schema_names"

schema_count="$(wc -l <"$installed_schema_names" | tr -d ' ')"
if [ "$schema_count" -ne 11 ]; then
  echo "ERROR: expected 11 current public schemas, got $schema_count"
  exit 1
fi
pass "fresh install public schema set matches source"

bash "$repo_root/install-agent-harness.sh" "$target_root" >"$tmp_root/reinstall.log" 2>&1
for entry in \
  ".agent/runs/" \
  ".agent/audits/" \
  ".agent/command-runs/" \
  ".agent/sandbox-runs/"
do
  count="$(grep -Fxc -- "$entry" "$target_root/.gitignore" || true)"
  if [ "$count" -ne 1 ]; then
    echo "ERROR: expected one .gitignore entry for $entry, got $count"
    exit 1
  fi
done

echo
echo "== Installed target checks =="
assert_exists "$target_root/scripts/lib/harness-common.sh"
assert_exists "$target_root/scripts/lib/finish-summary.sh"
assert_exists "$target_root/scripts/lib/gate-registry.sh"
assert_exists "$target_root/scripts/lib/finish-runner.sh"
pass "installed runtime libraries are present"
for required_path in \
  AGENTS.md \
  CLAUDE.md \
  agent.md \
  handoff.md \
  .agent/harness.yml \
  .agent/policy.yml \
  .agent/task.yml \
  .agent/handoff.yml \
  .agent/acceptance.yml \
  .agent/review.yml \
  .agent/architecture.yml \
  .agent/episode.yml \
  .agent/tdd-evidence.yml \
  .agent/interventions.yml \
  .agent/approvals/high-risk-approved.yml \
  .agent/subagent-packet.yml \
  .agent/subagent-runs/README.md \
  .agent/subagent-runs/.gitkeep \
  docs/agent/context-loading.md \
  docs/agent/gate-guide.md \
  docs/agent/policy-approval.md \
  docs/agent/subagent-result-template.md \
  docs/agent/review.md \
  docs/agent/episode-package.md \
  docs/agent/failure-attribution.md \
  docs/agent/interventions.md \
  docs/agent/entropy-audit.md \
  docs/agent/architecture-sensors.md \
  scripts/agent-preflight.sh \
  scripts/agent-finish.sh \
  scripts/agent-run.sh \
  scripts/agent-evidence-bind.sh \
  scripts/agent-task-profile.sh \
  scripts/agent-sandbox-run.sh \
  scripts/check-agent-md.sh \
  scripts/check-policy.sh \
  scripts/check-scope.sh \
  scripts/check-tdd-evidence.sh \
  scripts/check-acceptance.sh \
  scripts/check-evidence-refs.py \
  scripts/check-review-evidence.sh \
  scripts/check-architecture-evidence.sh \
  scripts/check-command-ledger.sh \
  scripts/check-failure-attribution.sh \
  scripts/check-interventions.sh \
  scripts/check-sandbox-evidence.sh \
  scripts/check-subagent-evidence.sh \
  scripts/check-import-boundaries.py \
  scripts/validate-episode.sh \
  scripts/agent-audit.sh \
  scripts/agent-verify.sh \
  scripts/lib/harness-common.sh \
  scripts/lib/finish-summary.sh \
  scripts/lib/gate-registry.sh \
  scripts/lib/finish-runner.sh \
  scripts/lib/read-yaml.py \
  scripts/lib/policy-approval.sh \
  scripts/check-doc-links.sh \
  scripts/validate-config.sh \
  scripts/validate-task.sh \
  scripts/validate-handoff.sh \
  scripts/validate-subagent-packet.sh \
  scripts/validate-subagent-run.sh \
  schemas/acceptance.schema.json \
  schemas/architecture.schema.json \
  schemas/episode.schema.json \
  schemas/evidence-ref.schema.json \
  schemas/failure-attribution.schema.json \
  schemas/handoff.schema.json \
  schemas/harness.schema.json \
  schemas/interventions.schema.json \
  schemas/policy.schema.json \
  schemas/review.schema.json \
  schemas/task.schema.json
do
  assert_exists "$target_root/$required_path"
done
pass "required files installed"

assert_contains "$target_root/.agent/task.yml" 'requires_tdd_evidence: false'
pass "installed default TDD evidence gate is opt-in"

assert_contains "$target_root/.agent/task.yml" 'requires_architecture_evidence: false'
pass "installed default architecture evidence gate is opt-in"

assert_contains "$target_root/.agent/task.yml" 'requires_failure_attribution: false'
pass "installed default failure attribution gate is opt-in"

assert_contains "$target_root/.agent/task.yml" 'requires_intervention_record: false'
pass "installed default intervention record gate is opt-in"

assert_contains "$target_root/.agent/harness.yml" "sandbox:"
assert_contains "$target_root/.agent/harness.yml" "enabled: false"
assert_contains "$target_root/.agent/task.yml" "requires_sandbox_verification: false"
pass "installed default sandbox verification gate is opt-in"

assert_contains "$target_root/.agent/task.yml" "requires_command_ledger: false"
pass "installed default command ledger gate is opt-in"

assert_contains "$target_root/.agent/task.yml" "verification_profile: bootstrap"
assert_contains "$target_root/.agent/harness.yml" "profiles:"
assert_contains "$target_root/scripts/agent-task-profile.sh" "--verification-profile"
assert_contains "$target_root/scripts/agent-verify.sh" "resolve_verification_path"
assert_contains "$target_root/scripts/agent-verify.sh" "repo-defined verification commands are authoritative"
assert_contains "$target_root/schemas/task.schema.json" '"verification_profile"'
assert_contains "$target_root/schemas/harness.schema.json" '"verificationProfile"'
pass "installed verification profile contract is present"

assert_not_exists "$target_root/adapters/hooks/README.md"
assert_not_exists "$target_root/adapters/hooks/git/pre-commit"
assert_not_exists "$target_root/adapters/hooks/git/pre-push"
assert_not_exists "$target_root/.git/hooks/pre-commit"
assert_not_exists "$target_root/.git/hooks/pre-push"
pass "hook adapters are not installed automatically"

echo
echo "== Existing schema install behavior =="
existing_target="$tmp_root/existing schema target"
mkdir -p "$existing_target/schemas"
git init -q "$existing_target"
printf '%s\n' "sentinel policy" \
  >"$existing_target/schemas/policy.schema.json"
printf '%s\n' "target-owned custom schema" \
  >"$existing_target/schemas/custom.schema.json"

existing_skip_log="$tmp_root/existing-schema-skip.log"
bash "$repo_root/install-agent-harness.sh" "$existing_target" \
  >"$existing_skip_log" 2>&1
assert_contains "$existing_skip_log" \
  "SKIP existing: $existing_target/schemas/policy.schema.json"
assert_contains "$existing_target/schemas/policy.schema.json" "sentinel policy"
assert_contains "$existing_target/schemas/custom.schema.json" \
  "target-owned custom schema"

existing_force_log="$tmp_root/existing-schema-force.log"
bash "$repo_root/install-agent-harness.sh" --force --backup "$existing_target" \
  >"$existing_force_log" 2>&1
assert_contains "$existing_force_log" \
  "BACKUP: $existing_target/schemas/policy.schema.json.bak"
cmp -s \
  "$repo_root/schemas/policy.schema.json" \
  "$existing_target/schemas/policy.schema.json" || {
  echo "ERROR: --force did not install the source policy schema"
  exit 1
}
assert_contains "$existing_target/schemas/policy.schema.json.bak" \
  "sentinel policy"
assert_contains "$existing_target/schemas/custom.schema.json" \
  "target-owned custom schema"
pass "existing and target-only schema behavior"

echo
echo "== Invalid schema source packages =="
for package_case in missing empty; do
  package_root="$tmp_root/$package_case schema package"
  package_target="$tmp_root/$package_case schema target"
  package_log="$tmp_root/$package_case-schema-package.log"
  mkdir -p "$package_root" "$package_target"
  git init -q "$package_target"
  cp "$repo_root/install-agent-harness.sh" "$package_root/"
  cp -R "$repo_root/templates" "$package_root/"
  if [ "$package_case" = "empty" ]; then
    mkdir -p "$package_root/schemas"
  fi

  if bash "$package_root/install-agent-harness.sh" "$package_target" \
    >"$package_log" 2>&1
  then
    echo "ERROR: installer accepted $package_case public schema source"
    exit 1
  fi
  assert_not_contains "$package_log" "Install complete."
  assert_not_exists "$package_target/AGENTS.md"
done

assert_contains "$tmp_root/missing-schema-package.log" \
  "ERROR: schema directory not found:"
assert_contains "$tmp_root/empty-schema-package.log" \
  "ERROR: no public schema files found in:"
pass "invalid schema source packages fail before target writes"

(
  cd "$target_root"
  preflight_log="$target_root/agent-preflight.log"
  bash scripts/agent-preflight.sh >"$preflight_log" 2>&1
  assert_contains "$preflight_log" "== Dependencies =="
  assert_contains "$preflight_log" "OK: python"
  assert_contains "$preflight_log" "Architecture evidence is not required."
  assert_contains "$preflight_log" "== Episode metadata =="
  assert_contains "$preflight_log" "EPISODE_VALIDATION_RESULT=pass"
  assert_contains "$preflight_log" "== Audit command =="
  assert_contains "$preflight_log" "FOUND scripts/agent-audit.sh"
  bash scripts/validate-config.sh
  bash scripts/validate-task.sh
  bash scripts/check-doc-links.sh
  handoff_pass_log="$target_root/handoff-pass.log"
  bash scripts/validate-handoff.sh >"$handoff_pass_log" 2>&1
  assert_contains "$handoff_pass_log" "HANDOFF_RESULT=pass"
  handoff_missing_log="$target_root/handoff-missing.log"
  if bash scripts/validate-handoff.sh .agent/missing-handoff.yml \
    >"$handoff_missing_log" 2>&1
  then
    echo "ERROR: expected missing handoff file validation failure"
    exit 1
  fi
  assert_contains "$handoff_missing_log" "handoff file does not exist"
  assert_contains "$handoff_missing_log" "HANDOFF_RESULT=fail"
  printf '%s\n' \
    'current_task: "Missing required fields."' \
    > .agent/handoff-missing-required.yml
  handoff_missing_required_log="$target_root/handoff-missing-required.log"
  if bash scripts/validate-handoff.sh .agent/handoff-missing-required.yml \
    >"$handoff_missing_required_log" 2>&1
  then
    echo "ERROR: expected missing required field handoff validation failure"
    exit 1
  fi
  assert_contains "$handoff_missing_required_log" "missing required field: current_state"
  assert_contains "$handoff_missing_required_log" "HANDOFF_RESULT=fail"
  printf '%s\n' \
    'current_task: "Invalid changed files."' \
    'current_state: "Testing."' \
    'changed_files: "templates/handoff.md"' \
    'verification: []' \
    > .agent/handoff-bad-changed-files.yml
  handoff_bad_changed_files_log="$target_root/handoff-bad-changed-files.log"
  if bash scripts/validate-handoff.sh .agent/handoff-bad-changed-files.yml \
    >"$handoff_bad_changed_files_log" 2>&1
  then
    echo "ERROR: expected changed_files type handoff validation failure"
    exit 1
  fi
  assert_contains "$handoff_bad_changed_files_log" "changed_files must be a list"
  assert_contains "$handoff_bad_changed_files_log" "HANDOFF_RESULT=fail"
  printf '%s\n' \
    'current_task: "Invalid verification."' \
    'current_state: "Testing."' \
    'changed_files: []' \
    'verification: "bash validate-harness.sh"' \
    > .agent/handoff-bad-verification.yml
  handoff_bad_verification_log="$target_root/handoff-bad-verification.log"
  if bash scripts/validate-handoff.sh .agent/handoff-bad-verification.yml \
    >"$handoff_bad_verification_log" 2>&1
  then
    echo "ERROR: expected verification type handoff validation failure"
    exit 1
  fi
  assert_contains "$handoff_bad_verification_log" "verification must be a list"
  assert_contains "$handoff_bad_verification_log" "HANDOFF_RESULT=fail"
  printf '%s\n' \
    'current_task: "Invalid verification item."' \
    'current_state: "Testing."' \
    'changed_files: []' \
    'verification:' \
    '  - command: ""' \
    '    result: "pass"' \
    > .agent/handoff-missing-verification-command.yml
  handoff_missing_verification_command_log="$target_root/handoff-missing-verification-command.log"
  if bash scripts/validate-handoff.sh .agent/handoff-missing-verification-command.yml \
    >"$handoff_missing_verification_command_log" 2>&1
  then
    echo "ERROR: expected missing verification command validation failure"
    exit 1
  fi
  assert_contains "$handoff_missing_verification_command_log" "verification[0].command must be non-empty"
  assert_contains "$handoff_missing_verification_command_log" "HANDOFF_RESULT=fail"
  printf '%s\n' \
    'current_task: "Invalid verification item."' \
    'current_state: "Testing."' \
    'changed_files: []' \
    'verification:' \
    '  - command: "bash validate-harness.sh"' \
    > .agent/handoff-missing-verification-result.yml
  handoff_missing_verification_result_log="$target_root/handoff-missing-verification-result.log"
  if bash scripts/validate-handoff.sh .agent/handoff-missing-verification-result.yml \
    >"$handoff_missing_verification_result_log" 2>&1
  then
    echo "ERROR: expected missing verification result validation failure"
    exit 1
  fi
  assert_contains "$handoff_missing_verification_result_log" "verification[0].result must be non-empty"
  assert_contains "$handoff_missing_verification_result_log" "HANDOFF_RESULT=fail"
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
  subagent_evidence_skip_log="$target_root/subagent-evidence-skip.log"
  bash scripts/check-subagent-evidence.sh >"$subagent_evidence_skip_log" 2>&1
  assert_contains "$subagent_evidence_skip_log" "Subagent evidence is not required."
  assert_contains "$subagent_evidence_skip_log" "SUBAGENT_EVIDENCE_RESULT=skip"
  printf '%s\n' \
    'task:' \
    '  status: "in_progress"' \
    '  goal: "Validate subagent evidence gate."' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_subagent_evidence: true' \
    > .agent/task.yml
  rm -rf .agent/subagent-runs
  mkdir -p .agent/subagent-runs
  subagent_evidence_fail_log="$target_root/subagent-evidence-fail.log"
  if bash scripts/check-subagent-evidence.sh >"$subagent_evidence_fail_log" 2>&1; then
    echo "ERROR: expected required subagent evidence failure"
    exit 1
  fi
  assert_contains "$subagent_evidence_fail_log" "Subagent evidence is required."
  assert_contains "$subagent_evidence_fail_log" "FAIL: no valid subagent run evidence found"
  assert_contains "$subagent_evidence_fail_log" "SUBAGENT_EVIDENCE_RESULT=fail"
  mkdir -p .agent/subagent-runs/20260502-120000-implementer-phase-1-4
  cp .agent/subagent-packet.yml \
    .agent/subagent-runs/20260502-120000-implementer-phase-1-4/packet.yml
  printf '%s\n' "# Subagent Result" \
    > .agent/subagent-runs/20260502-120000-implementer-phase-1-4/result.md
  printf '%s\n' "DONE" \
    > .agent/subagent-runs/20260502-120000-implementer-phase-1-4/status.txt
  subagent_evidence_pass_log="$target_root/subagent-evidence-pass.log"
  bash scripts/check-subagent-evidence.sh >"$subagent_evidence_pass_log" 2>&1
  assert_contains "$subagent_evidence_pass_log" "Subagent evidence is required."
  assert_contains "$subagent_evidence_pass_log" "SUBAGENT_EVIDENCE_RESULT=pass"
  architecture_evidence_skip_log="$target_root/architecture-evidence-skip.log"
  bash scripts/check-architecture-evidence.sh >"$architecture_evidence_skip_log" 2>&1
  assert_contains "$architecture_evidence_skip_log" "Architecture evidence is not required."
  assert_contains "$architecture_evidence_skip_log" "ARCHITECTURE_EVIDENCE_RESULT=pass"

  sandbox_evidence_skip_log="$target_root/sandbox-evidence-skip.log"
  bash scripts/check-sandbox-evidence.sh >"$sandbox_evidence_skip_log" 2>&1
  assert_contains "$sandbox_evidence_skip_log" "Sandbox verification is not required."
  assert_contains "$sandbox_evidence_skip_log" "SANDBOX_EVIDENCE_RESULT=pass"
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
  assert_file_contains "$target_root" "architecture-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "architecture-evidence-result.txt" "Architecture evidence is not required."
  assert_file_contains "$target_root" "sandbox-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "sandbox-evidence-result.txt" "Sandbox verification is not required."
  assert_file_contains "$target_root" "subagent-evidence-result.txt" "Exit status: 0"
  assert_file_contains "$target_root" "subagent-evidence-result.txt" "Subagent evidence is required."
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
