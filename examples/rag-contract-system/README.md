# RAG Contract System Example

This is an offline deterministic contract-analysis RAG fixture for evaluating
Agent-Repo-Harness adoption. It is not a production RAG stack and does not
provide legal advice.

## Architecture

```text
Markdown contracts -> loader -> deterministic chunks -> lexical retriever
  -> evidence threshold -> extractive answer with citations
```

- `loader.py`: metadata and Markdown loading
- `chunker.py`: heading and paragraph chunks
- `retriever.py`: deterministic lexical scoring and metadata filters
- `answerer.py`: extractive supported or unsupported answers
- `pipeline.py`: application composition
- `cli.py`: ask and eval commands

## Environment

The fixture has no third-party runtime dependencies. Use an isolated virtual
environment anyway so future optional tooling cannot pollute global Python:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Never use global `pip` or `pip3` for this fixture. If optional tooling is later
needed, install it only with the activated environment's `python -m pip`.

## Run

```bash
PYTHONPATH=src python -m contract_rag.cli ask "What is the termination notice period?"
PYTHONPATH=src python -m contract_rag.cli ask --contract-type dpa "Who must report a data breach?"
PYTHONPATH=src python -m contract_rag.cli eval
```

## Verify

```bash
PYTHONPATH=src python -m unittest discover -s tests -v
PYTHONPATH=src python -m contract_rag.cli eval
```

The `PYTHONPATH=src` prefix is part of the fixture contract. The project is not
installed as a package during adoption tests, so configured harness commands
and any host-provided Python test discovery must inherit the same source path.

## Corpus

The synthetic corpus contains a Master Services Agreement, Data Processing
Addendum, Software License, and an untrusted retrieved-content document. No
proprietary agreement text is included.

## Security Boundary

Retrieved documents and metadata are untrusted data. The answer composer does
not execute retrieved instructions and rejects instruction-like sentences from
supported answers. This deterministic safeguard demonstrates the boundary; it
is not a complete prompt-injection defense for production LLM systems.

## Harness Adoption

See [Adoption Scenarios](adoption/scenarios.md) for Minimal, Standard, and
High-Risk workflows and [Adoption Report](adoption/report.md) for measured
friction and gate value.

Adoption tests copy this fixture into a temporary Git repository before
installing Agent-Repo-Harness. Generated harness state and run evidence do not
belong in this source fixture.
