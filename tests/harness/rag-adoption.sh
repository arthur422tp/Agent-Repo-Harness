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

  HARNESS_SANDBOX_RUNNER_BIN="$PWD/bin/fake-docker" \
    HARNESS_SANDBOX_TIMEOUT_BIN="$PWD/bin/fake-timeout" \
    bash scripts/agent-sandbox-run.sh > high-risk-sandbox.log 2>&1
  assert_contains high-risk-sandbox.log "SANDBOX_RUN_RESULT=pass"
  bash scripts/check-sandbox-evidence.sh > high-risk-evidence.log 2>&1
  assert_contains high-risk-evidence.log "SANDBOX_EVIDENCE_RESULT=pass"
)

if find "$rag_source" -type d \
  \( -name .venv -o -name .agent -o -name __pycache__ \) \
  -print -quit | grep -q .
then
  echo "ERROR: generated environment or harness state found in source RAG fixture"
  exit 1
fi

pass "RAG contract fixture application and harness adoption"
