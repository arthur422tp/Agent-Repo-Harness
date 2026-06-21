# RAG Contract Adoption Fixture Design

## Goal

Build a deterministic, offline contract-analysis RAG reference project that
can exercise Agent-Repo-Harness adoption through Minimal, Standard, and
High-Risk workflows.

## Purpose

The fixture is not intended to demonstrate production model quality. Its
purpose is to provide a realistic repository shape, domain risks, tests,
evaluation cases, and change scenarios for measuring harness onboarding and
operating friction.

The project should be complex enough to expose scope, verification, TDD,
acceptance, architecture, command-ledger, review, sandbox, and handoff
decisions, but small enough to run offline in CI without secrets or model
downloads.

## Scope

The project lives under `examples/rag-contract-system/` and replaces the
current documentation-only example with an executable Python project.

Included:

- Markdown contract corpus
- deterministic heading/paragraph chunking
- in-memory lexical retrieval
- metadata filtering
- extractive answer composition
- source citations
- fixed evaluation cases
- prompt-injection-style retrieved content fixture
- unit, integration, security, and evaluation tests
- reproducible harness adoption scenarios
- adoption findings report

Excluded:

- embedding models
- LLM providers
- API keys or external services
- vector databases
- web UI or HTTP API
- authentication or deployment
- provider-native tracing
- new harness gates, schemas, or runtime abstractions

## Project Structure

```text
examples/rag-contract-system/
  pyproject.toml
  README.md
  src/contract_rag/
    __init__.py
    models.py
    loader.py
    chunker.py
    retriever.py
    answerer.py
    pipeline.py
    cli.py
  data/contracts/
    master-services-agreement.md
    data-processing-addendum.md
    software-license.md
    malicious-metadata.md
  evals/
    cases.json
  tests/
    test_chunker.py
    test_retriever.py
    test_pipeline.py
    test_security.py
    test_evals.py
  adoption/
    minimal-task.yml
    standard-task.yml
    high-risk-task.yml
    scenarios.md
    report.md
```

The source fixture should not contain an installed harness baseline. Adoption
tests copy it into a temporary Git repository and run
`install-agent-harness.sh` there so installation and first-run behavior remain
part of the measurement.

## Architecture

### Models

`models.py` defines immutable or simple value objects:

- `Document`: document ID, title, source path, metadata, and raw content
- `Chunk`: chunk ID, document ID, heading, text, and ordinal
- `SearchResult`: chunk, score, and matched terms
- `Citation`: document ID, heading, and chunk ID
- `Answer`: text, citations, supported flag, and confidence

These types form the boundaries between ingestion, retrieval, and answer
composition.

### Loader

`loader.py` reads Markdown contracts from a configured directory. Each file
uses a small front-matter-like metadata header or a documented metadata block
for fields such as:

- document ID
- title
- contract type
- jurisdiction

The loader validates required metadata and preserves document content without
interpreting retrieved instructions as control input.

### Chunker

`chunker.py` splits documents deterministically by Markdown heading and
paragraph boundaries.

Rules:

- empty paragraphs do not create chunks
- heading text is retained on the chunk
- ordinal order follows source order
- chunk IDs are derived deterministically from document ID and ordinal
- repeated runs over unchanged documents produce identical chunks

### Retriever

`retriever.py` builds an in-memory lexical index from chunks. It normalizes
query and chunk terms, computes a deterministic token-overlap or BM25-style
score, applies metadata filters, and returns stable ordered results.

Stable tie-breaking uses document ID and chunk ordinal. Retrieval does not
depend on network access, random seeds, or external model state.

### Answer Composer

`answerer.py` creates an extractive answer from top-ranked chunks.

Rules:

- supported answers use only retrieved chunk text
- every supported answer has at least one citation
- citations include document ID, heading, and chunk ID
- low-evidence queries return a fixed unsupported message and no citations
- document text and metadata never become executable instructions
- forbidden terms from security evaluation cases must not appear

### Pipeline

`pipeline.py` composes loading, chunking, retrieval, filtering, and answer
generation behind a small application interface.

### CLI

`cli.py` exposes:

```text
PYTHONPATH=src python -m contract_rag.cli ask "What is the termination notice period?"
PYTHONPATH=src python -m contract_rag.cli ask --contract-type dpa "Who must report a data breach?"
PYTHONPATH=src python -m contract_rag.cli eval
```

The CLI emits deterministic text or JSON suitable for tests and harness
verification commands.

## Contract Corpus

The fixture corpus contains four synthetic documents.

### Master Services Agreement

Covers termination notice, payment, service levels, limitation of liability,
and governing law.

### Data Processing Addendum

Covers breach notification, subprocessors, data subject requests, security
measures, and data return or deletion.

### Software License

Covers license scope, prohibited uses, support, audit rights, and termination.

### Malicious Metadata Document

Contains retrieved text or metadata such as instructions to ignore rules,
reveal secrets, or suppress citations. It exists only to prove that retrieved
content is treated as untrusted data and cannot alter pipeline behavior.

All documents are synthetic and must not reproduce proprietary agreements.

## Data Flow

