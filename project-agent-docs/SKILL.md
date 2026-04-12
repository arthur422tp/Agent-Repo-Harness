---
name: project-agent-docs
description: Use when routing repo guidance work between canonical maps, planning docs, and handoff state.
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
- stable project-map updates when the current guidance is missing or unusable

Use `$update-agent-handoff` for:

- session wrap-up or resume state
- compact current-focus updates
- checking whether changed files require a minimal `agent.md` patch
- pruning stale handoff state

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

## Mixed Requests

- If the request is "create guidance for this repo", use `$project-map-agent-md`.
- If the request is "what are we doing now / update resume context", use `$update-agent-handoff`.
- If the request combines status plus detailed next steps, keep status in handoff and route the detailed steps to planning.
- If the request combines initial mapping plus end-of-session state, create the canonical map first, then add a minimal handoff only if current-state capture is actually needed.
