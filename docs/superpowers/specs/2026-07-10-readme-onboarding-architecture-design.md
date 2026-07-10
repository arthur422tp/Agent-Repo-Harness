# README Onboarding And Architecture Design

**Date:** 2026-07-10

**Status:** Approved design, pending implementation

## Goal

Turn the public README pair into a concise onboarding entrypoint for first-time
adopters while preserving the repository's existing contracts, bilingual
documentation parity, and honest runtime boundaries. Record the architectural
improvements discovered during the repository scan without implementing the
runtime refactors in this documentation task.

## Context

The repository already has strong subsystem test separation under
`tests/harness/`, a stable `validate-harness.sh` integration entrypoint, and
specialized documents for agent workflows, gate selection, stability, and
runtime boundaries. The public README has grown to more than 500 lines because
it repeats portions of those references alongside installation and onboarding
instructions.

The runtime is also accumulating coordination complexity. In particular,
`templates/scripts/agent-finish.sh` combines orchestration, gate execution, and
evidence rendering in one large script. That is a future architectural concern,
not a reason to widen this README-focused change into a runtime refactor.

## Audience And Success Criteria

The primary reader is a first-time adopter deciding whether and how to install
Agent-Repo-Harness into a repository.

The change succeeds when:

- a new user can move from product definition to an installed baseline and
  first finished task through one obvious reading path;
- greenfield and existing-project adoption remain equally visible;
- English and Traditional Chinese READMEs have matching section structure,
  commands, links, and public claims;
- detailed reference material remains discoverable through focused documents;
- the README does not claim sandboxing, runtime orchestration, or semantic
  correctness that the project does not provide;
- existing public CLI, schema, gate, and installation behavior does not change;
- repository document checks and the full harness validation pass.

## Approaches Considered

### 1. Onboarding-First Entry Point

Keep the README focused on installation, repository configuration, the first
task lifecycle, failure repair, adoption choice, and reference routing.

This is the selected approach because it reduces first-use cognitive load and
uses the repository's existing specialized documents instead of duplicating
them.

### 2. Role-Based README

Give first-time adopters and maintainers separate paths in the same README.
This would make maintenance lookup convenient but would retain much of the
current length and duplicate the role already served by reference documents.

### 3. Complete Lifecycle Manual

Retain nearly all current content and reorder it around the task lifecycle.
This would preserve maximum inline detail but would not solve the entrypoint's
size or information hierarchy problem.

## Documentation Architecture

The public documentation will use four layers with distinct responsibilities:

1. `README.md` and `README.zh-TW.md`: product definition, onboarding, first
   task, failure path, adoption choice, and reference navigation.
2. `docs/USAGE_WITH_AGENTS.md`: complete cross-agent lifecycle and operational
   usage.
3. `docs/agent/gate-guide.md`: verification profiles, gate profiles, decision
   rules, result meanings, and evidence requirements.
4. `docs/runtime-boundaries.md`: implemented guardrails and explicitly
   unsupported runtime or security boundaries.

`docs/stability-contract.md` remains the source of truth for stable,
intended-stable, and experimental public interfaces.

The README may summarize a lower layer, but it must link to that layer rather
than reproduce its complete reference material.

## README Information Architecture

Both language variants will use the same sequence.

### 1. Product Header

- State that Agent-Repo-Harness is a repo-local completion gate for AI coding
  agents.
- Summarize scope, policy, verification, and durable evidence.
- State that it is not a sandbox, full agent runtime, or semantic correctness
  guarantee.

### 2. Quick Start

- Preview installation with `--dry-run`.
- Install into a target repository.
- Review the installed files and commit a clean harness baseline.
- Keep one copy-ready command block.

### 3. Configure The Repository

- Put stable repository facts in `agent.md`.
- Put authoritative verification commands in `.agent/harness.yml`.
- Put protected paths and approval rules in `.agent/policy.yml`.
- Show one minimal repository-owned verification example.

### 4. Run The First Task

Use one numbered lifecycle:

1. read the installed agent entrypoint and durable context;
2. generate `.agent/task.yml` with `scripts/agent-task-profile.sh`;
3. run `scripts/agent-preflight.sh`;
4. implement within task scope;
5. run `scripts/agent-finish.sh`;
6. inspect `.agent/runs/<timestamp>/finish-summary.json`;
7. repair failed gates when necessary;
8. bind strict acceptance evidence when enabled;
9. update `handoff.md` before claiming completion.

