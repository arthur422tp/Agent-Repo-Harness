---
name: domain-risk-review
description: Review risky changes for project-specific contract, safety, and operational concerns.
---

# Domain Risk Review

Use this skill when changes touch high-risk or high-coupling areas.

## Review Targets

- auth and permissions
- billing or money movement
- secrets and environment handling
- deploy and infra configuration
- shared schemas and contracts
- external integrations
- generated clients and interface boundaries

## Review Examples

For IoT projects:

- Did the change affect protocol worker -> queue -> handler -> DB -> frontend flow?
- Did it affect bucket naming?
- Did it affect signal parsing?
- Did it touch Docker, queue, DB, or handler config?

For RAG projects:

- Did it affect chunking, embedding, retrieval, reranking, or generation?
- Did it expose unsafe metadata to prompts?
- Did it preserve RAG injection mitigations?
- Did it change answer validation?

## Workflow

1. Identify the risky files or patterns involved.
2. Confirm the related policy warnings.
3. Check for contract, runtime, or operational regressions.
4. Require stronger verification when the blast radius is high.
5. Capture residual risks in `handoff.md` if they remain unresolved.

## Hard Rules

- Small diffs can still be high risk.
- Touched-file count is not a sufficient safety signal.
- If confidence is limited, say so explicitly.
