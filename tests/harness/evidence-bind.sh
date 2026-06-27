#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  evidence_bind_repo_root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
  export PYTHONDONTWRITEBYTECODE=1
  # shellcheck source=tests/harness/lib.sh
  source "$evidence_bind_repo_root/tests/harness/lib.sh"
  repo_root="$evidence_bind_repo_root"
  fixture_root="$repo_root/tests/fixtures/validate-harness"
fi

echo "== Evidence bind success =="
rm -rf "$evidence_bind_success_root"
mkdir -p "$evidence_bind_success_root/.agent/runs/20260627-091500" \
  "$evidence_bind_success_root/.agent" \
  "$evidence_bind_success_root/scripts/lib" \
  "$evidence_bind_success_root/scripts"
(
  cd "$evidence_bind_success_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": [
    {
      "name": "agent-verify",
      "result": "pass",
      "exit_status": 0,
      "path": ".agent/runs/20260627-091500/verify-result.txt"
    }
  ]
}
JSON
  printf '%s\n' 'HARNESS_VERIFY_RESULT=pass' > .agent/runs/20260627-091500/verify-result.txt
  bash scripts/agent-evidence-bind.sh \
    --run .agent/runs/20260627-091500 \
    --acceptance .agent/acceptance.yml \
    --criterion AC-1 \
    --gate agent-verify > bind.log 2>&1
  assert_contains bind.log "AGENT_EVIDENCE_BIND_RESULT=pass"
  assert_contains .agent/acceptance.yml "evidence_refs:"
  assert_contains .agent/acceptance.yml "type: finish_summary_json"
  assert_contains .agent/acceptance.yml "path: .agent/runs/20260627-091500/finish-summary.json"
  assert_contains .agent/acceptance.yml "expected_exit_status: 0"
  python_bin="$(find_python)"
  "$python_bin" scripts/check-evidence-refs.py .agent/acceptance.yml > refs.log 2>&1
  assert_contains refs.log "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence bind success"

echo
echo "== Evidence bind missing run fails =="
rm -rf "$evidence_bind_missing_run_root"
mkdir -p "$evidence_bind_missing_run_root/.agent" "$evidence_bind_missing_run_root/scripts"
(
  cd "$evidence_bind_missing_run_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  if bash scripts/agent-evidence-bind.sh --run .agent/runs/missing --criterion AC-1 > missing-run.log 2>&1; then
    echo "ERROR: expected missing run failure"
    exit 1
  fi
  assert_contains missing-run.log "FAIL: run directory not found"
  assert_contains missing-run.log "AGENT_EVIDENCE_BIND_RESULT=fail"
)
pass "evidence bind missing run fails"

echo
echo "== Evidence bind missing gate fails =="
rm -rf "$evidence_bind_missing_gate_root"
mkdir -p "$evidence_bind_missing_gate_root/.agent/runs/20260627-091501" \
  "$evidence_bind_missing_gate_root/.agent" \
  "$evidence_bind_missing_gate_root/scripts"
(
  cd "$evidence_bind_missing_gate_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  cat > .agent/runs/20260627-091501/finish-summary.json <<'JSON'
{"overall_result":"pass","gates":[{"name":"check-scope","result":"pass","exit_status":0}]}
JSON
  if bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091501 --criterion AC-1 --gate agent-verify > missing-gate.log 2>&1; then
    echo "ERROR: expected missing gate failure"
    exit 1
  fi
  assert_contains missing-gate.log "FAIL: gate not found: agent-verify"
  assert_contains missing-gate.log "AGENT_EVIDENCE_BIND_RESULT=fail"
)
pass "evidence bind missing gate fails"

echo
echo "== Evidence bind idempotent append =="
rm -rf "$evidence_bind_idempotent_root"
cp -R "$evidence_bind_success_root" "$evidence_bind_idempotent_root"
(
  cd "$evidence_bind_idempotent_root"
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > first.log 2>&1
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > second.log 2>&1
  ref_count="$(grep -c 'type: finish_summary_json' .agent/acceptance.yml)"
  if [ "$ref_count" -ne 1 ]; then
    echo "ERROR: expected one finish_summary_json ref, found $ref_count"
    exit 1
  fi
)
pass "evidence bind idempotent append"

echo
echo "== Evidence bind replace mode =="
rm -rf "$evidence_bind_replace_root"
cp -R "$evidence_bind_success_root" "$evidence_bind_replace_root"
(
  cd "$evidence_bind_replace_root"
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
      evidence_refs:
        - type: command_output
          path: .agent/runs/20260627-091500/verify-result.txt
          must_contain:
            - HARNESS_VERIFY_RESULT=pass
YAML
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify --replace > replace.log 2>&1
  assert_contains replace.log "AGENT_EVIDENCE_BIND_RESULT=pass"
  assert_contains .agent/acceptance.yml "type: finish_summary_json"
  assert_not_contains .agent/acceptance.yml "type: command_output"
  python_bin="$(find_python)"
  "$python_bin" scripts/check-evidence-refs.py .agent/acceptance.yml > refs.log 2>&1
  assert_contains refs.log "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence bind replace mode"

echo
echo "== Evidence bind preserves unknown criterion fields =="
rm -rf "$evidence_bind_strict_root"
cp -R "$evidence_bind_success_root" "$evidence_bind_strict_root"
(
  cd "$evidence_bind_strict_root"
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
      owner:
        team: platform
        reviewers:
          - agent
YAML
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > preserve.log 2>&1
  assert_contains preserve.log "AGENT_EVIDENCE_BIND_RESULT=pass"
  assert_contains .agent/acceptance.yml "owner:"
  assert_contains .agent/acceptance.yml "team: platform"
  assert_contains .agent/acceptance.yml "reviewers:"
  assert_contains .agent/acceptance.yml "- agent"
  assert_contains .agent/acceptance.yml "type: finish_summary_json"
)
pass "evidence bind preserves unknown criterion fields"

echo
echo "== Evidence bind strict acceptance compatibility =="
rm -rf "$evidence_bind_strict_root"
cp -R "$evidence_bind_success_root" "$evidence_bind_strict_root"
(
  cd "$evidence_bind_strict_root"
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  chmod +x scripts/*.sh
  cat > .agent/harness.yml <<'YAML'
evidence:
  strict_refs: true
  allow_text_only_evidence: false
YAML
  cat > .agent/task.yml <<'YAML'
task:
  completion:
    requires_acceptance_check: true
YAML
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > bind.log 2>&1
  bash scripts/check-acceptance.sh > acceptance.log 2>&1
  assert_contains acceptance.log "Strict evidence refs are enabled."
  assert_contains acceptance.log "ACCEPTANCE_RESULT=pass"
  assert_contains acceptance.log "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence bind strict acceptance compatibility"
