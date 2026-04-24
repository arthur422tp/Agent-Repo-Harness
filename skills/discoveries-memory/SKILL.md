---
name: discoveries-memory
description: Capture short-term discoveries and promote repeated insights into
  durable repo guidance.
---

# Discoveries Memory

Use this skill when implementation or debugging reveals facts that later agents should reuse.

## Workflow

1. After each subagent task, extract useful discoveries.
2. Add fresh short-term findings to `docs/agent/discoveries.md`.
3. Deduplicate.
4. Inject relevant discoveries into later Subagent Context Packets.
5. Promote repeated or durable findings into `docs/agent/known-issues.md`.
6. Update `agent.md` only when the finding changes stable repo understanding.

## Good Discovery Targets

- recurring debug steps
- fragile build or test assumptions
- hidden repo-specific constraints
- path or command gotchas

## Hard Rules

- Do not turn discoveries into session logs.
- Do not duplicate stable architecture facts that already live in `agent.md`.
