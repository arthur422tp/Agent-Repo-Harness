# Adoption Report

| Scenario | Setup commands | Harness files edited | Verification | Friction | Valuable gates | Low-value gates | Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Minimal | Copy fixture; install with `--force`; copy `minimal-task.yml`; run `validate-task.sh` | `.agent/task.yml` | Task validation passed | No optional evidence setup was required | Scope, policy, verification | None observed | Keep |
| Standard | Copy fixture; install; configure repo commands; copy `standard-task.yml`; run `agent-finish.sh --best-effort` with `PYTHONPATH=src` | `.agent/harness.yml`, `.agent/task.yml`, `.agent/tdd-evidence.yml`, `.agent/acceptance.yml` | Application tests, evals, task validation, and finish passed | A globally available `pytest` heuristic also ran and required `PYTHONPATH=src` | TDD, acceptance, repo verification | Duplicate heuristic test discovery | Document the environment requirement |
| High-Risk | Copy fixture; install; copy `high-risk-task.yml`; configure repo commands; populate TDD, acceptance, review, architecture, command-ledger, and sandbox evidence; run installed finish | `.agent/task.yml`, `.agent/harness.yml`, `.agent/tdd-evidence.yml`, `.agent/acceptance.yml`, `.agent/review.yml`, `.agent/architecture.yml`, `.agent/command-runs/*`, `.agent/sandbox-runs/*`; temporary fake-runner scripts | Application tests, evals, task validation, command ledger, fake-runner sandbox evidence, and finish passed; best-effort repo verification can warn when optional host tools such as `ruff` are unavailable | Evidence setup is deliberate but verbose; `PYTHONPATH=src` must be present for configured and heuristic Python checks | Architecture, review, command ledger, sandbox evidence, TDD, acceptance, repo verification | Failure attribution and intervention records were not needed because no repaired failure or manual override occurred | Keep High-Risk selective; document `PYTHONPATH=src` as fixture setup, not a new harness feature |

## Initial Findings

- `PYTHONPATH=src` is required because the offline fixture avoids package
  installation. README and harness verification must state it explicitly.
- High-Risk must remain selective. Enabling every optional gate would add
  evidence work unrelated to malicious-retrieval risk.
- The complete High-Risk finish flow showed value when each optional gate mapped
  to a named risk: architecture evidence captured the untrusted-data invariant,
  review evidence recorded security approval, command ledger made verification
  commands replayable, and sandbox evidence checked the external boundary.
  Failure attribution and intervention records stayed disabled because the run
  had no repaired failure or material manual override.
- The Standard finish exposed host-tool sensitivity: when `pytest` is already
  available, heuristic discovery runs in addition to configured commands and
  must inherit `PYTHONPATH=src` for this src-layout fixture.
- Best-effort verification stayed honest about host-tool sensitivity: optional
  checks can report `HARNESS_VERIFY_RESULT=warn` when tools such as `ruff` are
  unavailable.
- The source-purity assertion detected generated `__pycache__` directories;
  validation now proves copied or installed harness runs do not pollute the
  checked-in fixture.

## Reporting Rule

Record RAG application defects separately from harness installation,
configuration, evidence, or finish friction.
