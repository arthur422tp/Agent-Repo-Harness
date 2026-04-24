---
name: repo-map-maintenance
description: Build or patch stable repo guidance from concrete repository
  evidence.
---

# Repo Map Maintenance

Maintain `agent.md` as stable repo guidance only.

## Shared Rules

- Follow `Verified:`, `Inferred:`, and `TODO:` evidence thresholds.
- Use concrete repo evidence before promoting facts.
- Keep planning and handoff state out of `agent.md`.
- Update `agent.md` only when stable repo facts change.
- Do not duplicate handoff.

## Workflow

1. Check whether an existing `agent.md` is usable.
2. Scan only enough evidence to establish stable repo shape.
3. Patch first when the map is mostly right.
4. Rebuild only when the existing map is misleading or missing.
5. Keep the output navigational, not exhaustive.

## Keep `agent.md` Focused

Use these sections:

- `Project Overview`
- `Architecture Map`
- `Important Entrypoints`
- `Common Commands`
- `Verification`
- `Risk Areas`
- `Agent Rules`

## Hard Rules

- Do not invent repo structure.
- Do not store current task state in `agent.md`.
- Do not rewrite the whole file when a small patch is enough.
