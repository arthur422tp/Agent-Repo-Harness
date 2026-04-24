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
scripts/check-policy.sh --warn
scripts/check-scope.sh --strict
scripts/agent-verify.sh --strict
```

`check-policy.sh` defaults to warn mode unless strict policy approval is
required. `check-scope.sh` defaults to strict mode, but it only enforces
limits configured in `.agent/task.yml`. `agent-verify.sh` defaults to strict
mode.

3. Record the required command results in `handoff.md`.
4. If `.agent/task.yml` exists, keep its machine-readable verification state
   aligned with the final result.
5. If all required commands pass:
   - report the exact commands and results
6. If either command fails:
   - fix minimally when appropriate
   - rerun the failed command
   - do not claim verified until the required commands pass
7. If either command cannot run:
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
- `scripts/check-scope.sh` is required when `.agent/task.yml` exists.
- `scripts/agent-verify.sh` must be run before final completion.
- Record required command results in `handoff.md`.
- Do not claim verified if a required command fails or cannot run.
