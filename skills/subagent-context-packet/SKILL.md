---
name: subagent-context-packet
description: Build a compact repo-aware context packet for subagents from
  stable guidance, handoff, discoveries, and policy.
---

# Subagent Context Packet

Prepare context for Superpowers subagents before dispatch.

Use this packet instead of copying a long repo workflow prompt into every
subagent request.

## Template

```markdown
# Subagent Context Packet

## Task
[Exact task]

## Relevant Repo Map
[Relevant excerpt from agent.md]

## Current State
[Relevant excerpt from handoff.md]

## Known Issues
[Relevant known issues]

## Current Discoveries
[Relevant discoveries]

## Policy Constraints
[Relevant .agent/policy.yml rules]

## Allowed Files
[Files this subagent may edit]

## High-Risk / Forbidden Files
[Files requiring explanation or approval]

## Required Workflow
- Use superpowers:test-driven-development for behavior changes.
- Provide RED/GREEN/REFACTOR evidence.

## Definition of Done
- Task-specific tests pass.
- No unrelated files changed.
- Verification command is run or limitation is reported.
```

## Rules

- Every coding subagent must receive a packet.
- Every reviewer subagent should receive the same packet.
- Subagents must report discoveries.
- Include only task-relevant context.
- Prefer stable facts over recent speculation.
- Pull reusable repo workflow from skills and repo files rather than rewriting
  it manually in the dispatch prompt.
