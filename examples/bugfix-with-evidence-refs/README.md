# Bugfix With Evidence Refs

## Scenario

An agent fixes behavior and must bind artifact-backed acceptance evidence.

## Initial Task

Fix a failing edge case and prove verification passed.

## Profile Selected

Standard with strict evidence refs.

## Commands Run

```bash
bash scripts/agent-task-profile.sh standard --goal "Fix edge case" --allowed "src/**" --allowed "tests/**"
bash scripts/agent-finish.sh --strict
bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify
```

## Expected Failure

The first acceptance check fails if `evidence_refs` are missing.

## Repair Step

Bind the finish summary with `scripts/agent-evidence-bind.sh`, rerun
`scripts/check-acceptance.sh`, then rerun `scripts/agent-finish.sh`.

## Final Finish Result

`AGENT_FINISH_RESULT=pass`.

## What The Agent May Claim

The bugfix passed configured verification and strict acceptance evidence points
to a captured finish summary.

## What The Agent Must Not Claim

The agent must not claim the harness proved semantic correctness beyond the
configured checks.
