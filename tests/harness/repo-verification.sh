#!/usr/bin/env bash
set -euo pipefail

echo "== Doc link validation failure =="
rm -rf "$doc_links_failure_root"
mkdir -p "$doc_links_failure_root/docs"
(
  cd "$doc_links_failure_root"
  copy_fixture broken-doc-links.md docs/broken.md
  doc_link_log="$doc_links_failure_root/doc-links-failure.log"
  if bash "$repo_root/templates/scripts/check-doc-links.sh" >"$doc_link_log" 2>&1; then
    echo "ERROR: expected doc link validation failure"
    exit 1
  fi
  assert_contains "$doc_link_log" "missing Markdown link target"
  assert_contains "$doc_link_log" "missing script reference"
  assert_contains "$doc_link_log" "DOC_LINKS_RESULT=fail"
)
pass "doc link validation failure"

echo

echo "== Repo-defined verification commands =="
mkdir -p "$verify_config_root/.agent"
git init -q "$verify_config_root"
(
  cd "$verify_config_root"
  copy_fixture verification-required.yml .agent/harness.yml
  mkdir -p scripts
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'exit 0' \
    > scripts/second-check.sh
  mkdir -p scripts/lib
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/check-policy.sh scripts/second-check.sh
  verify_log="$verify_config_root/agent-verify-config.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "Repo-defined verification commands found."
  assert_contains "$verify_log" "RUN: shell-check"
  assert_contains "$verify_log" "PASS: shell-check"
  assert_contains "$verify_log" "RUN: second-check"
  assert_contains "$verify_log" "PASS: second-check"
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
)
pass "repo-defined verification commands"

echo
echo "== Repo-defined multiline verification command =="
verify_multiline_root="$tmp_root/verify-multiline-config"
mkdir -p "$verify_multiline_root/.agent"
git init -q "$verify_multiline_root"
(
  cd "$verify_multiline_root"
  copy_fixture verification-required-multiline.yml .agent/harness.yml
  mkdir -p scripts/lib
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  verify_log="$verify_multiline_root/agent-verify-multiline.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "RUN: multiline-check"
  assert_contains "$verify_log" "PASS: multiline-check"
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
  assert_contains "$verify_multiline_root/verification-output.txt" "first"
  assert_contains "$verify_multiline_root/verification-output.txt" "second"
)
pass "repo-defined multiline verification command"

echo
echo "== Repo-defined malformed verification config =="
mkdir -p "$verify_bad_config_root/.agent"
git init -q "$verify_bad_config_root"
(
  cd "$verify_bad_config_root"
  copy_fixture verification-required-bad.yml .agent/harness.yml
  mkdir -p scripts/lib
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  verify_log="$verify_bad_config_root/agent-verify-bad-config.log"
  if bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1; then
    echo "ERROR: expected malformed verification config failure"
    exit 1
  fi
  assert_contains "$verify_log" "FAIL: repo-defined verification config"
  assert_contains "$verify_log" "could not read verification.required"
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=fail"
)
pass "repo-defined malformed verification config"

echo
echo "== Context collection modes =="
context_root="$tmp_root/context-collection"
mkdir -p "$context_root/.agent" "$context_root/docs/agent" "$context_root/scripts/lib"
git init -q "$context_root"
(
  cd "$context_root"
  cp "$repo_root/templates/scripts/collect-context.sh" scripts/collect-context.sh
  chmod +x scripts/collect-context.sh
  printf '%s\n' "# Agent" "stable line" > agent.md
  printf '%s\n' "# Handoff" "current state" > handoff.md
  printf '%s\n' "# Known" "known issue" > docs/agent/known-issues.md
  printf '%s\n' "# Discoveries" "discovery" > docs/agent/discoveries.md
  printf '%s\n' "status: active" "allowed_paths:" "  - src/**" > .agent/task.yml
  printf '%s\n' "high_risk_paths:" "  - secrets/**" > .agent/policy.yml
  compact_log="$context_root/compact.log"
  full_log="$context_root/full.log"
  bad_args_log="$context_root/bad-args.log"
  bash scripts/collect-context.sh >"$compact_log" 2>&1
  bash scripts/collect-context.sh --full >"$full_log" 2>&1
  bad_args_status=0
  bash scripts/collect-context.sh --full unexpected >"$bad_args_log" 2>&1 || bad_args_status=$?
  if [ "$bad_args_status" -eq 0 ]; then
    echo "ERROR: expected collect-context.sh to reject trailing args"
    exit 1
  fi
  if [ "$bad_args_status" -ne 2 ]; then
    echo "ERROR: expected collect-context.sh trailing args exit 2, got $bad_args_status"
    exit 1
  fi
  assert_contains "$compact_log" "== Context Loading Policy =="
  assert_contains "$compact_log" "Mode: compact"
  assert_contains "$compact_log" "== Task Scope =="
  assert_contains "$compact_log" "== Policy =="
  assert_contains "$full_log" "Mode: full"
  assert_contains "$full_log" "== Known Issues =="
  assert_contains "$full_log" "== Discoveries =="
  assert_contains "$bad_args_log" "ERROR: unknown argument: unexpected"
  assert_contains "$bad_args_log" "Usage: collect-context.sh [--full]"
)
pass "context collection modes"
