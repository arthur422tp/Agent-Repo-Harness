---
name: verification-gate
description: Require explicit verification evidence before claiming the work is complete.
---

# Verification Gate

Use this skill at the end of implementation and before handoff updates are finalized.

This keeps finish-time verification workflow in a reusable skill instead of repeating it in every user prompt.

## Workflow

1. Before claiming completion, run:

```bash
scripts/agent-verify.sh
```

2. If it passes:
   - report the command and result
3. If it fails:
   - fix minimally and rerun
4. If it cannot run:
   - explain why
   - mark completion as unverified
5. Record the last meaningful verification command and result in `handoff.md`.

## Hard Rules

- Do not claim completion without verification evidence.
- Do not hide skipped checks.
- Prefer repo-native commands over guessed commands.
- Never say "verified" without command evidence.
