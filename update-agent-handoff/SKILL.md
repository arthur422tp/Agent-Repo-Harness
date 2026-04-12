---
name: update-agent-handoff
description: Use when syncing compact current-state notes and assessing whether changed files require canonical guidance updates.
---

# Update Agent Handoff

Update only current-state guidance and patch `agent.md` only when architecture-significant facts changed.

## Core Principle

- `agent.md` is the map.
- Planning docs are navigation.
- Handoff is the current position.
- Do not mix them.

## Boundary

Use this skill for:

- session wrap-up or resume state
- current focus
- concise progress delta
- one-line next pointer
- blockers
- linking to the relevant planning doc
- deciding whether changed files require a minimal `agent.md` patch

Do not use this skill for:

- initial repo mapping
- full repo rescans
- implementation plans
- test plans
- chronological logs

## Workflow

1. Read the canonical root guidance file first. Supported names: `agent.md`, `AGENT.md`, `AGENTS.md`, `claude.md`, `CLAUDE.md`.
2. Preserve the canonical filename. Do not create a parallel full-content root guidance file.
3. Inspect changed files first.
4. From changed files, identify impacted modules.
5. Assess architecture significance.
6. If architecture significance is `yes`, patch `agent.md` minimally.
7. If architecture significance is `no`, update only the handoff section or do nothing.
8. Read module guidance only if the changed files or impacted modules require it.
9. Remove stale or completed handoff state after verification.
10. Link to a planning document when details exist elsewhere.

## Architecture Significance Gate

Update `agent.md` only when one or more of these changed:

1. repository tree or module boundaries
2. entry points or startup path
3. cross-module dependencies or data flow
4. external contracts such as APIs, schemas, migrations, integrations
5. tooling commands or package-manager evidence
6. risk map or skip zones
7. an important `TODO:` or `Inferred:` fact that is now verified and belongs in canonical guidance

If none of the above changed:

- do not update `agent.md`
- update only handoff if next-session state matters
- otherwise do nothing

## Minimal Patch Rules

- Do not do a full repo scan by default.
- Prioritize changed files, adjacent impacted modules, and the existing canonical guidance.
- Patch only the affected lines or sections.
- Do not rewrite the entire `agent.md` unless the current file is unusable.
- Keep stable project-map content stable.

## Handoff Section Schema

Keep the handoff short and state-only:

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

### Handoff Rules

- `Current focus`: the current main work item
- `Progress`: only the most important delta
- `Next pointer`: one short pointer, not a plan
- `Blockers`: unresolved blockers or `None`
- `Related plan`: planning doc path or `None`

Do not include:

- long background explanation
- historical logs
- detailed ordered steps
- commit-style chronological notes

## Anti-Bloat Rules

- Keep only next-session-relevant state.
- Do not restate stable repo-map content unless it changed.
- Replace stale facts instead of appending history.
- Keep handoff shorter than the map.
- Preserve `Verified:`, `Inferred:`, and `TODO:` labels when touching canonical facts.
- If a handoff needs more than one short next pointer, move the detail to planning and link it.

## Quality Checklist

Before finishing, verify:

- the canonical root guidance filename was preserved
- no parallel full-content guidance file was created
- changed files were assessed before any canonical update
- `agent.md` was updated only if the architecture-significance gate passed
- any `agent.md` edit was a minimal patch
- the handoff follows the minimal schema above
- the handoff contains no detailed plan
- `Related plan` points to a planning doc or `None`
