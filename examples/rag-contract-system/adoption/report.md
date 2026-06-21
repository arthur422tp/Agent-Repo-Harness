# Adoption Report

| Scenario | Setup commands | Harness files edited | Verification | Friction | Valuable gates | Low-value gates | Action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Minimal | not_run | not_run | not_run | not_run | not_run | not_run | not_run |
| Standard | not_run | not_run | not_run | not_run | not_run | not_run | not_run |
| High-Risk | not_run | not_run | not_run | not_run | not_run | not_run | not_run |

## Initial Findings

- `PYTHONPATH=src` is required because the offline fixture avoids package
  installation. README and harness verification must state it explicitly.
- High-Risk must remain selective. Enabling every optional gate would add
  evidence work unrelated to malicious-retrieval risk.

## Reporting Rule

Record RAG application defects separately from harness installation,
configuration, evidence, or finish friction.
