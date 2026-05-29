# Runtime Boundaries

Agent-Repo-Harness is a repo-local completion harness. It gives agents
contracts, gates, and evidence requirements before they claim completion.

## Implemented

- Task scope checks against Git changes.
- Repo-local policy checks for high-risk paths.
- Repo-defined verification commands through `.agent/harness.yml`.
- Optional TDD, acceptance, review, subagent, and architecture evidence gates.
- Durable run evidence under `.agent/runs/<timestamp>/`.
- Machine-readable `finish-summary.json` beside the human-readable summary.
- A local resource envelope for finish duration and changed-file count.

## Not Implemented

- Filesystem sandboxing.
- Network sandboxing.
- Secret isolation.
- Agent-provider token accounting.
- Model-cost enforcement.
- Runtime tool orchestration outside local shell scripts.
- Semantic correctness guarantees beyond configured checks and evidence.

## Design Rule

Do not describe the harness as a sandbox, agent runtime, MCP server, or semantic
correctness guarantee. When stronger containment is required, run the harness
inside a separate sandbox, container, VM, worktree, or CI job that provides that
boundary.
