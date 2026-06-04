#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Intervention evidence skip semantics =="
interventions_skip_root="$tmp_root/interventions-skip"
rm -rf "$interventions_skip_root"
mkdir -p "$interventions_skip_root/.agent" "$interventions_skip_root/scripts/lib"
(
  cd "$interventions_skip_root"
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: false' \
    > .agent/task.yml
  bash scripts/check-interventions.sh > interventions-skip.log 2>&1
  assert_contains interventions-skip.log "Intervention record is not required."
  assert_contains interventions-skip.log "INTERVENTIONS_RESULT=pass"
)
pass "intervention evidence skip semantics"

echo
echo "== Intervention evidence required and valid =="
interventions_pass_root="$tmp_root/interventions-pass"
rm -rf "$interventions_pass_root"
mkdir -p "$interventions_pass_root/.agent" "$interventions_pass_root/scripts/lib"
(
  cd "$interventions_pass_root"
  cp "$repo_root/templates/.agent/interventions.yml" .agent/interventions.yml
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: true' \
    > .agent/task.yml
  bash scripts/check-interventions.sh > interventions-pass.log 2>&1
  assert_contains interventions-pass.log "Intervention record is required."
  assert_contains interventions-pass.log "OK: intervention 0"
  assert_contains interventions-pass.log "INTERVENTIONS_RESULT=pass"
)
pass "intervention evidence required and valid"

echo
echo "== Intervention evidence required and missing actor =="
interventions_bad_root="$tmp_root/interventions-bad"
rm -rf "$interventions_bad_root"
mkdir -p "$interventions_bad_root/.agent" "$interventions_bad_root/scripts/lib"
(
  cd "$interventions_bad_root"
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: true' \
    > .agent/task.yml
  printf '%s\n' \
    'interventions:' \
    '  required: true' \
    '  entries:' \
    '    - timestamp: "2026-06-03T00:00:00Z"' \
    '      type: "approval"' \
    '      summary: "Approved high-risk change."' \
    > .agent/interventions.yml
  if bash scripts/check-interventions.sh > interventions-bad.log 2>&1; then
    echo "ERROR: expected intervention gate failure"
    exit 1
  fi
  assert_contains interventions-bad.log "entries[0].actor must be non-empty"
  assert_contains interventions-bad.log "INTERVENTIONS_RESULT=fail"
)
pass "intervention evidence required and missing actor"
