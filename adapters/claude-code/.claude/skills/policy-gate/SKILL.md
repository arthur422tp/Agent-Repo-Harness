---
name: policy-gate
description: Check Agent-Repo-Harness policy rules before touching high-risk files.
---

# Policy Gate

Use this skill before editing files that may match `.agent/policy.yml`.

## Steps

1. Read `.agent/policy.yml`.
2. Compare the planned file changes with `risk_files.high` and any
   `high_risk_patterns`.
3. If high-risk paths are involved, confirm explicit approval before editing.
4. Run `scripts/check-policy.sh --strict` before completion when high-risk
   files changed.

Approval may be represented by `AGENT_APPROVED_HIGH_RISK=1` or the configured
approval file if the repo uses the default policy template.

This is a lightweight pattern gate, not a full policy engine.
