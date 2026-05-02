# Agent-Repo-Harness

See [README.md](README.md). The main README is now maintained in English while
the project evolves into a universal repo-local harness core with adapters for
Codex, Claude Code, Superpowers-compatible agents, and generic coding agents.

Use `scripts/agent-finish.sh` as the canonical completion gate; it writes
durable run evidence under `.agent/runs/<timestamp>/`.

TDD evidence is required only when `.agent/task.yml` sets
`completion.requires_tdd_evidence: true`; in that case fill
`.agent/tdd-evidence.yml` before finishing.

Subagent packets are optional controller-agent to subagent handoff files. Fill
`.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh` only
when delegating precise context to a fresh subagent; this is not part of
`scripts/agent-finish.sh` yet.
