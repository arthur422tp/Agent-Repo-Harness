# Agent-Repo-Harness

See [README.md](README.md). The main README is now maintained in English while
the project evolves into a universal repo-local harness core with adapters for
Codex, Claude Code, Superpowers-compatible agents, and generic coding agents.

## Superpowers Integration

Agent-Repo-Harness is designed to work alongside Superpowers. Superpowers
provides workflow discipline; this harness provides repo-local contracts,
gates, and evidence.

See [docs/superpowers-integration.md](docs/superpowers-integration.md).

Use `scripts/agent-finish.sh` as the canonical completion gate; it writes
durable run evidence under `.agent/runs/<timestamp>/`.

TDD evidence is required only when `.agent/task.yml` sets
`completion.requires_tdd_evidence: true`; in that case fill
`.agent/tdd-evidence.yml` before finishing.

Acceptance and review evidence are also task opt-ins. Fill
`.agent/acceptance.yml` only when
`completion.requires_acceptance_check: true`, and fill `.agent/review.yml` only
when `completion.requires_review_evidence: true`.

Subagent packets are optional controller-agent to subagent handoff files. Fill
`.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh` only
when delegating precise context to a fresh subagent; this is not part of
`scripts/agent-finish.sh` yet.