The README will preserve the distinction between authoritative finish evidence
and the human-authored continuity handoff. Handoff freshness remains a workflow
expectation rather than an enforced finish gate.

### 5. When Finish Fails

- Do not claim completion.
- Read the failed result and evidence files.
- Follow `docs/agent/repair-failed-run.md`.
- Rerun the canonical finish gate after repair.
- Keep strict evidence binding as a short conditional step with a reference,
  rather than a full schema walkthrough.

### 6. Choose An Adoption Path

Present greenfield and existing or mid-development repositories as parallel
paths with matching structure.

Greenfield guidance will install the harness alongside the initial project
scaffold and establish verification early. Existing-project guidance will make
installation a separate reviewed baseline change and avoid mixing scaffold
files with unfinished product work.

### 7. Choose Verification And Gates

- Explain that repository-owned verification commands are authoritative.
- Explain that `task.verification_profile` selects a stage-appropriate command
  set and replaces the default required commands.
- Summarize Minimal, Standard, and selective High-Risk task profiles.
- Route matrices, flags, evidence requirements, and failure meanings to the
  Gate Guide.

### 8. Architecture And Boundaries

Explain the four main responsibility groups without enumerating every file:

- stable repository facts;
- current task state and policy;
- finish orchestration and configured gates;
- immutable per-run evidence and mutable continuity notes.

Identify `scripts/agent-finish.sh` as the canonical completion boundary and
link to runtime and stability references.

### 9. Examples And References

- Link the docs-only, strict-evidence bugfix, and high-risk policy examples.
- Link agent-specific usage and compatibility references.
- Keep short version, repository contents, and local validation information.

## Content Moved Out Of The README

The rewrite will remove repeated detail from the README, not remove project
capabilities. Specialized documents will remain responsible for:

- the exhaustive individual-check command list;
- full evidence schema examples;
- every optional evidence gate category and flag;
- platform-specific agent setup details;
- detailed production-readiness and runtime-boundary explanations;
- complete gate decision matrices and result meanings.

No new destination document is required because the repository already has a
focused home for each category.

## Future Runtime Architecture Recommendations

These recommendations are findings from the scan and are explicitly outside
the implementation scope of this task.

### Separate Finish Responsibilities

Split finish orchestration, shared gate execution, and evidence rendering into
focused units. Preserve `scripts/agent-finish.sh` as the stable public
entrypoint while reducing the amount of policy and formatting logic it owns.

### Introduce A Gate Capability Registry

Give each gate one declarative record containing its task flag, configuration
flag, script, result marker, evidence file, and reference link. Use the registry
to validate or generate repeated representations in schemas, profiles, finish
summaries, documentation, and consistency tests.

### Consolidate Shell Infrastructure

Centralize repeated handling for interpreter discovery, the shared YAML subset,
temporary files, empty arrays under `set -u`, result markers, and diagnostic
formatting. Keep the installed runtime dependency-light and Bash-compatible.

### Strengthen Architecture Contract Tests

Verify that every public task completion flag maps to a documented gate and
finish result, every public helper has a stability classification, and every
README entrypoint exists in an installed target.

## Implementation Scope

Expected content changes:

- modify `README.md`;
- modify `README.zh-TW.md` with matching structure and semantics;
- modify `tests/harness/doc-consistency.sh` only where assertions must follow
  renamed or consolidated README sections.

Process artifacts created before implementation:

- this design specification;
- a detailed implementation plan under `docs/superpowers/plans/`.

The task will not change runtime scripts, schemas, public CLI behavior, gate
semantics, installed templates, or generated `.agent/` runtime state.

## Error And Drift Handling

- Preserve all claims required by `tests/harness/doc-consistency.sh`, updating
  assertions only when their old wording encodes the superseded README layout.
- Do not weaken assertions that protect runtime-boundary honesty or installed
  entrypoint discoverability.
- Keep paths relative and repository-local so the document link checker can
  validate them.
- If the shorter README exposes missing detail in a destination document, make
  the smallest synchronized change to that existing document and its installed
  template mirror; do not reintroduce the detail into the README by default.
- Leave the existing untracked `.agent/` directory untouched.

## Verification

Run fresh verification after implementation:

```bash
git diff --check
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

The change is complete only when all three commands exit successfully and the
final diff contains no runtime behavior changes or generated `.agent/` state.
