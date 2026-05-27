# Public Packaging

Use this checklist when presenting Agent-Repo-Harness as an adoptable public
repository and when preparing its initial public release.

## Recommended GitHub Repository Description

Repo-local completion gate for AI coding agents.

## Recommended GitHub Topics

- `ai-agents`
- `coding-agents`
- `codex`
- `claude-code`
- `agentic-coding`
- `developer-tools`
- `repo-automation`
- `shell`

## v0.1.0 release checklist

- [ ] CI is passing.
- [ ] `VERSION` is `0.1.0`.
- [ ] `CHANGELOG.md` has a `v0.1.0` entry.
- [ ] `README.md` has a CI badge, Quick Start, What It Is Not, Platform Support, Verification Strategy, and Guardrails section.
- [ ] `install-agent-harness.sh` prints the short 3-step next path.
- [ ] The default TDD evidence is opt-in.
- [ ] `bash validate-harness.sh` passes locally.
- [ ] GitHub release notes are copied or summarized from `CHANGELOG.md`.

## Before Publishing

- [ ] Set the GitHub description.
- [ ] Set the GitHub topics.
- [ ] Create the GitHub release tag `v0.1.0`.
- [ ] Verify the README renders correctly on GitHub.
- [ ] Verify the CI badge points to `.github/workflows/ci.yml`.