```text
Markdown contracts
  -> loader and metadata validation
  -> deterministic chunks
  -> in-memory lexical index
  -> normalized query and optional filters
  -> ranked SearchResult list
  -> evidence threshold
  -> extractive Answer with citations or fixed unsupported result
```

## Evaluation Contract

`evals/cases.json` contains fixed cases with:

- case ID
- query
- optional metadata filters
- expected document IDs
- required answer terms
- forbidden answer terms
- expected supported state

Evaluation output identifies the case, expected documents, actual documents,
missing answer terms, forbidden terms, and supported-state mismatch.

The evaluator returns nonzero when any case fails.

## Harness Adoption Scenarios

### Minimal Scenario

Example task: fix loader handling for empty headings.

Use existing Minimal profile guidance:

- scope check
- policy check
- repository verification
- handoff update expectation

Measure:

- number of installation and setup steps
- number of harness files requiring edits
- time or command count to first passing finish
- whether optional gates remain unobtrusive

### Standard Scenario

Example task: add jurisdiction metadata filtering.

Use:

- Minimal checks
- TDD evidence
- acceptance evidence

Measure:

- clarity of red/green evidence recording
- mapping between acceptance criteria and behavior
- readability of grouped finish summary
- documentation lookup path

### High-Risk Scenario

Example task: prevent malicious retrieved instructions from influencing answer
composition.

Use:

- Standard checks
- architecture evidence
- command ledger
- review evidence
- sandbox verification only when a runner is available
- failure attribution or intervention records only when the corresponding
  event actually occurs

Measure:

- whether the gate guide prevents enabling every gate by default
- whether each enabled gate answers a named risk
- value of command ledger and security-test evidence
- behavior when external sandbox runners are unavailable
- whether handoff evidence is sufficient for a new agent

## Adoption Test Method

Repository validation should copy the fixture into a temporary directory,
initialize Git, install the harness, select a scenario task configuration, and
run the relevant preflight, verification, and finish commands.

The source example remains free of generated `.agent/runs`, `.agent/audits`,
and installed harness output.

At minimum, automated adoption coverage should prove:

- the fixture copies cleanly into a temporary Git repository
- the installer succeeds
- Minimal, Standard, and High-Risk task configurations validate
- the RAG unit tests and evaluation command pass
- a Standard finish run passes with required evidence populated
- High-Risk sandbox evidence can be tested with the existing fake-runner
  contract without requiring local Docker or Podman

## Tests

### Chunker Tests

- heading boundaries are stable
- empty paragraphs do not create chunks
- chunk IDs are deterministic
- source order is preserved

### Retriever Tests

- a termination query retrieves the Master Services Agreement
- a breach query with DPA filter retrieves the Data Processing Addendum
- metadata filters exclude other contract types
- score ordering and tie-breaking are deterministic

### Pipeline Tests

- supported answers include citations
- unsupported queries return the fixed unsupported message
- answer terms come from retrieved evidence
- citations reference existing chunks

### Security Tests

- malicious retrieved instructions do not alter pipeline behavior
- forbidden terms do not appear in answers
- metadata is treated as data, not control instructions
- unsupported evidence cannot force a supported answer

### Evaluation Tests

- every case in `evals/cases.json` executes
- failures report expected and actual document IDs
- required and forbidden answer terms are checked
- evaluator exit status reflects aggregate success

## Repository Verification

The example uses Python standard library `unittest` and has no required
third-party dependencies.

Canonical commands:

```text
PYTHONPATH=src python -m unittest discover -s tests -v
PYTHONPATH=src python -m contract_rag.cli eval
```

The documented commands set `PYTHONPATH=src` explicitly so the fixture does not
require package installation or network access. `pyproject.toml` provides
project metadata and tool-independent Python version requirements.

## Adoption Report

`adoption/report.md` records observed results rather than assuming the harness
has no friction.

Required fields:

- scenario
- installation and first-finish commands
- harness files edited
- verification result
- false positives or confusing behavior
- documentation path used
- gates that added decision value
- gates that added cost without value
- recommended keep, simplify, or change actions

Application defects and harness friction must be reported separately.

## Error Handling

- invalid contract metadata fails loading with file and field context
- missing corpus directories fail clearly
- unsupported CLI commands return nonzero with usage
- malformed evaluation JSON reports the case file and parse error
- no retrieval result above threshold returns a supported false answer rather
  than fabricating content
- adoption setup failures identify whether the source is fixture setup,
  application verification, harness configuration, or finish evidence

## Success Criteria

- the fixture runs offline and deterministically
- no API key, model download, vector database, or third-party package is
  required
- unit, integration, security, and evaluation tests pass
- the three adoption scenarios have reproducible steps
- at least one adoption finding is recorded, even if it confirms a workflow is
  clear rather than identifying a defect
- harness friction and RAG application failures are distinguished
- no harness gate, schema, profile engine, or runtime abstraction is added
- `bash validate-harness.sh` remains passing

## Non-Goals

This project does not establish a production RAG architecture, benchmark model
quality, process real contracts, or provide legal advice. It is a deterministic
adoption and regression fixture for Agent-Repo-Harness.
