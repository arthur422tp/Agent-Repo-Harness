#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Architecture evidence not required by default =="
architecture_optional_root="$tmp_root/architecture-optional"
rm -rf "$architecture_optional_root"
mkdir -p "$architecture_optional_root/.agent" "$architecture_optional_root/scripts/lib"
(
  cd "$architecture_optional_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: false' > .agent/task.yml
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "Architecture evidence is not required."
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=pass"
)
pass "architecture evidence not required by default"

echo
echo "== Architecture evidence skips without task reader =="
architecture_no_task_reader_root="$tmp_root/architecture-no-task-reader"
rm -rf "$architecture_no_task_reader_root"
mkdir -p "$architecture_no_task_reader_root/scripts"
(
  cd "$architecture_no_task_reader_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  chmod +x scripts/*.sh
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "Architecture evidence is not required."
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=pass"
)
pass "architecture evidence skips without task reader"

echo
echo "== Architecture evidence required and valid =="
architecture_valid_root="$tmp_root/architecture-valid"
rm -rf "$architecture_valid_root"
mkdir -p "$architecture_valid_root/.agent" "$architecture_valid_root/scripts/lib"
(
  cd "$architecture_valid_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  printf '%s\n' \
    'architecture:' \
    '  status: upheld' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "Reviewed changed module boundaries and public API shape."' \
    '  invariants:' \
    '    - id: "small-public-api"' \
    '      description: "No new broad public API was introduced."' \
    '      status: upheld' \
    '      evidence: "Diff only changes internal harness files."' \
    > .agent/architecture.yml
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "Architecture evidence is required."
  assert_contains architecture.log "OK: invariant small-public-api"
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=pass"
)
pass "architecture evidence required and valid"

echo
echo "== Architecture evidence required and invalid =="
architecture_invalid_root="$tmp_root/architecture-invalid"
rm -rf "$architecture_invalid_root"
mkdir -p "$architecture_invalid_root/.agent" "$architecture_invalid_root/scripts/lib"
(
  cd "$architecture_invalid_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  printf '%s\n' \
    'architecture:' \
    '  status: violated' \
    '  reviewer: ""' \
    '  evidence: ""' \
    '  invariants: []' \
    > .agent/architecture.yml
  if bash scripts/check-architecture-evidence.sh > architecture.log 2>&1; then
    echo "ERROR: expected architecture evidence failure"
    exit 1
  fi
  assert_contains architecture.log "architecture.status must be upheld or upheld_with_concerns"
  assert_contains architecture.log "architecture.reviewer must be non-empty"
  assert_contains architecture.log "architecture.evidence must be non-empty"
  assert_contains architecture.log "architecture.invariants must contain at least one invariant"
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=fail"
  assert_contains architecture.log "docs/agent/repair-failed-run.md"
)
pass "architecture evidence required and invalid"

echo
echo "== Preflight warns but does not block required architecture evidence =="
architecture_preflight_root="$tmp_root/architecture-preflight"
rm -rf "$architecture_preflight_root"
mkdir -p "$architecture_preflight_root/.agent" "$architecture_preflight_root/scripts/lib"
(
  cd "$architecture_preflight_root"
  cp "$repo_root/templates/scripts/agent-preflight.sh" scripts/agent-preflight.sh
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  bash scripts/agent-preflight.sh > preflight.log 2>&1
  assert_contains preflight.log "Architecture evidence is required."
  assert_contains preflight.log "ARCHITECTURE_EVIDENCE_RESULT=fail"
  assert_contains preflight.log "WARN: architecture evidence is incomplete"
  assert_contains preflight.log "PREFLIGHT_RESULT=pass"
)
pass "preflight warns but does not block required architecture evidence"
