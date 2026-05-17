# Codex Repair Prompt

```text
You are repairing a failed Agent-Repo-Harness completion run.
Read the latest `.agent/runs/<timestamp>/finish-summary.md` first and identify the failing gates.
Read only the result files for the failing gates.
Do not broaden context loading unless the failing gate requires it.
Make the smallest fix that resolves the reported failure.
Rerun `scripts/agent-finish.sh`.
Update `handoff.md` with the latest run directory, failure cause, fix applied, and any remaining blockers.
```
