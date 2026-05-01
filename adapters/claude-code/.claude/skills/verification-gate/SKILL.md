---
name: verification-gate
description: Run Agent-Repo-Harness finish and verification checks before claiming completion.
---

# Verification Gate

Use this skill before final response.

## Steps

1. Run `scripts/agent-finish.sh`.
2. If strict completion is not possible, run only the best available commands
   and explain the exact blocker.
3. Record results in `handoff.md`.
4. Do not claim verified completion unless the relevant gates passed.

`agent-finish.sh` writes a timestamped run summary under `.agent/runs/` when
the installed template supports run evidence.
