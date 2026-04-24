---
name: repo-context-bootstrap
description: Bootstrap repo-aware context by reading stable guidance, handoff
  state, policy, and obvious project markers.
---

# Repo Context Bootstrap

Initialize or refresh harness context inside a target project.

## Steps

1. Inspect README files, manifests, entrypoints, tests, config, and infra files.
2. Run `scripts/agent-preflight.sh` if available.
3. Create or refresh `agent.md` from concrete evidence.
4. Create or refresh `handoff.md` with current state only.
5. Create `docs/agent/known-issues.md` if repeated pitfalls exist.
6. Create or refresh scripts and `.agent` config if they are missing.
7. Mark uncertain items as `TODO:` or `Inferred:`.

## Hard Rules

- Keep output compact and factual.
- Do not invent repo facts.
- Do not rebuild the repo map unless `repo-map-maintenance` is actually needed.
