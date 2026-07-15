# Changelog

## Unreleased

### Changed

- Add repository-only release integrity and prior-release upgrade checks.
- Add optional named verification profiles selected through
  `task.verification_profile`.
- Repo-defined configured verification commands now suppress language heuristics; repositories that need those checks must list them explicitly in
  `verification.required` or the selected profile.
- Ignore untracked harness runtime evidence in scope checks while continuing to
  enforce tracked evidence changes.

## v0.2.0 - Agent-facing productization polish

- Ensure `check-acceptance.sh` emits exactly one final
  `ACCEPTANCE_RESULT=pass|fail` marker per required run.
- Clarify that `scripts/agent-task-profile.sh` rewrites the output task file
  and add a warning before overwriting existing task state.
- Extend `scripts/check-evidence-refs.py` so architecture evidence can validate
  `architecture.evidence_refs` and invariant-level `evidence_refs`.
- Add a concrete failed-run repair example with failed and passed finish
  evidence.
- Classify `agent-task-profile.sh`, `agent-evidence-bind.sh`, and
  `check-evidence-refs.py` as intended-stable v0.x agent-facing helper CLIs.

## v0.1.1 - RAG adoption benchmark

- Measure complete High-Risk adoption for the contract RAG fixture and document
  evidence-backed harness friction.
- Expand the contract RAG example into an offline deterministic application,
  evaluation suite, and harness adoption fixture.
- Add a canonical gate guide with Minimal, Standard, and High-Risk documentation profiles.
- Simplify public and installed gate-selection guidance.
- Group human-readable finish checks without changing the JSON evidence contract.
- Explicit command ledger evidence through the installed `agent-run.sh`
  command runner and an opt-in `requires_command_ledger` completion gate.

## v0.1.0 - Initial public baseline

Initial repo-local completion gate for AI coding agents.

Highlights:

- installable repo-local harness templates
- `AGENTS.md` and `CLAUDE.md` entrypoints
- `scripts/agent-finish.sh` completion gate
- scope and policy checks
- repo-defined verification via `.agent/harness.yml`
- opt-in TDD, acceptance, review, architecture, subagent, failure attribution, intervention, and sandbox evidence gates
- durable `.agent/runs/<timestamp>/` finish evidence
- machine-readable `finish-summary.json` and `episode-summary.json`
- local resource-envelope controls and entropy audit reports
- external sandbox verification envelope with `.agent/sandbox-runs/<timestamp>/` evidence
- Sandbox smoke readiness through `ci/sandbox-smoke.sh` and GitHub Actions
- Codex and Claude Code adapters
- GitHub Actions CI running `bash validate-harness.sh`

Notes:

- not a runtime
- not a sandbox
- not a semantic correctness guarantee
- sandbox verification depends on an external Docker or Podman runner
