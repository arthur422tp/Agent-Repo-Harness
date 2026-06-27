# RAG Fixture Harness Friction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Use the RAG fixture to run a complete High-Risk harness adoption flow, measure gate value and friction, and make only evidence-backed ergonomics improvements.

**Architecture:** Extend the existing `tests/harness/rag-adoption.sh` suite instead of adding new harness runtime concepts. The test continues to copy `examples/rag-contract-system/` into a temporary Git repository, install the harness there, and validate the installed target; the new work adds a complete High-Risk finish flow with TDD, acceptance, review, architecture, command-ledger, and sandbox evidence. Documentation and report updates record measured friction and keep High-Risk as a selective gate menu.

**Tech Stack:** POSIX-ish Bash, existing Agent-Repo-Harness shell scripts, Python 3 standard library fixture commands, Markdown documentation.

---

## Approved Spec

Design source:

- `docs/superpowers/specs/2026-06-26-rag-fixture-harness-friction-design.md`

Hard constraints:

- Do not add completion gates, `.agent/task.yml` flags, schemas, runtime abstractions, or a profile engine.
- Do not require package installation for `examples/rag-contract-system/`.
- Keep generated `.agent/`, `.venv/`, and `__pycache__/` state out of the source fixture.
- Treat High-Risk as a selective menu; do not imply every high-risk task should enable every optional gate.
- Keep application defects separate from harness installation, configuration, evidence, or finish friction in the report.

## File Structure

Modify:

- `tests/harness/rag-adoption.sh` - add complete High-Risk finish evidence and assertions.
- `examples/rag-contract-system/adoption/report.md` - record measured High-Risk gate value, friction, and action.
- `examples/rag-contract-system/adoption/scenarios.md` - document the complete High-Risk flow.
- `examples/rag-contract-system/README.md` - clarify `PYTHONPATH=src` and source-purity expectations if needed by measured friction.
- `docs/agent/gate-guide.md` - clarify selective High-Risk evidence only if the report shows gate-selection friction.
- `templates/docs/agent/gate-guide.md` - mirror gate-guide changes byte-for-byte when `docs/agent/gate-guide.md` changes.
- `handoff.md` - record final verification and next action.
- `docs/superpowers/plans/2026-06-26-rag-fixture-harness-friction.md` - update task checkboxes as work completes.

Do not modify:

- `schemas/task.schema.json`
- `templates/.agent/task.yml`
- `templates/scripts/agent-finish.sh`
- `templates/scripts/check-*.sh` gate contracts

## Task 1: Add Failing Complete High-Risk Adoption Assertions

**Files:**
- Modify: `tests/harness/rag-adoption.sh`

- [x] **Step 1: Add assertions that require High-Risk finish evidence**

In `tests/harness/rag-adoption.sh`, after the existing sandbox evidence check:

```bash
  bash scripts/check-sandbox-evidence.sh > high-risk-evidence.log 2>&1
  assert_contains high-risk-evidence.log "SANDBOX_EVIDENCE_RESULT=pass"
```

add:

```bash
  PYTHONPATH=src bash scripts/agent-finish.sh --best-effort > high-risk-finish.log 2>&1
  assert_contains high-risk-finish.log "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$rag_root" "finish-summary.md" "check-review-evidence"
  assert_file_contains "$rag_root" "finish-summary.md" "check-architecture-evidence"
  assert_file_contains "$rag_root" "finish-summary.md" "check-command-ledger"
  assert_file_contains "$rag_root" "finish-summary.md" "check-sandbox-evidence"
  assert_file_contains "$rag_root" "finish-summary.md" "agent-verify"
  assert_contains high-risk-finish.log "HARNESS_VERIFY_RESULT="
```

The final accepted behavior checks that repo verification reported a result,
without requiring a pass value; optional missing host tools such as `ruff` may
honestly surface as warnings.

- [x] **Step 2: Run validation to verify the missing evidence fails**

```bash
bash validate-harness.sh
```

Expected: FAIL in the RAG adoption suite because the High-Risk installed
target has not populated review, architecture, command-ledger, or finish
evidence yet. The failure should occur before the final
`PASS: validation completed` marker.

- [x] **Step 3: Confirm the failure is scoped to High-Risk adoption**

Inspect the validation output and confirm these earlier checks still pass:

```text
PASS: installed script smoke checks
PASS: task validation command ledger flag behavior
PASS: sandbox evidence required and valid
PASS: RAG application tests before the new High-Risk finish assertion
```

If another suite fails first, stop and fix the unrelated failure before
continuing.

## Task 2: Populate Complete High-Risk Evidence In The Installed Target

**Files:**
- Modify: `tests/harness/rag-adoption.sh`

- [x] **Step 1: Add High-Risk TDD evidence**

