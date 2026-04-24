# RAG Contract System Example

This example shows how Agent-Repo-Harness can be applied to a retrieval-augmented contract-analysis project.

## Typical Repo Shape

- `apps/api/`
- `apps/worker/`
- `packages/prompts/`
- `packages/contracts/`
- `data/`
- `pipelines/`
- `infra/`

## Suggested Harness Focus

- `agent.md`: map ingestion, chunking, embedding, retrieval, ranking, and answer-generation boundaries
- `handoff.md`: record the active retrieval or evaluation task and the last successful checks
- `docs/agent/discoveries.md`: capture dataset quirks, indexing assumptions, or prompt regressions
- `docs/agent/known-issues.md`: store recurring eval drift or document-shape issues

## Example `known-issues.md` Topics

- prompt injection through retrieved metadata
- chunk boundary regressions that lower recall
- reranker drift after embedding model changes

## Domain Review Focus

- verify chunking, embedding, retrieval, reranking, generation, and answer validation boundaries
- check whether unsafe metadata can leak into prompts
- confirm retrieval quality safeguards still hold

## Likely Policy Risks

- schema or contract changes across API and worker boundaries
- prompt and evaluation drift
- secrets for model providers or vector stores
- infra changes that affect indexing or retrieval performance
- prompt templates, retrieval logic, DB migrations, and auth as high-risk paths

## Likely Verification

- repo-native unit and integration tests
- retrieval or eval smoke tests
- prompt or contract sanity checks
