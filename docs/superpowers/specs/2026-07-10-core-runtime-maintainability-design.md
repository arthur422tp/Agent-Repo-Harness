# Core Runtime Maintainability Design

**Date:** 2026-07-10

**Status:** Approved design, pending implementation planning

## Goal

Reduce the cost and risk of changing the Agent-Repo-Harness finish path by
giving gate inventory, gate execution, shared shell mechanics, and summary
rendering distinct internal owners while preserving the installed public
runtime contract.

This design covers the first of three architecture initiatives:

1. core runtime maintainability;
2. packaging manifest and install contract;
3. validation selection and CI parallelism.

The latter two initiatives require separate design and implementation cycles.

## Context

The current runtime has strong behavior coverage and a stable public boundary,
but its internal responsibilities have accumulated in a few large scripts.
`templates/scripts/agent-finish.sh` owns command-line parsing, Git evidence,
resource limits, gate execution, status collection, Markdown rendering, JSON
rendering, episode rendering, and final exit behavior. Its strict and
best-effort branches also repeat the gate inventory.

Adding a finish gate therefore requires synchronized edits across the finish
entrypoint, task configuration and validation, evidence files, summary output,
tests, installed-shape fixtures, and documentation. This design does not change
that public contract. It creates internal boundaries so the runtime gate
inventory and execution order have one owner.

## Compatibility Standard

The refactor is contract-compatible rather than byte-for-byte compatible.

The following behavior must remain stable:

- public CLI options and invocation paths;
- exit codes and strict versus best-effort semantics;
- canonical gate execution order;
- result markers and evidence filenames;
- required Markdown summary rows, groups, and field meanings;
- required JSON keys, status values, and evidence paths;
- installed-target behavior and dependency requirements;
- the role of `scripts/agent-finish.sh` as the canonical completion boundary.

Internal functions, non-contract debug wording, and insignificant whitespace
may change. Tests must assert public fields and ordering without turning entire
outputs into brittle snapshots.

## Approaches Considered

### Shell-Native Incremental Extraction

Add small sourceable shell modules, lock current behavior with characterization
tests, and move one responsibility at a time. Keep the public shell entrypoints
stable throughout the migration.

This is the selected approach. It preserves the dependency-light installed
runtime and allows every extraction stage to remain independently releasable.

### Registry-First Data Model

Define the inventory in YAML, JSON, or TSV first and make runtime and tooling
consume it. This offers strong centralization but immediately introduces a
parser or generation workflow before module boundaries are proven.

### Runtime Rewrite

Rewrite the finish path in Python, Go, or Node. This would simplify some data
handling but would change runtime dependencies, error surfaces, startup
behavior, and the project's stability boundary. It is outside the current
product direction.

## Target Module Structure

The installed runtime will contain:

```text
scripts/
├── agent-finish.sh
├── agent-verify.sh
└── lib/
    ├── harness-common.sh
    ├── gate-registry.sh
    ├── finish-runner.sh
    └── finish-summary.sh
```

The source repository owns these files under `templates/scripts/`. Recursive
template installation must copy the library directory into installed targets.

### Public Finish Entrypoint

`agent-finish.sh` remains the stable public command. It owns:

- CLI parsing and usage output;
- repository and run-directory initialization;
- loading required internal modules by script-relative path;
- the top-level sequence of evidence collection, gate execution, resource
  evaluation, summary rendering, and final exit;
- the existing user-facing repair and evidence-location hints.

It must not own the list of individual gates or serialize Markdown and JSON
fields directly after the migration is complete.

### Shared Shell Mechanics

`harness-common.sh` owns dependency-free mechanics shared by the finish and
verification entrypoints:

- command availability checks;
- Python interpreter discovery;
- access to the existing shared configuration reader;
- run-local temporary-file creation;
- atomic final-file replacement;
- common error formatting that does not encode gate policy.

The library must run on Bash 3.2. It must not use associative arrays, namerefs,
`mapfile`, or external dependencies such as `jq` and `yq`.

### Gate Registry

`gate-registry.sh` is the single runtime inventory of finish gates. It declares
one ordered record per gate with:

- gate ID;
- command path;
- result filename;
- Markdown summary group;
- strict-mode arguments;
- best-effort-mode arguments;
- related task completion flag for validation and documentation coverage.

The registry uses Bash 3.2 indexed arrays. All parallel arrays must have the
same length, and the registry order is the canonical execution order.

Registry validation must reject duplicate IDs, duplicate result filenames,
empty required fields, unknown summary groups, and mismatched array lengths
before any gate runs. A malformed registry must not produce a finish summary
that could be mistaken for a valid run.

### Finish Runner

`finish-runner.sh` consumes the registry and owns:

- sequential gate execution;
- stdout and stderr capture;
- per-gate result-file creation;
- per-gate status collection;
- preservation of strict and best-effort behavior;
- accumulation of the overall finish result.

It does not render Markdown or JSON. Gate failures must still produce their
result evidence. One gate's output or status must not leak into the next gate.

### Finish Summary Renderer

`finish-summary.sh` consumes registry metadata, gate statuses, Git evidence,
resource results, and run metadata. It owns:

- `finish-summary.md` rendering;
- `finish-summary.json` rendering;
- required gate grouping and order;
- evidence-path fields;
- JSON escaping through the current supported Python path.

Episode summary rendering may move into this module only after the primary
Markdown and JSON extraction is green. The first extraction step must not move
episode rendering and gate rendering simultaneously.

Internal shell libraries are implementation details, not public APIs. The
stability contract must state that downstream repositories should invoke the
public scripts rather than source files under `scripts/lib/` directly.