After `cp adoption/high-risk-task.yml .agent/task.yml`, write:

```bash
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
```

- [x] **Step 2: Add High-Risk acceptance evidence**

Immediately after the High-Risk TDD evidence, write:

```bash
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
```

- [x] **Step 3: Add High-Risk review evidence**

Immediately after the acceptance evidence, write:

```bash
  cat > .agent/review.yml <<EOF
review:
  required: true
  status: approved
  reviewer: "rag-adoption-fixture"
  evidence: "tests/test_security.py, evals/cases.json, and high-risk command ledger evidence"
  summary: "Security-sensitive retrieval behavior is covered by tests and evals."
  concerns: []
EOF
```

- [x] **Step 4: Add High-Risk architecture evidence**

Immediately after the review evidence, write:

```bash
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
```

- [x] **Step 5: Run verification commands through `agent-run.sh`**

After enabling sandbox and before invoking `agent-sandbox-run.sh`, run:

```bash
  PYTHONPATH=src bash scripts/agent-run.sh -- \
    "$python_bin" -m unittest discover -s tests -v \
    > high-risk-command-tests.log 2>&1
  assert_contains high-risk-command-tests.log "COMMAND_RUN_RESULT=pass"

  PYTHONPATH=src bash scripts/agent-run.sh -- \
    "$python_bin" -m contract_rag.cli eval \
    > high-risk-command-evals.log 2>&1
  assert_contains high-risk-command-evals.log "COMMAND_RUN_RESULT=pass"
```

These commands create `.agent/command-runs/*` evidence for the existing
`requires_command_ledger: true` task flag.

- [x] **Step 6: Commit the installed target High-Risk evidence before finish**

Before running `agent-finish.sh`, commit the installed target evidence in the
temporary Git repository:

```bash
  git add .
  git commit -q -m "chore: configure High-Risk harness adoption"
```

This keeps scope and git-diff evidence stable for the finish run.

- [x] **Step 7: Run the targeted adoption suite through full validation**

```bash
bash validate-harness.sh
```

Expected: PASS, including:

```text
PASS: RAG contract fixture application and harness adoption
PASS: validation completed
```

## Task 3: Record Measured Friction And Minimal Resolution

**Files:**
- Modify: `examples/rag-contract-system/adoption/report.md`
- Modify: `examples/rag-contract-system/adoption/scenarios.md`
- Modify: `examples/rag-contract-system/README.md`

- [x] **Step 1: Update the High-Risk row in `adoption/report.md`**

Replace the existing High-Risk table row with:

