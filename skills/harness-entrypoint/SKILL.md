---
name: harness-entrypoint
description: Lightweight repo-aware control entrypoint that wraps around
  Superpowers without replacing it.
---

# Harness Entrypoint

Use this skill at the start of any non-trivial development, debugging,
refactor, repo-analysis, or handoff task.

This skill exists so the user does not need to restate the same repo workflow
in every prompt. The live prompt should stay focused on the current task and
any special constraints.

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
   - run `scripts/check-policy.sh`
   - run `scripts/agent-verify.sh`
   - update `handoff.md` if needed
   - update discoveries if useful

## Hard Rules

- Agent-Repo-Harness does not replace Superpowers.
- Reusable workflow instructions belong in skills, not repeated user prompts.
- Repo-specific facts belong in `agent.md`, `handoff.md`, and `docs/agent/*`.
- Treat the user's live prompt as task-specific input, not as a place to
  rebuild the whole harness protocol.
- Do not duplicate Superpowers workflows.
- Do not use `handoff.md` as a plan.
- Do not put session logs into `agent.md`.
- Prefer additive guidance updates before rewrites.
