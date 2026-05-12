# Review Evidence

Review evidence is optional by default. It is required only when
`.agent/task.yml` sets:

```yaml
task:
  completion:
    requires_review_evidence: true
```

`task.completion.requires_review_evidence` is the task-level switch that makes
`scripts/check-review-evidence.sh` inspect `.agent/review.yml`. If the switch
is absent or not `true`, the check passes without requiring review evidence.

`review.required` is the evidence-file acknowledgement that the required review
was actually performed. When the task-level switch is `true`,
`review.required` must also be `true`; leaving it `false` or omitting it blocks
finish.

When required, fill `.agent/review.yml` before running
`scripts/agent-finish.sh`:

```yaml
review:
  required: true
  status: approved
  reviewer: "Human Reviewer"
  evidence: "PR review approved on 2026-05-12."
  concerns: []
```

## Status Values

- `not_requested`: no review has happened yet; blocks finish when review
  evidence is required.
- `approved`: review completed without blocking concerns.
- `approved_with_comments`: review completed with non-blocking comments.
- `changes_requested`: reviewer requested changes; blocks finish.
- `blocked`: review cannot approve completion; blocks finish.

## Evidence

Use `review.evidence` for a concise, durable reference to the review event:
pull request review URL, review thread, issue comment, email/message reference,
or a human-authored note with date and reviewer name.

`review.reviewer` must identify who reviewed the work. It can be a person,
team, or review role if that is how the repo operates.

## Blocking Concerns

Concerns may be strings or maps. A mapped concern with `blocking: true` blocks
finish even if the top-level status is otherwise acceptable.

```yaml
review:
  required: true
  status: approved_with_comments
  reviewer: "Human Reviewer"
  evidence: "PR review approved on 2026-05-12."
  concerns:
    - id: review-1
      description: "Follow-up cleanup can happen later."
      blocking: false
```
