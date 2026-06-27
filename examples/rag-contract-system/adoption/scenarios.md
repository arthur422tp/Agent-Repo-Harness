# Harness Adoption Scenarios

These scenarios copy the fixture into a temporary Git repository before
installing Agent-Repo-Harness. The source fixture does not contain installed
harness state or generated evidence.

## Environment Rule

If a Python package or optional tool must be installed, create and activate
`.venv` first. Never use global `pip` or `pip3` for this fixture.

## Minimal

- Task: `adoption/minimal-task.yml`
- Customize: `.agent/task.yml`, `.agent/harness.yml`, `agent.md`, `handoff.md`
- Preflight: `bash scripts/agent-preflight.sh`
- Verify: `PYTHONPATH=src python -m unittest discover -s tests -v`
- Finish: `bash scripts/agent-finish.sh --best-effort`
- Record: setup commands, files edited, first-finish result, false positives,
  and whether optional gates stayed unobtrusive.

## Standard

- Task: `adoption/standard-task.yml`
- Additional evidence: `.agent/tdd-evidence.yml`, `.agent/acceptance.yml`
- Verify: unit tests and `PYTHONPATH=src python -m contract_rag.cli eval`
- Finish: `bash scripts/agent-finish.sh --best-effort`
- Record: red/green clarity, acceptance mapping, summary readability, and docs
  lookup path.

## High-Risk

- Task: `adoption/high-risk-task.yml`
- Additional evidence: `.agent/tdd-evidence.yml`, `.agent/acceptance.yml`,
  `.agent/review.yml`, `.agent/architecture.yml`, `.agent/command-runs/*`, and
  `.agent/sandbox-runs/*`
- Verify: `PYTHONPATH=src python -m unittest discover -s tests -v`,
  `PYTHONPATH=src python -m contract_rag.cli eval`, command ledger evidence,
  and sandbox evidence check
- Finish: `PYTHONPATH=src bash scripts/agent-finish.sh --best-effort` after all
  enabled evidence is populated. Best-effort repo verification may warn when an
  optional host tool such as `ruff` is unavailable.
- Record: whether each enabled gate answered a named risk, which gates were
  intentionally left disabled, and how unavailable sandbox runners were handled.
