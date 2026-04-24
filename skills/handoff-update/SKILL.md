---
name: handoff-update
description: Update current-task state and patch stable guidance only when
  repo-significant facts changed.
---

# Handoff Update

Update `handoff.md` as current-task state only.

Use `handoff.md` for repo state handoff, not as a substitute for repeated
workflow instructions in the prompt.

## Workflow

1. Read `agent.md` before touching `handoff.md`.
2. Inspect changed files and current progress.
3. Update `handoff.md` with only:
   - current task
   - current state
   - confirmed facts
   - changed files
   - verification result
   - open issues
   - next recommended step
4. Patch `agent.md` only if stable repo facts changed.
5. Update after meaningful state changes, blockers, verification changes, or
   architecture-sensitive changes.

## Stability Gate

Patch `agent.md` when changes affect:

- entrypoints
- module boundaries
- shared contracts
- verification commands
- high-risk areas

Do not patch `agent.md` for local implementation details only.

## Hard Rules

- `handoff.md` must not become a plan.
- Keep reusable workflow instructions in skills, not in `handoff.md`.
- Keep it concise enough to resume work quickly.
- Link to plans instead of copying long execution details.
- Do not duplicate the full repo map in handoff.
