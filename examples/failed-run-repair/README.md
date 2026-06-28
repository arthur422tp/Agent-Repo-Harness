# Failed Run Repair

## Scenario

A strict acceptance run failed because the criterion had text but no structured artifact reference. The agent may not claim completion from the failed finish summary.

## Initial Task

Repair strict acceptance evidence for a completed docs-only change.

## Profile Selected

Standard profile with `requires_acceptance_check: true` and `evidence.strict_refs: true`.

## Commands Run

```bash
bash scripts/agent-finish.sh
bash scripts/check-acceptance.sh
bash scripts/agent-evidence-bind.sh --acceptance .agent/acceptance.yml --criterion strict-acceptance-repaired --type command_output --path examples/failed-run-repair/sample-run-passed/acceptance-result.txt --must-contain ACCEPTANCE_RESULT=pass
bash scripts/check-acceptance.sh
bash scripts/agent-finish.sh
```

## Expected Failure

The first finish run fails because strict acceptance requires `evidence_refs`.

## Failure Evidence

`sample-run-failed/acceptance-result.txt` contains `ACCEPTANCE_RESULT=fail`.

## Repair Step

The agent inspects the failed acceptance result, binds command-backed evidence with `scripts/agent-evidence-bind.sh`, and records the final artifact path in `.agent/acceptance.yml`.

## Rerun

The agent reruns `scripts/check-acceptance.sh` and then `scripts/agent-finish.sh`.

## Final Finish Result

`sample-run-passed/finish-summary.json` records `overall_result: pass`, and `sample-run-passed/acceptance-result.txt` contains `ACCEPTANCE_RESULT=pass`.

## What The Agent May Claim

The agent may claim the strict acceptance evidence was repaired after the passed rerun.

## What The Agent Must Not Claim

The agent must not claim the original failed finish run completed the task, and must not claim semantic correctness beyond the recorded harness checks.
