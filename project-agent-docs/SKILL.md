---
name: |
  project-agent-docs
description: |
  Route repo-guidance requests between canonical maps,
  planning docs, and handoff state.
---

# Project Agent Docs

Act as the ONLY routing authority for repo-guidance work.

## Core Model

- `agent.md` is the map.
- Planning docs are navigation.
- Handoff is the current position.
- NEVER mix them.

## Router Contract

- You MUST choose exactly one primary path first.
- You MUST route before any mapping or handoff work starts.
- You MUST keep routing logic here only.
- Other repo-guidance skills MUST execute, not re-route.
- If the request is ambiguous, you MUST apply the ordered rules below and pick the first match.

## Ordered Routing Precedence

1. If the request asks for implementation steps, test plan, execution order, or file-by-file work, route to planning. Do NOT use repo-guidance skills as the primary path.
2. If the repo lacks concrete evidence such as README, manifests, entrypoints, tests, config, infra, or schema files, route to planning or evidence gathering. Do NOT build a canonical map.
3. If no canonical root guidance exists, route to `$project-map-agent-md`.
4. If canonical guidance exists and the request is about current status, blockers, resume context, or concise next-session state, route to `$update-agent-handoff`.
5. If canonical guidance exists and the request is about refreshing architecture understanding, route to `$update-agent-handoff` first.
6. If canonical guidance exists but is clearly broken, contradictory, mapped to the wrong repo shape, or too incomplete to trust, route to `$project-map-agent-md`.
7. If the request mixes repo guidance and next steps, route repo guidance first. Keep the next-step output to a short pointer or plan link only.
8. If changed files are few but touch shared contracts, workspace config, CI, schema, migrations, env templates, generated clients, bootstrap, router registration, auth, billing, permissions, secrets, deploy, or external integrations, route to `$update-agent-handoff` for architecture-sensitive review.
9. If the request combines initial mapping and end-of-session state, route to `$project-map-agent-md` first, then allow a minimal handoff only if current-state capture is still necessary.

## Patch vs Rebuild Table

| Condition | Route | Action |
| --- | --- | --- |
| Canonical guidance is missing | `$project-map-agent-md` | Build |
| Canonical guidance exists and is mostly right but stale | `$update-agent-handoff` | Patch |
| Canonical guidance exists and only handoff is stale or bloated | `$update-agent-handoff` | Patch or prune |
| Canonical guidance exists and only commands, edges, or labels need stronger evidence | `$update-agent-handoff` | Patch |
| Canonical guidance exists but is structurally wrong or misleading | `$project-map-agent-md` | Rebuild |
| Canonical guidance exists but key runtime boundaries or ownership edges are absent | `$project-map-agent-md` | Rebuild |

## Mixed-Request Rules

- Planning docs MUST remain the source of future steps.
- Handoff MUST record only current focus, progress delta, blockers, and related plan.
- `agent.md` MUST stay stable and MUST NOT absorb planning or session logs.
- If detailed next steps already exist, you MUST link to planning instead of copying them.
- If handoff and planning disagree, planning remains future intent and handoff records only current delta.

## Fail-Safe Rules

- You MUST default to patch before rebuild when a safe patch target exists.
- You MUST NEVER route by touched-file count alone.
- You MUST NEVER use handoff as a planning document.
- You MUST NEVER use `project-map-agent-md` to map a repo from pure intention.
- You MUST NEVER let detailed plan content enter `agent.md`.

## Output

- Output ONLY:
  - chosen primary path
  - one-sentence reason
  - optional secondary pointer only if the request is mixed
- Output MUST stay under 8 lines.
