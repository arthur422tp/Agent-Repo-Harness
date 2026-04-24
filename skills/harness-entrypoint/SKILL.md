---
name: harness-entrypoint
description: Lightweight repo-aware control entrypoint that wraps around Superpowers without replacing it.
---

# Harness Entrypoint

Use this skill at the start of any non-trivial development, debugging, refactor, repo-analysis, or handoff task.

## Steps

1. Read project harness files:
   - `agent.md`
   - `handoff.md`
   - `.agent/harness.yml`
   - `.agent/policy.yml`
   - `docs/agent/known-issues.md` if relevant
   - `docs/agent/discoveries.md` if relevant

2. Run:

```bash
scripts/agent-preflight.sh
```

3. Classify the task:
   - repo bootstrapping
   - bugfix
   - feature
   - refactor
   - debugging
   - documentation
   - handoff update

4. Select the Superpowers workflow:
   - unclear requirement -> `superpowers:brainstorming`
   - implementation plan needed -> `superpowers:writing-plans`
   - independent implementation tasks -> `superpowers:subagent-driven-development`
   - sequential implementation -> `superpowers:executing-plans`
   - behavior change -> `superpowers:test-driven-development`

5. Before dispatching subagents, create a Subagent Context Packet.

6. Before final completion:
   - run `scripts/agent-verify.sh`
   - run policy checks
   - update `handoff.md` if needed
   - update discoveries if useful

## Hard Rules

- Agent-Repo-Harness does not replace Superpowers.
- Do not duplicate Superpowers workflows.
- Do not use `handoff.md` as a plan.
- Do not put session logs into `agent.md`.
- Prefer additive guidance updates before rewrites.
