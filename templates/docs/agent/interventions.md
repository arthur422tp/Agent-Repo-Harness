# Interventions

Intervention records document human, tool, or runtime actions that materially
changed the task path. They are evidence for traceability, not a way to create
approval after the fact.

## Enablement

Set the task completion flag in `.agent/task.yml`:

```yaml
task:
  completion:
    requires_intervention_record: true
```

When this flag is true, `scripts/check-interventions.sh` and
`scripts/agent-finish.sh` require `.agent/interventions.yml`.

## Required Entry Fields

`.agent/interventions.yml` must include `interventions.required` and at least
one entry under `interventions.entries`. Each required entry includes:

- `timestamp`: when the intervention happened.
- `actor`: person, agent, tool, or runtime that intervened.
- `type`: one of `approval`, `scope_change`, `blocker_resolution`,
  `manual_verification`, or `runtime_override`.
- `summary`: concise description of what changed.

`evidence` is optional but recommended when a command output, message, or file
path supports the entry.

## Rule

Record only interventions that actually happened. Do not invent approvals,
scope changes, runtime overrides, manual verification, or blocker resolutions.
High-risk approvals still require explicit human instruction under the policy
approval contract.
