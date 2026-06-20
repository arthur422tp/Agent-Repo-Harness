# Harness Ergonomics And Simplification Design

## Goal

Reduce the cognitive cost of adopting and operating Agent-Repo-Harness without
removing existing capabilities or introducing another configuration layer.

## Scope

This phase reorganizes documentation and the human-readable finish summary. It
does not add completion flags, evidence gates, schemas, runtime profiles, or
provider integrations. Existing task contracts, gate behavior, evidence files,
and machine-readable finish output remain compatible.

## Architecture

The harness keeps its existing execution model. Tasks continue to select gates
through the current `.agent/task.yml` completion flags, and
`scripts/agent-finish.sh` continues to run the same commands in the same order.

The simplification is delivered through two presentation layers:

1. A canonical gate guide that explains when each existing gate should be used.
2. A grouped human-readable finish summary that makes core checks, optional
   evidence, and final verification easier to scan.

The three recommended profiles are documentation-only presets. They do not add
a `profile` field, precedence rules, automatic flag mutation, or migration
requirements.

## Canonical Gate Guide

Create `docs/agent/gate-guide.md` as the single detailed reference for gate
selection and evidence requirements.

For every completion flag or finish check, the guide should state:

- gate/check name
- `.agent/task.yml` flag, when one exists
- default behavior
- required evidence
- when to enable it
- when not to enable it
- what a failure means
- command used to diagnose or validate it

Other public and installed documentation should summarize the workflow and
link to the gate guide instead of duplicating full gate instructions.

## Documentation-Only Profiles

The gate guide should define three recommended profiles.

### Minimal

Use for small, low-risk maintenance work.

- scope check
- policy check
- repository verification
- handoff update expectation

All optional evidence gates remain disabled unless the task has a specific
reason to enable one.

### Standard

Use for normal feature, bug-fix, and refactoring work.

- all Minimal checks
- TDD evidence for features, bug fixes, refactors, and behavior changes
- acceptance evidence when the task has explicit user-visible criteria
- review evidence when independent review is required

### High-Risk

Use for security-sensitive, architectural, release-critical, delegated, or
environment-sensitive work.

- all Standard checks
- architecture evidence for design-risk changes
- command ledger evidence for important replayable local commands
- sandbox verification for isolated final verification
- subagent evidence when delegated execution must be proven
- failure attribution for repaired or failure-prone work
- intervention records for material approvals, overrides, or manual actions

The profile examples should show existing `.agent/task.yml` flags. They must
not imply that the harness reads a profile name or changes flags automatically.

## README And Usage Structure

`README.md` should remain the public product entrypoint, but its main path
should focus on:

- what the harness is and is not
- three-step installation and first finish run
- the normal task workflow
- a short profile chooser
- evidence versus handoff
- runtime and sandbox boundaries
- links to detailed guides

Detailed per-gate requirements should move to or be consolidated in
`docs/agent/gate-guide.md`.

`docs/USAGE_WITH_AGENTS.md` should focus on agent-specific lifecycle guidance,
context loading, delegation, and adapter use. It should link to the canonical
gate guide for detailed gate selection.

Installed entrypoints and local skills should contain concise navigation and
commands, not copies of the complete gate catalog.

## Finish Summary Grouping

The human-readable `finish-summary.md` should group its existing rows under
three headings.

### Core Guardrails

- `check-agent-md`
- `check-scope`
- `check-policy`

### Optional Evidence

- `check-tdd-evidence`
- `check-acceptance`
- `check-review-evidence`
- `check-architecture-evidence`
- `check-failure-attribution`
- `check-interventions`
- `check-command-ledger`
- `check-sandbox-evidence`
- `check-subagent-evidence`

### Verification And Limits

- `validate-episode`
- `agent-verify`
- `resource-envelope`

The underlying gates should run in their existing order. Grouping affects only
the Markdown renderer.

## Compatibility Contract

The following must remain unchanged:

- `finish-summary.json` top-level keys
- JSON gate names, order, exit statuses, and evidence paths
- gate execution order
- `.agent/task.yml` defaults and flag names
- result markers such as `AGENT_FINISH_RESULT`
- evidence filenames and directories
- installer behavior
- strict and best-effort semantics

The Markdown summary must continue to include timestamp, mode, command, run
directory, overall result, every gate's exit status and evidence path, changed
files, diff stat, next action, and final result marker.

## Error Handling

Documentation profiles should be described as recommendations, not executable
configuration. Examples must use only existing flags and supported values.

If a completion flag exists in the task template but is absent from the gate
guide, repository validation should fail. If the guide names a nonexistent
flag, repository validation should also fail.

Markdown summary grouping must not suppress failed or skipped checks. Every
existing row must appear exactly once in the grouped summary.

## Testing Strategy

Implementation should use the existing shell validation suites.

Required coverage:

- `tests/harness/lib.sh` requires all three summary group headings
- every existing gate row appears exactly once in `finish-summary.md`
- `assert_finish_json_contract()` continues to validate the unchanged JSON
  gate list and ordering
- `tests/harness/doc-consistency.sh` requires the gate guide and three profiles
- every completion flag in `templates/.agent/task.yml` is represented in the
  guide
- README, usage docs, installed entrypoints, and verification skill link to the
  gate guide where their workflows discuss gate selection
- runtime boundary statements remain present
- document links pass
- installed-target finish smoke passes
- source checkout audit passes

Final verification should include:

- `bash validate-harness.sh`
- `bash templates/scripts/check-doc-links.sh .`
- an installed-target `scripts/agent-finish.sh --best-effort` run
- `bash templates/scripts/agent-audit.sh`

## Non-Goals

This phase does not:

- remove gates or evidence contracts
- change default completion flags
- add a runtime profile engine
- add automatic task classification
- add new finish gates
- add provider-native tracing, token accounting, or cost enforcement
- turn the harness into a runtime, orchestrator, or sandbox

## Acceptance Criteria

- Users can select Minimal, Standard, or High-Risk guidance without learning
  every gate first.
- `docs/agent/gate-guide.md` is the canonical detailed gate reference.
- README and usage documentation contain less duplicated gate detail.
- `finish-summary.md` groups checks into three scan-friendly sections.
- `finish-summary.json` remains contract-compatible.
- No completion flags, gates, schemas, or profile runtime behavior are added.
- Full validation, doc links, installed-target smoke, and audit pass.
