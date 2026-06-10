---
name: verification-gate
description: Run Agent-Repo-Harness finish and verification checks before claiming completion.
---

# Verification Gate

Use this skill before final response.

## Steps

1. If `.agent/task.yml` sets `completion.requires_sandbox_verification: true`,
   run:

```bash
scripts/agent-sandbox-run.sh
```

2. Run `scripts/agent-finish.sh`. The finish gate validates existing
   sandbox verification evidence instead of creating the sandbox run itself.
3. If strict completion is not possible, run only the best available commands
   and explain the exact blocker.
4. Record results in `handoff.md`.
5. Do not claim verified completion unless the relevant gates passed.

`agent-finish.sh` writes a timestamped run summary under `.agent/runs/` when
the installed template supports run evidence.
