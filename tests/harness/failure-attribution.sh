#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Failure attribution skip semantics =="
failure_attr_skip_root="$tmp_root/failure-attribution-skip"
rm -rf "$failure_attr_skip_root"
mkdir -p "$failure_attr_skip_root/.agent" "$failure_attr_skip_root/scripts/lib"
(
  cd "$failure_attr_skip_root"
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: false' \
    > .agent/task.yml
  bash scripts/check-failure-attribution.sh > failure-attribution-skip.log 2>&1
  assert_contains failure-attribution-skip.log "Failure attribution is not required."
  assert_contains failure-attribution-skip.log "FAILURE_ATTRIBUTION_RESULT=pass"
)
pass "failure attribution skip semantics"

echo
echo "== Failure attribution required and valid =="
failure_attr_pass_root="$tmp_root/failure-attribution-pass"
rm -rf "$failure_attr_pass_root"
mkdir -p "$failure_attr_pass_root/.agent" "$failure_attr_pass_root/scripts/lib"
(
  cd "$failure_attr_pass_root"
  cp "$repo_root/templates/.agent/failure-attribution.yml" .agent/failure-attribution.yml
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: true' \
    > .agent/task.yml
  bash scripts/check-failure-attribution.sh > failure-attribution-pass.log 2>&1
  assert_contains failure-attribution-pass.log "Failure attribution is required."
  assert_contains failure-attribution-pass.log "OK: failure attribution"
  assert_contains failure-attribution-pass.log "FAILURE_ATTRIBUTION_RESULT=pass"
)
pass "failure attribution required and valid"

echo
echo "== Failure attribution required and invalid =="
failure_attr_bad_root="$tmp_root/failure-attribution-bad"
rm -rf "$failure_attr_bad_root"
mkdir -p "$failure_attr_bad_root/.agent" "$failure_attr_bad_root/scripts/lib"
(
  cd "$failure_attr_bad_root"
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: true' \
    > .agent/task.yml
  printf '%s\n' \
    'failure_attribution:' \
    '  required: true' \
    '  status: incomplete' \
    > .agent/failure-attribution.yml
  if bash scripts/check-failure-attribution.sh > failure-attribution-bad.log 2>&1; then
    echo "ERROR: expected failure attribution gate failure"
    exit 1
  fi
  assert_contains failure-attribution-bad.log "root_cause must be non-empty"
  assert_contains failure-attribution-bad.log "FAILURE_ATTRIBUTION_RESULT=fail"
)
pass "failure attribution required and invalid"
