# Agent-Repo-Guide To Agent-Repo-Harness Migration

This repository keeps the original Agent-Repo-Guide skills in place while introducing the lightweight Agent-Repo-Harness structure.

## Mapping

| Legacy skill | Harness replacement |
| --- | --- |
| `project-agent-docs` | `harness-entrypoint` + `repo-context-bootstrap` |
| `project-map-agent-md` | `repo-map-maintenance` |
| `update-agent-handoff` | `handoff-update` |

## Intent

- Keep the old skills available during migration.
- Move new installs toward the harness structure.
- Preserve the separation between stable repo context, planning, and handoff state.
- Add policy, verification, discoveries, and subagent context without replacing Superpowers.

## Recommended Use

- Existing users of the legacy skills can continue using them.
- New harness installs should prefer the `skills/` tree.
- Superpowers remains the workflow engine in both setups.

## Non-Goals

- no new runtime
- no MCP server
- no forced deletion of legacy content before migration is complete
