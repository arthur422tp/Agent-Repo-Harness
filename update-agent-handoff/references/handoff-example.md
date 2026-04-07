# Handoff Update Example

Use this only when the shape of a compact handoff update is uncertain. Keep the final update specific to the target repo.

## Before

```markdown
## Handoff

- Last updated: 2026-04-01
- Current active task: Add payment webhook tests.
- Changed this session: Added initial webhook handler.
- Read first next session:
  - `src/payments/webhook.ts`
- Next recommended step: Finish webhook tests.
- Blockers / decisions: TODO: Confirm retry policy.
- Related plan: `docs/plans/payment-webhooks.md`
```

## After

```markdown
## Handoff

- Last updated: 2026-04-07
- Current active task: None
- Changed this session: Verified webhook retry tests and removed stale TODO for handler wiring.
- Read first next session:
  - `src/payments/webhook.ts`
  - `tests/payments/webhook.test.ts`
- Next recommended step: Review production retry policy before changing webhook behavior again.
- Blockers / decisions: TODO: Confirm production retry limits with ops.
- Related plan: `docs/plans/payment-webhooks.md`
```

## What Changed

- Updated the date and active task.
- Replaced stale task state instead of appending a log.
- Kept read-first paths path-only.
- Preserved the unresolved decision as `TODO:`.
- Kept the next step to one short pointer.
