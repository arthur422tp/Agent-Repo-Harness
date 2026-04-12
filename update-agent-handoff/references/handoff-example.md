# Handoff Update Example

Use this only when the shape of a compact handoff update is uncertain. Keep the final update specific to the target repo.

## Before

```markdown
## Handoff

- Last updated: 2026-04-01
- Current focus: Payment webhook retry handling
- Progress: Added initial webhook handler but retry verification is still open.
- Next pointer: Verify retry behavior in tests.
- Blockers: Confirm retry policy with ops.
- Related plan: `docs/plans/payment-webhooks.md`
```

## After

```markdown
## Handoff

- Last updated: 2026-04-07
- Current focus: None
- Progress: Verified webhook retry tests and removed stale handler-wiring TODO.
- Next pointer: Review production retry policy before changing webhook behavior again.
- Blockers: None
- Related plan: `docs/plans/payment-webhooks.md`
```

## What Changed

- Updated the date and current focus.
- Replaced stale status instead of appending a history log.
- Kept progress to the single most important delta.
- Kept the next pointer to one short line.
- Left the detailed plan in the planning doc.