## Runtime Data Flow

The finish lifecycle becomes:

1. parse the mode and locate the target repository;
2. source internal modules by path relative to the public entrypoint;
3. initialize and validate the ordered gate registry;
4. create the run directory and collect Git evidence;
5. execute every gate sequentially through the finish runner;
6. evaluate the resource envelope and existing episode metadata in their
   current relative order;
7. render Markdown and JSON summaries from the same registry and status data;
8. emit the existing completion or repair messaging;
9. return the existing strict or best-effort exit status.

The implementation plan must verify the exact current order of Git evidence,
gates, resource evaluation, episode handling, and summary writes before moving
code. The refactor must follow observed behavior rather than infer an order
from this high-level description.

## Error Handling

### Missing Modules

If an internal module is absent, the public entrypoint fails immediately with
the missing installed path. No gate executes and no successful finish marker is
emitted.

### Invalid Registry

Registry validation completes before gate execution. Invalid inventory fails
the command without creating a valid-looking summary.

### Gate Failure

The runner captures the failing gate output and writes the existing result
file. Strict mode remains blocking. Best-effort mode preserves its current
overall-result and exit behavior. No later gate receives the failed gate's
temporary variables or output.

### Evidence Write Failure

Temporary output is created inside the active run directory and finalized with
an atomic move. A failure to finalize a result file is an evidence failure and
must not be converted into a passing gate status.

### Summary Failure

A Markdown or JSON serialization failure prevents a successful finish result.
Previously written gate evidence remains available for diagnosis. A Markdown
summary alone must not be treated as overall success when required JSON output
failed.

### Interruption

Run-local temporary files may remain after interruption, but canonical result
and summary filenames must contain only fully finalized content. Cleanup may be
best effort; it must not hide the original failure.

## Migration Stages

### Stage 1: Characterization Contract

Add coverage for gate order, result filenames, Markdown rows and groups, JSON
keys and evidence paths, mode-specific exit behavior, and temporary
installed-target execution. No runtime extraction occurs in this stage.

### Stage 2: Common And Summary Extraction

Extract policy-free common helpers, then extract Markdown and JSON rendering.
The public entrypoint continues using its existing hard-coded gate calls until
the summary extraction is green.

Move shared command and Python discovery in `agent-verify.sh` only after its
existing verification-selection tests pass against the common module. Do not
move verification policy into the common library.

### Stage 3: Registry And Runner

Introduce the ordered registry and runner. Replace both strict and best-effort
hard-coded gate lists with iteration over the same inventory. Retain current
mode-specific arguments and failure semantics.

### Stage 4: Cleanup And Installed Validation

Remove dead entrypoint functions, classify the internal libraries in the
stability contract, synchronize installed-shape fixtures, and run source plus
temporary installed-target validation.

Each stage must pass the full repository validation and end in an independent
commit. A failed stage must be repairable without completing later stages.

## Test Strategy

### Registry Contract Tests

Tests validate required fields, uniqueness, array lengths, summary groups,
canonical order, and mode arguments. Static checks reject Bash features newer
than the supported baseline.

### Runner Tests

Fake gates cover pass, fail, mixed output, evidence-write failure, sequential
status isolation, strict behavior, and best-effort behavior.

### Summary Contract Tests

Assertions lock required Markdown rows and grouping, JSON keys and statuses,
evidence filenames, and gate order. Tests do not compare entire output files
when only non-contract formatting differs.

### Installed-Target Tests

Static install coverage asserts all internal libraries are copied. Temporary
installed targets execute strict and best-effort finish smoke cases. Fixtures
that manually copy `agent-finish.sh` or `agent-verify.sh` must copy their
internal dependencies as well.

The committed universal-minimal example must mirror the installed library
shape if it is maintained as a byte-for-byte installed fixture.

## Expected File Scope

Create:

- `templates/scripts/lib/harness-common.sh`;
- `templates/scripts/lib/gate-registry.sh`;
- `templates/scripts/lib/finish-runner.sh`;
- `templates/scripts/lib/finish-summary.sh`;
- `tests/harness/finish-runtime-modules.sh`.

Modify as required by tests and installed parity:

- `templates/scripts/agent-finish.sh`;
- `templates/scripts/agent-verify.sh`;
- `tests/harness/lib.sh`;
- `tests/harness/finish-examples.sh`;
- `tests/harness/resource-envelope.sh`;
- `tests/harness/static-install.sh`;
- `tests/harness/template-sync.sh`;
- `validate-harness.sh`;
- `docs/stability-contract.md`;
- the universal-minimal installed-shape example when parity requires it.

The implementation plan may narrow this list when live inspection proves a
file does not copy or assert finish runtime behavior. It must not expand into
packaging-manifest or validation-orchestration work.

## Completion Criteria

- the runtime gate inventory is declared once;
- the public finish entrypoint does not list individual gate invocations;
- Markdown and JSON serialization no longer live in the public entrypoint;
- current CLI, exit, order, marker, evidence filename, and summary contracts
  remain compatible;
- `agent-verify.sh` shares only policy-free mechanics;
- internal libraries are classified as non-public implementation details;
- source, committed installed-shape, and temporary installed-target validation
  agree;
- `bash validate-harness.sh` passes after every migration stage;
- generated `.agent/` runtime evidence remains untracked.

## Non-Goals

This initiative does not:

- create an installer manifest;
- add validation-suite selection or CI parallelism;
- change schemas or task flags;
- add, remove, or reorder gates;
- change verification-selection policy;
- rewrite the runtime in another language;
- revise README onboarding;
- reclassify public helper CLIs;
- make internal libraries supported downstream extension points.