```markdown
| High-Risk | Copy fixture; install; copy `high-risk-task.yml`; configure repo commands; populate TDD, acceptance, review, architecture, command-ledger, and sandbox evidence; run installed finish | `.agent/task.yml`, `.agent/harness.yml`, `.agent/tdd-evidence.yml`, `.agent/acceptance.yml`, `.agent/review.yml`, `.agent/architecture.yml`, `.agent/command-runs/*`, `.agent/sandbox-runs/*`; temporary fake-runner scripts | Application tests, evals, task validation, command ledger, fake-runner sandbox evidence, and finish passed | Evidence setup is deliberate but verbose; `PYTHONPATH=src` must be present for configured and heuristic Python checks | Architecture, review, command ledger, sandbox evidence, TDD, acceptance, repo verification | Failure attribution and intervention records were not needed because no repaired failure or manual override occurred | Keep High-Risk selective; document `PYTHONPATH=src` as fixture setup, not a new harness feature |
```

- [x] **Step 2: Add a measured High-Risk finding**

Under `## Initial Findings`, add:

```markdown
- The complete High-Risk finish flow showed value when each optional gate mapped
  to a named risk: architecture evidence captured the untrusted-data invariant,
  review evidence recorded security approval, command ledger made verification
  commands replayable, and sandbox evidence checked the external boundary.
  Failure attribution and intervention records stayed disabled because the run
  had no repaired failure or material manual override.
```

- [x] **Step 3: Update `adoption/scenarios.md` High-Risk instructions**

Replace the High-Risk section with:

```markdown
## High-Risk

- Task: `adoption/high-risk-task.yml`
- Additional evidence: `.agent/tdd-evidence.yml`, `.agent/acceptance.yml`,
  `.agent/review.yml`, `.agent/architecture.yml`, `.agent/command-runs/*`, and
  `.agent/sandbox-runs/*`
- Verify: `PYTHONPATH=src python -m unittest discover -s tests -v`,
  `PYTHONPATH=src python -m contract_rag.cli eval`, command ledger evidence,
  and sandbox evidence check
- Finish: `PYTHONPATH=src bash scripts/agent-finish.sh --best-effort` after all
  enabled evidence is populated
- Record: whether each enabled gate answered a named risk, which gates were
  intentionally left disabled, and how unavailable sandbox runners were handled.
```

- [x] **Step 4: Clarify the README verification environment**

In `examples/rag-contract-system/README.md`, make sure the verification section
contains this paragraph:

```markdown
The `PYTHONPATH=src` prefix is part of the fixture contract. The project is not
installed as a package during adoption tests, so configured harness commands
and any host-provided Python test discovery must inherit the same source path.
```

If the paragraph already exists with equivalent wording, keep the existing text
and do not duplicate it.

- [x] **Step 5: Run docs and full validation**

```bash
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected:

```text
DOC_LINKS_RESULT=pass
PASS: validation completed
```

- [x] **Step 6: Commit the measured adoption update**

```bash
git add tests/harness/rag-adoption.sh examples/rag-contract-system/adoption/report.md examples/rag-contract-system/adoption/scenarios.md examples/rag-contract-system/README.md
git commit -m "test: measure RAG high-risk harness adoption"
```

## Task 4: Final Verification, Handoff, And Plan Status

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `handoff.md`
- Modify: `docs/superpowers/plans/2026-06-26-rag-fixture-harness-friction.md`

- [x] **Step 1: Update changelog**

Under `## Unreleased`, add:

```markdown
- Measure complete High-Risk adoption for the contract RAG fixture and document
  evidence-backed harness friction.
```

- [x] **Step 2: Run full validation**

```bash
bash validate-harness.sh
```

Expected:

```text
PASS: validation completed
```

- [x] **Step 3: Run doc links and source audit**

```bash
bash templates/scripts/check-doc-links.sh .
bash templates/scripts/agent-audit.sh
```

Expected:

```text
DOC_LINKS_RESULT=pass
AGENT_AUDIT_RESULT=pass
```

- [x] **Step 4: Verify source fixture purity**

```bash
find examples/rag-contract-system -type d \( -name .venv -o -name __pycache__ -o -name .agent \) -prune -print
git status --short
```

Expected:

- the `find` command prints nothing
- git status shows only intended tracked changes and repository-level `.agent/`
  runtime evidence

- [x] **Step 5: Update handoff**

Replace the current `## Current State` and following sections in `handoff.md`
with:

```markdown
## Current State

The contract RAG fixture now measures a complete High-Risk Agent-Repo-Harness
adoption flow. The installed-target scenario records TDD, acceptance, review,
architecture, command-ledger, sandbox, and repository verification evidence
without adding new gates, schemas, profile engines, or runtime abstractions.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- `bash templates/scripts/agent-audit.sh`: PASS
- RAG Minimal, Standard, and complete High-Risk adoption scenarios: PASS through
  the repository validation suite

## Adoption Findings

- High-Risk gates add value when each gate maps to a named risk.
- `PYTHONPATH=src` remains an explicit fixture contract because the example is
  intentionally not installed as a package.
- Failure attribution and intervention records stay disabled when no repaired
  failure or material manual override occurs.

## Environment Isolation

- No third-party runtime packages required.
- No global Python package installation performed.
- The source RAG fixture remains free of `.agent/`, `.venv/`, and
  `__pycache__/` generated state.

## Next Action

Use the measured adoption report before changing harness gate behavior. Prefer
docs or fixture configuration unless repeated validation evidence proves a
harness behavior change is needed.
```

- [x] **Step 6: Mark this plan complete**

Mark every completed step in this plan with `[x]` only after validation,
handoff, audit, and source-purity evidence are current.

- [x] **Step 7: Inspect final status**

```bash
git status --short --branch
git diff --stat
```

Expected: only intended tracked changes remain, plus expected untracked
repository-level `.agent/` evidence.

- [x] **Step 8: Commit**

```bash
git add CHANGELOG.md handoff.md docs/superpowers/plans/2026-06-26-rag-fixture-harness-friction.md
git commit -m "chore: finalize RAG friction pass"
```

## Self-Review

Spec coverage:

- Complete High-Risk adoption flow: Tasks 1 and 2.
- Review, architecture, command-ledger, sandbox, TDD, acceptance, and repository
  verification evidence: Task 2.
- Gate value and cost measurement: Task 3.
- `PYTHONPATH=src` and host Python discovery friction decision: Task 3.
- Source fixture purity: Tasks 2 and 4.
- No new gates, flags, schemas, profile engine, or runtime abstraction: all
  tasks avoid those files and contracts.
- Final validation and handoff: Task 4.

Validation commands:

- `bash validate-harness.sh`
- `bash templates/scripts/check-doc-links.sh .`
- `bash templates/scripts/agent-audit.sh`

Plan complete and saved to `docs/superpowers/plans/2026-06-26-rag-fixture-harness-friction.md`.
