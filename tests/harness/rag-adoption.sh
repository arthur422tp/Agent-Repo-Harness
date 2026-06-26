#!/usr/bin/env bash
set -euo pipefail

echo
echo "== RAG contract fixture application and harness adoption =="
rag_source="$repo_root/examples/rag-contract-system"
rag_root="$tmp_root/rag-adoption"
rm -rf "$rag_root"
mkdir -p "$rag_root"

(
  cd "$rag_source"
  tar \
    --exclude './.venv' \
    --exclude './.agent' \
    --exclude '*/__pycache__' \
    -cf - .
) | (
  cd "$rag_root"
  tar -xf -
)

python_bin="$(find_python)"

(
  cd "$rag_root"
  git init -q
  git config user.email "rag-adoption@example.invalid"
  git config user.name "RAG Adoption Test"

  PYTHONPATH=src "$python_bin" -m unittest discover -s tests -v \
    > application-tests.log 2>&1
  PYTHONPATH=src "$python_bin" -m contract_rag.cli eval \
    > application-evals.log 2>&1
  assert_contains application-evals.log "PASS: msa-termination"
  assert_contains application-evals.log "PASS: dpa-breach"

  git add .
  git commit -q -m "chore: add RAG fixture baseline"

  bash "$repo_root/install-agent-harness.sh" --force "$PWD" \
    > install-harness.log 2>&1

  for profile in minimal standard high-risk; do
    cp "adoption/$profile-task.yml" .agent/task.yml
    bash scripts/validate-task.sh > "validate-$profile.log" 2>&1
    assert_contains "validate-$profile.log" "TASK_VALIDATION_RESULT=pass"
  done

  "$python_bin" - "$python_bin" <<'PY'
import sys
from pathlib import Path

python_bin = sys.argv[1]
path = Path(".agent/harness.yml")
text = path.read_text(encoding="utf-8")
marker = "  # Optional repo-defined verification commands run before heuristic checks.\n"
required = (
    "  required:\n"
    "    - name: \"contract RAG unit tests\"\n"
    f"      command: \"PYTHONPATH=src {python_bin} -m unittest discover -s tests -v\"\n"
    "    - name: \"contract RAG evals\"\n"
    f"      command: \"PYTHONPATH=src {python_bin} -m contract_rag.cli eval\"\n"
)
if marker not in text:
    raise SystemExit("verification insertion marker not found")
path.write_text(text.replace(marker, required + marker, 1), encoding="utf-8")
PY

  cp adoption/standard-task.yml .agent/task.yml
  cat > .agent/tdd-evidence.yml <<EOF
status: required
red_phase:
  command: "PYTHONPATH=src $python_bin -m unittest discover -s tests -v"
  observed_failure: "Metadata filtering test failed before implementation."
green_phase:
  command: "PYTHONPATH=src $python_bin -m unittest discover -s tests -v"
  observed_pass: "All retrieval and pipeline tests passed."
refactor_phase:
  command: "PYTHONPATH=src $python_bin -m contract_rag.cli eval"
  result: "All fixed evaluation cases passed."
tests_added_or_changed:
  - "tests/test_retriever.py"
  - "tests/test_pipeline.py"
notes: "Recorded fixture evidence for Standard adoption validation."
EOF
  cat > .agent/acceptance.yml <<EOF
acceptance:
  criteria:
    - id: jurisdiction-filter
      description: "Jurisdiction and contract-type filters constrain retrieval."
      met: true
      evidence: "tests/test_retriever.py and tests/test_pipeline.py"
      verification: "PYTHONPATH=src $python_bin -m unittest discover -s tests -v"
EOF

  git add .
  git commit -q -m "chore: configure Standard harness adoption"
  PYTHONPATH=src bash scripts/agent-finish.sh --best-effort > standard-finish.log 2>&1
  assert_contains standard-finish.log "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$rag_root" "finish-summary.md" "### Core Guardrails"
  assert_file_contains "$rag_root" "finish-summary.md" "### Optional Evidence"

  cp adoption/high-risk-task.yml .agent/task.yml
  cat > .agent/tdd-evidence.yml <<EOF
status: required
red_phase:
  command: "PYTHONPATH=src $python_bin -m unittest tests/test_security.py"
  observed_failure: "Security regression failed before answer composition treated retrieved instructions as untrusted data."
green_phase:
  command: "PYTHONPATH=src $python_bin -m unittest discover -s tests -v"
  observed_pass: "All RAG fixture tests passed with malicious retrieved instructions treated as data."
refactor_phase:
  command: "PYTHONPATH=src $python_bin -m contract_rag.cli eval"
  result: "All fixed evaluation cases passed."
tests_added_or_changed:
  - "tests/test_security.py"
  - "evals/cases.json"
notes: "Recorded High-Risk evidence for malicious retrieval isolation."
EOF
  cat > .agent/acceptance.yml <<EOF
acceptance:
  criteria:
    - id: malicious-instructions-untrusted
      description: "Retrieved instructions cannot suppress citations or change answer policy."
      met: true
      evidence: "tests/test_security.py"
      verification: "PYTHONPATH=src $python_bin -m unittest discover -s tests -v"
    - id: fixed-evals-still-pass
      description: "Security handling does not break fixed contract evaluation cases."
      met: true
      evidence: "evals/cases.json and contract_rag.cli eval"
      verification: "PYTHONPATH=src $python_bin -m contract_rag.cli eval"
EOF
  cat > .agent/review.yml <<EOF
review:
  required: true
  status: approved
  reviewer: "rag-adoption-fixture"
  evidence: "tests/test_security.py, evals/cases.json, and high-risk command ledger evidence"
  summary: "Security-sensitive retrieval behavior is covered by tests and evals."
  concerns: []
EOF
  cat > .agent/architecture.yml <<EOF
architecture:
  status: upheld
  reviewer: "rag-adoption-fixture"
  evidence: "src/contract_rag/answerer.py, tests/test_security.py, and evals/cases.json"
  invariants:
    - id: retrieved-text-is-data
      description: "Contract text and metadata are never interpreted as executable instructions."
      status: upheld
      evidence: "src/contract_rag/answerer.py and tests/test_security.py"
    - id: citations-remain-required
      description: "Supported answers retain citations even when retrieved chunks contain hostile text."
      status: upheld
      evidence: "tests/test_pipeline.py and tests/test_security.py"
  notes: "The fixture measures harness evidence flow; it does not claim semantic proof beyond deterministic tests."
EOF
  "$python_bin" - <<'PY'
from pathlib import Path

path = Path(".agent/harness.yml")
text = path.read_text(encoding="utf-8")
if "  enabled: false\n" not in text:
    raise SystemExit("sandbox enabled marker not found")
path.write_text(text.replace("  enabled: false\n", "  enabled: true\n", 1), encoding="utf-8")
PY

  mkdir -p bin
  cat > bin/fake-docker <<'SH'
#!/usr/bin/env bash
printf '%s\n' "fake sandbox verification"
exit 0
SH
  cat > bin/fake-timeout <<'SH'
#!/usr/bin/env bash
shift
exec "$@"
SH
  chmod +x bin/fake-docker bin/fake-timeout

  PATH="$PWD/bin:$PATH" PYTHONPATH=src bash scripts/agent-run.sh -- \
    "$python_bin" -m unittest discover -s tests -v \
    > high-risk-command-tests.log 2>&1
  assert_contains high-risk-command-tests.log "COMMAND_RUN_RESULT=pass"

  PATH="$PWD/bin:$PATH" PYTHONPATH=src bash scripts/agent-run.sh -- \
    "$python_bin" -m contract_rag.cli eval \
    > high-risk-command-evals.log 2>&1
  assert_contains high-risk-command-evals.log "COMMAND_RUN_RESULT=pass"

  PATH="$PWD/bin:$PATH" \
    HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_TIMEOUT_BIN="$PWD/bin/fake-timeout" \
    bash scripts/agent-sandbox-run.sh > high-risk-sandbox.log 2>&1
  assert_contains high-risk-sandbox.log "SANDBOX_RUN_RESULT=pass"
  bash scripts/check-sandbox-evidence.sh > high-risk-evidence.log 2>&1
  assert_contains high-risk-evidence.log "SANDBOX_EVIDENCE_RESULT=pass"

  git add .
  git commit -q -m "chore: configure High-Risk harness adoption"

  PYTHONPATH=src bash scripts/agent-finish.sh --best-effort > high-risk-finish.log 2>&1
  assert_contains high-risk-finish.log "AGENT_FINISH_RESULT=pass"
  high_risk_run_dir="$(sed -n 's/^Run directory: //p' high-risk-finish.log | tail -n 1)"
  if [ -z "$high_risk_run_dir" ]; then
    echo "ERROR: expected high-risk finish log to include run directory"
    exit 1
  fi
  high_risk_summary_file="$high_risk_run_dir/finish-summary.md"
  if [ ! -f "$high_risk_summary_file" ]; then
    echo "ERROR: expected high-risk finish summary: $high_risk_summary_file"
    exit 1
  fi
  assert_contains "$high_risk_summary_file" "check-review-evidence"
  assert_contains "$high_risk_summary_file" "check-architecture-evidence"
  assert_contains "$high_risk_summary_file" "check-command-ledger"
  assert_contains "$high_risk_summary_file" "check-sandbox-evidence"
  assert_contains "$high_risk_summary_file" "agent-verify"
  assert_contains high-risk-finish.log "HARNESS_VERIFY_RESULT="
)

if find "$rag_source" -type d \
  \( -name .venv -o -name .agent -o -name __pycache__ \) \
  -print -quit | grep -q .
then
  echo "ERROR: generated environment or harness state found in source RAG fixture"
  exit 1
fi

pass "RAG contract fixture application and harness adoption"
