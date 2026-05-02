# Agent-Repo-Harness

See [README.md](README.md). The main README is now maintained in English while
the project evolves into a universal repo-local harness core with adapters for
Codex, Claude Code, Superpowers-compatible agents, and generic coding agents.

Use `scripts/agent-finish.sh` as the canonical completion gate; it writes
durable run evidence under `.agent/runs/<timestamp>/`.
