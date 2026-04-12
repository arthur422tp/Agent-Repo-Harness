# Bad Handoff Output Examples

Use these examples to avoid turning handoff into a log, mini plan, or duplicate map.

## Bad Example 1: Handoff As History Log

````markdown
## Handoff

- Last updated: 2026-04-12
- Current focus: Auth cleanup
- Progress: Renamed files on Monday, then tried a second approach, then rolled it back, then talked to ops, then reviewed tests, then updated docs.
- Next pointer: 1. check auth env 2. inspect CI 3. rewrite middleware 4. compare old branch 5. update docs
- Blockers: None
- Related plan: `docs/plans/auth.md`
````

Why this is bad:

- `Progress` is a narrative log instead of a compact delta
- `Next pointer` became a multi-step plan

## Bad Example 2: Handoff Duplicates Planning

````markdown
## Handoff

- Last updated: 2026-04-12
- Current focus: Payment rewrite
- Progress: Work in progress
- Next pointer: Implement steps 3 through 9 from the payment migration plan, then validate all API routes, then backfill data, then coordinate rollout.
- Blockers: None
- Related plan: `docs/plans/payment-rewrite.md`
````

Why this is bad:

- the detailed next steps already belong in the planning doc
- handoff should link to the plan, not copy it

## Bad Example 3: Handoff That Should Be Removed

````markdown
## Handoff

- Last updated: 2026-04-12
- Current focus: None
- Progress: None
- Next pointer: None
- Blockers: None
- Related plan: None
````

Why this is bad:

- no useful current-state information remains
- the section should usually be removed instead of kept as empty scaffolding
