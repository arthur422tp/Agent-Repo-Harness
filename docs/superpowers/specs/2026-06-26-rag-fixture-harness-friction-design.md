# RAG Fixture Harness Friction Design

## Goal

Use the completed contract RAG fixture to measure Agent-Repo-Harness adoption
friction in a complete High-Risk workflow, then make only the smallest
evidence-backed improvements needed to reduce repeated verification or
gate-selection friction.

## Purpose

The RAG fixture now gives the harness a deterministic reference repository
with a realistic `src/` Python layout, application tests, security risk,
evaluation cases, and Minimal, Standard, and High-Risk adoption tasks.

The next phase should use that fixture as a measuring instrument. The work is
not to add more harness capability by default. It is to learn where the current
harness is still confusing, environment-sensitive, or costly during adoption,
then decide whether the right response is documentation, fixture configuration,
or a narrowly scoped harness behavior change.

## Scope

Included:

- one complete High-Risk adoption flow for `examples/rag-contract-system/`
- evidence for review, architecture, command ledger, sandbox, TDD, acceptance,
  and repository verification in an installed temporary target
- explicit measurement of each enabled gate's value and cost
- a clearer decision for the `PYTHONPATH=src` and host `pytest` discovery
  friction already observed by the Standard scenario
- updates to the RAG adoption report with separated application defects and
  harness friction
- minimal docs, fixture configuration, or verification ergonomics improvements
  only when the measured flow proves the need

Excluded:

- new completion gates
- new `.agent/task.yml` flags
- a profile engine or automatic profile selector
- new schemas or migration requirements
- new runtime, sandbox, orchestration, tracing, or provider integration
- package installation for the RAG fixture
- broad README or guide rewrites unrelated to measured adoption friction

## Design Principle

Measure first, change second.

The harness already has enough completion gates to express Minimal, Standard,
and High-Risk workflows. This phase should not expand the gate surface. It
should validate whether the existing gates are understandable and useful when
applied to a realistic high-risk task.

Any improvement must be traceable to one of these evidence sources:

- the existing RAG adoption report
- the new complete High-Risk adoption run
- a failing or noisy validation command
- a documented source-purity or environment-isolation problem

## High-Risk Adoption Flow

The implementation should add an automated scenario that copies
`examples/rag-contract-system/` into a temporary Git repository, installs the
harness there, configures a High-Risk task, records required evidence, and runs
the installed finish command.

The scenario should use the malicious retrieval task as the motivating risk:
retrieved contract text must not become executable instructions or suppress
citations. The application behavior is already covered by fixture tests; the
adoption flow measures whether harness evidence helps prove that behavior
without adding unnecessary ceremony.

The installed target should exercise these evidence types:

- TDD evidence for the behavior-change discipline
- acceptance evidence for observable task criteria
- architecture evidence for the invariant that retrieved text is untrusted data
- review evidence for security-sensitive change approval
- command ledger evidence for replayable verification commands
- sandbox evidence through the existing fake-runner contract
- repository verification through the installed harness finish command

The source fixture must remain free of generated `.agent/`, `.venv/`, and
`__pycache__/` directories.

## Verification Ergonomics Decision

The Standard adoption report already exposed two related friction points:

- the fixture needs `PYTHONPATH=src` because it intentionally avoids package
  installation
- when `pytest` is available on the host, heuristic discovery can run in
  addition to configured commands and must inherit the same environment

This phase should decide the smallest appropriate response after the
High-Risk flow confirms the behavior.

Allowed responses:

- document the requirement more clearly in the fixture and gate guide
- encode the needed environment in the example harness configuration used by
  the installed adoption scenario
- adjust verification command handling so configured environment assumptions
  are not undermined by heuristic discovery

Disallowed responses:

- requiring package installation for the fixture
- disabling useful verification globally without evidence
- adding a new profile field or language-specific project detector
- making Python-specific behavior part of the generic harness contract

## Adoption Report Contract

`examples/rag-contract-system/adoption/report.md` remains the reader-facing
record of adoption results.

The High-Risk row should distinguish:

- setup commands
- harness files edited
- verification result
- friction observed
- valuable gates
- low-value gates
- recommended action

The report should record application defects separately from harness
installation, configuration, evidence, or finish friction. If no application
defect is found, it should say that directly rather than implying the harness
proved semantic correctness.

## Expected Improvements

The implementation may update only the surfaces needed by measured results.
Likely surfaces include:

- `tests/harness/rag-adoption.sh`
- `examples/rag-contract-system/adoption/report.md`
- `examples/rag-contract-system/adoption/scenarios.md`
- `examples/rag-contract-system/README.md`
- `docs/agent/gate-guide.md` and its installed template mirror, if gate
  selection guidance is the friction
- verification script behavior and tests, only if the measured environment
  issue cannot be solved honestly through fixture configuration or docs

## Testing Strategy

Required verification:

- the RAG fixture application tests pass in the copied target
- the CLI eval passes in the copied target
- Minimal and Standard adoption coverage remains passing
- the complete High-Risk finish flow passes in the installed target
- command ledger evidence is produced and accepted by finish validation
- sandbox fake-runner evidence is produced and accepted by finish validation
- source fixture purity checks reject `.agent/`, `.venv/`, and `__pycache__/`
  pollution
- `bash validate-harness.sh` passes
- `bash templates/scripts/check-doc-links.sh .` passes if docs are changed

## Error Handling

The adoption test should fail with clear attribution:

- fixture setup failure
- application verification failure
- harness installation failure
- evidence setup failure
- finish-gate failure
- source-purity failure

The failure message should identify whether the problem is in the RAG
application, the fixture configuration, or the harness workflow.

## Success Criteria

- A complete High-Risk RAG adoption flow runs offline and deterministically.
- The adoption report explains which High-Risk gates added decision value and
  which added cost without value.
- The `PYTHONPATH=src` and host `pytest` friction has a clear documented or
  implemented resolution.
- The source fixture remains clean of generated runtime state.
- No new harness gate, schema, profile engine, or runtime abstraction is added.
- `bash validate-harness.sh` remains passing.

## Non-Goals

This phase does not make the harness a semantic verifier, sandbox runtime,
language-specific build system, or package manager. It also does not prove that
all future High-Risk tasks should enable every optional gate. High-Risk remains
a selective menu driven by named risks.
