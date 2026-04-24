---
name: verification-gate
description: Require explicit verification evidence before claiming the work is
  complete.
---

# Verification Gate

Use this skill at the end of implementation and before handoff updates are
finalized.

This keeps finish-time verification workflow in a reusable skill instead of
repeating it in every user prompt.

## Workflow

1. Decide whether `scripts/check-policy.sh` is required.
   Run it when files changed or when `.agent/policy.yml` exists.
2. Before final completion, run:

```bash
scripts/check-policy.sh
scripts/agent-verify.sh
```

3. Record both command results in `handoff.md`.
4. If both commands pass:
   - report the exact commands and results
5. If either command fails:
   - fix minimally when appropriate
   - rerun the failed command
   - do not claim verified until both commands pass
6. If either command cannot run:
   - explain why
   - record the limitation in `handoff.md`
   - mark completion as unverified

## Hard Rules

- Do not claim completion without verification evidence.
- Do not hide skipped checks.
- Prefer repo-native commands over guessed commands.
- Never say "verified" without command evidence.
- `scripts/check-policy.sh` is required when files changed or when policy
  exists.
- `scripts/agent-verify.sh` must be run before final completion.
- Record both command results in `handoff.md`.
- Do not claim verified if either command fails or cannot run.
