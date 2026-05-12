---
name: repo-context-bootstrap
description: Bootstrap repo-aware context by reading stable guidance, handoff
  state, policy, and obvious project markers.
---

# Repo Context Bootstrap

Initialize or refresh harness context inside a target project.

## Steps

1. Build compact context before broad source inspection.
2. Read installed entrypoints: `AGENTS.md`, `CLAUDE.md`, or adapter guidance that exists in the target repo.
3. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries.
4. Run `scripts/agent-preflight.sh` if available.
5. Inspect README files, manifests, entrypoints, tests, config, and infra files only when needed to verify missing or stale facts.
6. Create or refresh `agent.md` from concrete evidence.
7. Create or refresh `handoff.md` with current state only.
8. Create `docs/agent/known-issues.md` if repeated pitfalls exist.
9. Create or refresh scripts and `.agent` config if they are missing.
10. Mark uncertain items as `Inferred:` with the file or command that led to the inference.

## Hard Rules

- Keep output compact and factual.
- Prefer concise summaries and links over copying raw file contents into repo memory.
- Do not invent repo facts.
- Do not rebuild the repo map unless `repo-map-maintenance` is actually needed.
