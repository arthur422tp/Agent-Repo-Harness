# Adoption Report

| Scenario | Setup commands | Harness files edited | Verification | Friction | Valuable gates | Low-value gates | Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Minimal | Copy fixture; install with `--force`; copy `minimal-task.yml`; run `validate-task.sh` | `.agent/task.yml` | Task validation passed | No optional evidence setup was required | Scope, policy, verification | None observed | Keep |
| Standard | Copy fixture; install; configure repo commands; copy `standard-task.yml`; run `agent-finish.sh --best-effort` with `PYTHONPATH=src` | `.agent/harness.yml`, `.agent/task.yml`, `.agent/tdd-evidence.yml`, `.agent/acceptance.yml` | Application tests, evals, task validation, and finish passed | A globally available `pytest` heuristic also ran and required `PYTHONPATH=src` | TDD, acceptance, repo verification | Duplicate heuristic test discovery | Document the environment requirement |
| High-Risk | Copy fixture; install; copy `high-risk-task.yml`; enable sandbox; run fake runner and evidence check | `.agent/task.yml`, `.agent/harness.yml`; temporary fake-runner scripts | Task validation and sandbox evidence passed | Runner hooks were required; no Docker or Podman was needed | Sandbox evidence for the named isolation risk | Review, architecture, and command-ledger value were not measured by this smoke | Measure remaining gates only in a complete High-Risk finish scenario |

## Initial Findings

- `PYTHONPATH=src` is required because the offline fixture avoids package
  installation. README and harness verification must state it explicitly.
- High-Risk must remain selective. Enabling every optional gate would add
  evidence work unrelated to malicious-retrieval risk.
- The Standard finish exposed host-tool sensitivity: when `pytest` is already
  available, heuristic discovery runs in addition to configured commands and
  must inherit `PYTHONPATH=src` for this src-layout fixture.
- The source-purity assertion detected generated `__pycache__` directories;
  validation now proves copied or installed harness runs do not pollute the
  checked-in fixture.

## Reporting Rule

Record RAG application defects separately from harness installation,
configuration, evidence, or finish friction.
