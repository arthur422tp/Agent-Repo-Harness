# Agent Support Matrix

Agent-Repo-Harness is a repo-local framework for giving coding agents shared
context, scope boundaries, policy gates, and verification expectations.

## Supported Agents

Codex:
- Entrypoint: `AGENTS.md`
- Adapter assets: `adapters/codex/AGENTS.md`,
  `adapters/codex/codex-start-prompt.md`
- Notes: ask Codex to read `AGENTS.md`, inspect harness files, run preflight,
  respect `.agent/task.yml`, and run `scripts/agent-finish.sh`.

Claude Code:
- Entrypoint: `CLAUDE.md`
- Adapter assets: `adapters/claude-code/CLAUDE.md`, `.claude/skills/*`
- Notes: Claude Code can use project skills for harness startup, policy,
  verification, handoff, and subagent packets.

Superpowers-compatible agents:
- Entrypoint: skills
- Adapter assets: `skills/*`
- Notes: existing Superpowers-compatible skills remain supported and should not
  be removed.

Generic coding agents:
- Entrypoint: `AGENTS.md` or live prompt
- Adapter assets: `templates/AGENTS.md`, scripts, repo files
- Notes: generic agents can follow the files and scripts directly without
  adapter-specific skill support.

## Non-Goals

This repository does not provide:

- a full agent runtime
- an MCP server
- sandboxing
- guaranteed semantic correctness
- replacement workflow discipline for Superpowers

The harness can make expectations explicit and easier to verify, but it cannot
prove that an arbitrary code change is correct.
