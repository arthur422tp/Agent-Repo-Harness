---
name: verification-gate
description: Require explicit verification evidence before claiming the work is complete.
---

# Verification Gate

Use this skill at the end of implementation and before handoff updates are
finalized.

This keeps finish-time verification workflow in a reusable skill instead of
repeating it in every user prompt.

## Workflow

1. Before claiming completion, run:

```bash
scripts/check-policy.sh
scripts/agent-verify.sh
```

2. If both pass:
   - report the commands and results
3. If either fails:
   - fix minimally and rerun
4. If it cannot run:
   - explain why
   - mark completion as unverified
5. Record the last meaningful policy and verification results in `handoff.md`.

## Hard Rules

- Do not claim completion without verification evidence.
- Do not hide skipped checks.
- Prefer repo-native commands over guessed commands.
- Never say "verified" without command evidence.
- `scripts/check-policy.sh` is part of the completion gate, not an optional
  extra.
