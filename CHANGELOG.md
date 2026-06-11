# Changelog

## Unreleased

No unreleased changes.

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
