# Policy Approval

High-risk approval is needed when `scripts/check-policy.sh --strict` finds changed files that match high-risk patterns in `.agent/policy.yml`.

## Preferred Structured Approval

Use `.agent/approvals/high-risk-approved.yml` only after explicit human approval:

```yaml
approval:
  approved_by: "human"
  approved_at: "2026-05-12T00:00:00Z"
  task_id: "current-task-id-or-description"
  reason: "User explicitly approved this high-risk change."
  approved_paths:
    - "src/auth/**"
    - ".github/workflows/**"
```

Required fields:

- `approval.approved_by` must be non-empty.
- `approval.reason` must be non-empty.
- `approval.approved_paths` must be a non-empty list.

Every high-risk changed file must match at least one `approved_paths` pattern. Use the narrowest patterns that cover the approved change.

## Agent Rule

Agents must not create or modify approval files unless the user explicitly instructs them to record an approval.

## Legacy Compatibility

Strict mode still accepts `AGENT_APPROVED_HIGH_RISK=1` and `.agent/approvals/high-risk-approved` for compatibility. These legacy approvals emit warnings and should be replaced by structured approval when possible.
