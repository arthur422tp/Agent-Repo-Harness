# Codex Handoff Prompt

```text
You are writing the Agent-Repo-Harness handoff for completed or paused work.
Update `handoff.md` after work.
Keep the handoff concise and durable.
Include changed files, verification commands and results, the latest `.agent/runs/<timestamp>/finish-summary.md` path, remaining blockers, and the next recommended action.
When it exists, include the latest `.agent/runs/<timestamp>/episode-summary.json` path.
If task flags required failure attribution or intervention evidence, include the relevant `.agent/failure-attribution.yml`, `.agent/interventions.yml`, `failure-attribution-result.txt`, and `interventions-result.txt` paths.
When the work follows a failed `scripts/agent-finish.sh` run, include a repair outcome section with:
- Repair outcome (`REPAIRED_AND_PASSED`, `REPAIRED_BUT_STILL_FAILING`, `BLOCKED_NEEDS_HUMAN`, or `SCOPE_OR_POLICY_NEEDS_APPROVAL`)
- Latest run directory
- Failing gate before repair
- Fix applied
- Remaining blocker
- Next action
```
