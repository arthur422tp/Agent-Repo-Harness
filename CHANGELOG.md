# Changelog

## Unreleased

- Add optional episode package metadata and generated `episode-summary.json`.
- Add optional failure attribution and intervention evidence gates.
- Add `scripts/agent-audit.sh` for local entropy audit reports.
- Document H3-style harness workflows while preserving the repo-local runtime boundary.

## v0.1.0 - Initial public baseline

Initial repo-local completion gate for AI coding agents.

Highlights:

- installable repo-local harness templates
- `AGENTS.md` and `CLAUDE.md` entrypoints
- `scripts/agent-finish.sh` completion gate
- scope and policy checks
- repo-defined verification via `.agent/harness.yml`
- opt-in TDD, acceptance, review, and subagent evidence gates
- durable `.agent/runs/<timestamp>/` finish evidence
- machine-readable finish evidence, local resource-envelope controls, architecture evidence, and runtime-boundary documentation
- Codex and Claude Code adapters
- GitHub Actions CI running `bash validate-harness.sh`

Notes:

- not a runtime
- not a sandbox
- not a semantic correctness guarantee
