# Runtime Boundaries

Agent-Repo-Harness is a repo-local completion harness. It gives agents
contracts, gates, and evidence requirements before they claim completion.

## Implemented

- Task scope checks against Git changes.
- Repo-local policy checks for high-risk paths.
- Repo-defined verification commands through `.agent/harness.yml`.
- Optional TDD, acceptance, review, architecture, and subagent evidence gates.
- Durable run evidence under `.agent/runs/<timestamp>/`.
- Machine-readable `finish-summary.json` beside the human-readable summary.
- Optional episode package metadata through `.agent/episode.yml` and generated
  `episode-summary.json` evidence.
- Optional failure-attribution and intervention evidence gates controlled by
  `.agent/task.yml` completion flags.
- Local entropy audit reports through `scripts/agent-audit.sh`.
- A local resource envelope for finish duration and changed-file count.
- Sandbox verification evidence from an external Docker or Podman runner when
  configured.

## Not Implemented

- Filesystem sandboxing.
- Network sandboxing.
- Secret isolation.
- Complete sandbox security independent of the configured external runner.
- Per-tool runtime interception.
- Network allowlists beyond first-version disabled or host modes.
- Secret manager integration.
- Agent-provider token accounting.
- Model-cost enforcement.
- Runtime tool orchestration outside local shell scripts.
- Full tool-call replay outside local script evidence.
- Provider-native trace capture unless an external runtime supplies it.
- Semantic correctness guarantees beyond configured checks and evidence.

## Design Rule

Do not describe the harness as a sandbox, agent runtime, MCP server, or semantic
correctness guarantee. When stronger containment is required, run the harness
inside a separate sandbox, container, VM, worktree, or CI job that provides that
boundary.
