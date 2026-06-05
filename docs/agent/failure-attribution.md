# Failure Attribution

Failure attribution records why a failed or repaired harness run failed, what
evidence supports that conclusion, what repair was made, and how the repair was
verified.

## Enablement

Set the task completion flag in `.agent/task.yml`:

```yaml
task:
  completion:
    requires_failure_attribution: true
```

When this flag is true, `scripts/check-failure-attribution.sh` and
`scripts/agent-finish.sh` require `.agent/failure-attribution.yml`.

## Required Fields

`.agent/failure-attribution.yml` must include:

- `failure_attribution.required`: boolean marker for the evidence file.
- `failure_attribution.status`: `complete` or `complete_with_concerns`.
- `failure_attribution.root_cause`: concise cause of the failure.
- `failure_attribution.evidence`: concrete run output, file path, command
  result, or observation supporting the cause.
- `failure_attribution.repair`: repair action taken or required.

Optional fields include `failure_attribution.verification` and
`failure_attribution.concerns`.

## Result File

The finish run writes
`.agent/runs/<timestamp>/failure-attribution-result.txt`. Inspect that file
when the gate fails, then update `.agent/failure-attribution.yml` with real
evidence. Do not invent failures, repairs, approvals, or verification results.
