---
name: |
  project-agent-docs
description: |
  Use when routing repo guidance work between canonical maps,
  planning docs, and handoff state.
---

# Project Agent Docs

Route repo-guidance requests to the narrowest workflow.

## Core Principle

- `agent.md` is the map.
- Planning docs are navigation.
- Handoff is the current position.
- Do not mix them.

## Intent Routing

Use `$project-map-agent-md` for:

- first-time canonical guidance creation
- repo scan or onboarding after concrete repo evidence exists
- stable project-map updates when the current guidance is missing, unusable, or too wrong to patch safely

Use `$update-agent-handoff` for:

- session wrap-up or resume state
- compact current-focus updates
- checking whether changed files require a minimal `agent.md` patch
- pruning stale handoff state
- refreshing existing canonical guidance when it mostly exists but may be stale

Use `writing-plans` or another planning workflow for:

- implementation plans
- detailed next steps
- execution order
- file-by-file task breakdowns
- test plans

Use a planning or scaffolding workflow before repo-guidance skills when:

- the repo is still mostly an idea
- architecture or scope is still being decided
- there is no concrete evidence such as README, manifests, entry points, tests, infra, or schemas

## Decision Rules

- Choose one primary path by default.
- Prefer the narrowest path that answers the request.
- Repo guidance should link to plans, not absorb them.
- Handoff should point to a related plan, not restate it.
- Do not put session state into the stable `agent.md` body.
- Do not use handoff for multi-step planning.
- Do not duplicate target-skill schemas here.
- Default to patching existing canonical guidance before considering rebuild.
- Rebuild only when the current canonical guidance is missing, clearly broken, or so stale that patching is less reliable than remapping.

## Mixed Requests

- If the request is "create guidance for this repo", use `$project-map-agent-md`.
- If the request is "what are we doing now / update resume context", use `$update-agent-handoff`.
- If the request combines status plus detailed next steps, keep status in handoff and route the detailed steps to planning.
- If the request combines initial mapping plus end-of-session state, create the canonical map first, then add a minimal handoff only if current-state capture is actually needed.

## Conflict Resolution / Mixed Request Rules

When canonical guidance already exists but may be outdated:

- If the main need is to refresh architecture understanding, route to `$update-agent-handoff` first.
- Prefer patching over rebuilding by default.
- Escalate to `$project-map-agent-md` only when the existing canonical guidance is missing, clearly unusable, or materially misleading enough that targeted patching is not trustworthy.

When the request mixes "organize or refresh repo guidance" with "tell me what to do next":

- Handle repo guidance first.
- Keep the "next" part to a short pointer or link.
- Route detailed execution steps to planning.
- Do not absorb a detailed plan into `agent.md` or handoff.

When a planning doc already exists but handoff may be out of sync with real progress:

- Keep the planning doc as the source of future steps.
- Use handoff only for current focus, progress delta, blockers, and related-plan linkage.
- Do not overwrite handoff by copying planning content verbatim.
- Do not reinterpret unfinished planning steps as completed without fresh progress evidence.

When only a few files changed but they include high-impact files:

- Treat shared contracts, workspace config, CI, schema, migration, env template, generated client, bootstrap files, router registration, and infra config as architecture-sensitive.
- Prefer `$update-agent-handoff` for deeper significance assessment instead of assuming the change is local.
- Do not route purely by touched-file count.

When the repo has only vague idea text or insufficient evidence:

- Do not force `$project-map-agent-md` to build a full canonical map.
- Prefer planning or ask for concrete repo evidence first.

## Patch vs Rebuild Decision Table

Use this table when existing canonical guidance is present:

| Situation | Default action | Why |
| --- | --- | --- |
| Canonical guidance exists and is mostly accurate but stale in a few architecture areas | Patch via `$update-agent-handoff` | Preserve stable map structure and avoid unnecessary rewrite churn |
| Canonical guidance exists but handoff is stale or bloated | Patch or prune via `$update-agent-handoff` | This is a state-sync problem, not a remapping problem |
| Canonical guidance exists, but only commands or dependency labels are weak or outdated | Patch via `$update-agent-handoff` | Evidence can be tightened without rebuilding the map |
| Canonical guidance is missing entirely | Build via `$project-map-agent-md` | No patch target exists |
| Canonical guidance exists but is clearly broken, contradictory, or mapped to the wrong repo shape | Rebuild via `$project-map-agent-md` | Patch would preserve incorrect structure |
| Canonical guidance is so incomplete that key runtime boundaries, entrypoints, or ownership edges are absent | Rebuild via `$project-map-agent-md` | The file is not trustworthy as a canonical base |
| The repo itself still lacks concrete evidence | Do not rebuild yet | Planning or evidence gathering should happen first |
