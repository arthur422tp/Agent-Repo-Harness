---
name: project-agent-docs
description: Route canonical repo guidance work to mapping, handoff, or planning.
---

# Project Agent Docs

Route agent/Claude repo-guidance requests to the narrowest skill.

## Intent Routing

Use `$project-map-agent-md` for:

- repo scan, onboarding, bootstrap, or first project/idea setup
- creating the canonical root guidance file
- creating initial module guidance
- entry maps, read-first paths, tooling, dependencies, important files, unknowns

Use `$update-agent-handoff` for:

- session wrap-up or resume context
- active task, one-line next pointer, blockers, stale fact cleanup
- dependency TODO or verified command updates after work happened
- compact updates to an existing canonical guidance file

Use `writing-plans` for:

- implementation plans, test plans, file-by-file task breakdowns
- execution handoffs, commit sequences, or detailed next-step procedures

## Decision Rules

- Choose one primary path; do not chain skills by default.
- For mixed init + wrap-up requests, run `$project-map-agent-md` first, then `$update-agent-handoff` only if session state must be recorded.
- Repo guidance should link to plans, not absorb them.
- If a handoff note needs more than one short next pointer, route the detail to `writing-plans` and link it from guidance.
- Do not duplicate target-skill schemas here.
