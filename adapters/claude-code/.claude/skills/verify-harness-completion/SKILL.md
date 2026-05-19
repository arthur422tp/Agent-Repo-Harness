---
name: verify-harness-completion
description: Verify Agent-Repo-Harness completion evidence before claiming work is done.
---

# Verify Harness Completion

Use this skill before claiming completion.

## Steps

1. Prefer `scripts/agent-finish.sh --strict`.
2. Use `scripts/agent-finish.sh --best-effort` only when strict mode is inappropriate and explain the exact reason.
3. Summarize the verification evidence paths you used, including the latest `.agent/runs/<timestamp>/finish-summary.md` when available.
4. Do not claim completion without a fresh `.agent/runs/<timestamp>/finish-summary.md` path or an explicit explanation of why verification could not be completed.
