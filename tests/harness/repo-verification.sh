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
