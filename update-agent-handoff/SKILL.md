---
name: |
  update-agent-handoff
description: |
  Use when syncing compact current-state notes and assessing whether
  changed files require canonical guidance updates.
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
4. Check for high-priority global triggers before narrowing to local modules.
5. From changed files, identify impacted modules.
6. Assess architecture significance.
7. If architecture significance is `yes`, patch `agent.md` minimally.
8. If architecture significance is `no`, update only the handoff section or do nothing.
9. Read module guidance only if the changed files or impacted modules require it.
10. Remove stale or completed handoff state after verification.
11. Link to a planning document when details exist elsewhere.

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

## Architecture Significance Calibration

Use these rules to avoid over-updating canonical guidance:

- Code-level dependency change does not automatically mean architecture-level dependency change.
- Internal refactor does not automatically mean module ownership change.
- A new file does not automatically mean a new module.
- New tests usually do not require `agent.md` updates unless they reveal a new entry point, runtime boundary, external contract, or previously unknown structure.
- A command mentioned in docs is not a verified command.
- Import relationships do not automatically equal runtime dependencies.
- Prioritize runtime evidence such as config wiring, DI wiring, router registration, startup path, schema ownership, and external integrations over file adjacency.
- Shared type, DTO, schema, or contract changes require elevated review and should not be judged only by the touched directory.
- If the change only affects function internals, local helpers, naming, test coverage, or copy text, usually do not update `agent.md`.

Treat the following as stronger architecture evidence than ordinary code edits:

- bootstrap or startup registration
- router or plugin registration
- manifest or workspace linkage
- schema ownership or migrations
- external integration wiring
- command definitions in executable repo config

## High-Priority Global Triggers

Escalate to architecture-sensitive review when changed files hit any of these areas:

- workspace config
- package manifests or lockfiles
- CI or deploy config
- Docker, compose, or infra config
- env example or env schema
- migrations, schema, OpenAPI, GraphQL, protobuf, or generated client
- shared packages, common contracts, core app bootstrap, or router registration
- auth, billing, permissions, secrets, or external integrations

These files may imply architecture, runtime, contract, or command changes even when the local directory diff looks small.

Do not stop at the nearest touched folder when one of these triggers is present. Review the related runtime boundary, ownership edge, or contract surface before deciding whether `agent.md` changes.

## Evidence Thresholds

Use evidence labels as a method, not formatting:

- `Verified command`: only if observed in executable repo evidence such as package scripts, Makefile, task runner config, CI invocation, or directly executed and confirmed. Mention the source of verification when possible.
- `Inferred command`: docs mention only, or a conventional guess from framework or tooling.
- `Verified dependency edge`: runtime evidence such as router wiring, bootstrap registration, DI config, manifest or workspace linkage, schema ownership, external contract reference, or runtime config.
- `Inferred dependency edge`: import path, naming convention, directory convention, or weak structural hints only.
- `Verified contract change`: concrete schema, migration, generated client, API spec, config, or runtime registration evidence confirms the contract moved.
- `Inferred contract change`: naming or colocated files suggest a contract edge, but ownership or runtime usage is not yet proven.

## Repo Not Ready For Mapping

If the repo is still a bare folder, only contains vague idea text, or lacks concrete evidence such as manifests, README, entry points, tests, config, or schema files:

- do not rebuild or fabricate a full canonical map from pure intention
- limit updates to handoff or explicit TODO notes
- route full mapping work back to concrete repo evidence first

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
- `Progress`: only the most important delta since the related plan or prior session
- `Next pointer`: one short pointer, not a multi-step plan
- `Blockers`: unresolved blockers or `None`
- `Related plan`: planning doc path or `None`

Do not include:

- long background explanation
- historical logs
- detailed ordered steps
- commit-style chronological notes
- execution narratives
- copied planning detail when a plan document already exists

## Anti-Bloat Rules

- Keep only next-session-relevant state.
- Do not restate stable repo-map content unless it changed.
- Replace stale facts instead of appending history.
- Keep handoff shorter than the map.
- Preserve `Verified:`, `Inferred:`, and `TODO:` labels when touching canonical facts.
- If a handoff needs more than one short next pointer, move the detail to planning and link it.
- If detailed next steps already exist, link to the planning doc instead of copying them into handoff.

## When To Remove The Handoff Section Entirely

Remove the handoff section instead of updating it when one or more of these is true:

- there is no meaningful current focus, progress delta, blocker, or next-session pointer left
- the last session is complete and no handoff state would help the next model
- the remaining content is only history log, execution narrative, or stale planning detail
- every useful next step already lives in a planning doc and no current-state delta remains

If only one line remains useful, keep the section but prune everything else.

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
