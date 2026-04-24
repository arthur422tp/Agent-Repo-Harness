---
name: policy-gate
description: Run repo policy checks and surface project-specific risk warnings before completion.
---

# Policy Gate

Use this skill before claiming completion or when risky paths are touched.

This keeps risk workflow out of the user's main prompt. The prompt should only say what the task is and any special constraints.

## Workflow

1. Read `.agent/policy.yml`.
2. Identify files likely to be touched.
3. Classify risk.
4. If high-risk:
   - explain the risk
   - prefer minimal patch
   - avoid destructive changes
   - ask for confirmation only when destructive, production-impacting, or architecture-rewriting
5. Run `scripts/check-policy.sh` if available.
6. Record high-risk changes in `handoff.md`.

## Hard Rules

- Default to warning mode unless the repo policy says otherwise.
- Do not ignore high-risk warnings silently.
- If a policy hit affects contracts, auth, billing, secrets, infra, deploy, or schemas, escalate review depth.
