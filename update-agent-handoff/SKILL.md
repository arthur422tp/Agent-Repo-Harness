---
name: update-agent-handoff
description: Update compact state in existing canonical guidance only.
---

# Update Agent Handoff

Update existing canonical repo guidance so the next session can resume. Do not create repo maps or implementation plans.

## Boundary

Use this skill only for compact state updates:

- session wrap-up or resume note
- current active task
- one-line next pointer
- dependency TODO or verified command update
- stale fact cleanup
- blocker or decision needed

Use `writing-plans` for implementation plans, test plans, file-by-file execution, code snippets, commit sequences, or detailed procedures.

## Workflow

1. Read the canonical root guidance file first. Supported names: `agent.md`, `AGENT.md`, `AGENTS.md`, `claude.md`, `CLAUDE.md`.
2. Preserve the canonical filename; do not create parallel full-content root guidance. If a secondary filename is needed, keep it as a short pointer only.
3. Read module guidance only if the session touched that module.
4. Update only changed facts, active task, blockers, dependency TODOs, verified commands, and one-line next pointer.
5. Remove stale or completed state after verification.
6. Prefer incremental edits; do not rewrite unrelated sections.
7. Link to a `writing-plans` document when detailed planning exists or is needed.

## Reference Loading

- If update shape is uncertain, read `references/handoff-example.md` for a minimal before/after example.

## Handoff Section Schema

- `Last updated`: date.
- `Current active task`: current task or `None`.
- `Changed this session`: terse factual summary only.
- `Read first next session`: paths only.
- `Next recommended step`: one short pointer, not a plan.
- `Blockers / decisions`: unresolved items only.
- `Related plan`: path, if any.

## Anti-Bloat Rules

- Keep only next-session-relevant state.
- Do not restate stable repo-map content unless it changed.
- Do not preserve reasoning history, chronological logs, or completed work unless needed to avoid repeat work.
- Keep handoff shorter than the repo map.
- Preserve evidence labels; do not promote `Inferred:` or `TODO:` items to `Verified:` without proof.

## Dependency / Module Updates

Update dependency notes only when work revealed new manifests, lockfiles, package-manager evidence, verified/unverified commands, missing packages, unclear runtime versions, conflicts, or risky/outdated deps.

Update module guidance only for touched modules or newly discovered module-specific risk: local active task, one-line next pointer, dependency notes, generated files, schemas, migrations, external contracts, or safety boundaries.

## Maintenance Policy

- Rewrite the handoff section only when its current shape is stale, contradictory, or too noisy to update safely.
- Append a new fact only when it is next-session-relevant and not already captured elsewhere.
- Replace stale facts instead of preserving historical notes.
- Prune completed tasks, resolved blockers, outdated next steps, and chronological logs after verification.
- Keep stable repo-map content in the map sections; keep temporary state in the handoff section.
- If a handoff grows into multiple ordered tasks, link to a planning document or use `writing-plans` instead.

## Quality Checklist

Before finishing, verify:

- The canonical root guidance filename was preserved.
- No parallel full-content root guidance file was created.
- The handoff is shorter than the repo map.
- The handoff contains only next-session-relevant state.
- `Verified:`, `Inferred:`, and `TODO:` labels were preserved and not promoted without evidence.
- Detailed implementation plans, code snippets, commit sequences, and test plans were not added.
- `Read first next session` contains paths only.
- `Next recommended step` is one short pointer, not a multi-step plan.
