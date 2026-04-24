---
name: |
  update-agent-handoff
description: |
  Update compact handoff state and patch canonical
  guidance only when architecture-significant facts changed.
---

# Update Agent Handoff

Migration note:
- Legacy handoff updater kept for compatibility.
- New installs should prefer `handoff-update`.
- See [../references/harness-migration.md](../references/harness-migration.md).

Update current-state guidance only after routing is complete.

## Shared Spec

- You MUST follow [../references/shared-spec.md](../references/shared-spec.md).
- You MUST treat handoff as current position only.

## Preconditions

- You MUST assume routing is already decided.
- You MUST read the canonical root guidance first.
- You MUST preserve the canonical filename.
- You MUST inspect changed files before touching canonical guidance.

## Workflow

1. Read canonical root guidance.
2. Inspect changed files.
3. Check high-priority global triggers.
4. Identify impacted modules and contracts.
5. Run the architecture significance decision block.
6. Patch `agent.md` ONLY if the decision block returns `YES`.
7. Otherwise update handoff only, or remove it if no useful state remains.
8. Link to planning instead of copying detailed next steps.

## Architecture Significance Decision Block

Return `YES` ONLY if one or more are true:

- repository tree or module boundaries changed
- entrypoint or startup path changed
- runtime dependency edge or data flow changed
- external contract changed
- tooling command changed with executable repo evidence
- risk map or skip zone changed
- an important `TODO:` or `Inferred:` fact is now `Verified:`

Return `NO` when changes are limited to:

- function internals
- local helpers
- renaming
- copy text
- test coverage only
- internal refactor without ownership, contract, or runtime boundary change
- new files that do not create a new module, boundary, or contract

## Architecture Evidence Rules

- Code-level dependency change is NOT architecture-level dependency change by itself.
- Internal refactor is NOT module ownership change by itself.
- Import paths are NOT runtime dependencies by themselves.
- Docs command mentions are NOT verified commands.
- New tests are NOT architecture evidence unless they reveal a new entrypoint, runtime boundary, external contract, or previously unknown structure.
- Shared type, DTO, schema, or contract changes MUST trigger elevated review.

Treat these as strong architecture evidence:

- bootstrap or startup registration
- router registration
- DI wiring
- manifest or workspace linkage
- schema or migration ownership
- generated client regeneration tied to contract changes
- auth, billing, permissions, secrets, deploy, or external integration wiring

## High-Priority Global Triggers

You MUST escalate to architecture-sensitive review when changed files include:

- workspace config
- package manifests or lockfiles
- CI or deploy config
- Docker, compose, or infra config
- env example or env schema
- migrations, schema, OpenAPI, GraphQL, protobuf, or generated client
- shared packages, common contracts, core bootstrap, or router registration
- auth, billing, permissions, secrets, or external integrations

These files may imply architecture, runtime, contract, or command changes even when the local directory diff looks small.

## Evidence Rules

- You MUST use the shared labels and promotion rules from [../references/shared-spec.md](../references/shared-spec.md).
- You MUST mention the verification source when possible.

## Handoff Schema

Keep ONLY:

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

## Handoff Rules

- `Progress` MUST capture only the most important delta since the related plan or prior session.
- `Next pointer` MUST be one short pointer only.
- `Related plan` MUST be a planning-doc path or `None`.
- You MUST NEVER keep logs, execution narratives, chronological notes, or multi-step plans.
- You MUST link to planning docs instead of copying detailed steps.

## Remove Handoff Rule

You MUST remove the handoff section entirely when:

- no meaningful current focus remains
- no useful progress delta remains
- no blocker remains
- no next-session pointer remains
- the remaining content is only stale plan text or history

## Output Constraints

- Patch ONLY affected lines or sections.
- NEVER rescan the full repo by default.
- NEVER rewrite the whole `agent.md` unless the file is unusable.
- Handoff output MUST stay under 12 lines of content.
- Handoff MUST contain at most one short pointer and one related-plan link.
- Canonical patch notes MUST stay under 40 lines unless multiple architecture edges changed at once.

## Final Checks

- canonical filename preserved
- no parallel full-content root guidance file
- `agent.md` patched only when decision block returned `YES`
- handoff contains no plan
- handoff removed if no useful state remains
