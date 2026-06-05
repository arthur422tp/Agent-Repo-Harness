# Codex Repair Prompt

```text
You are repairing a failed Agent-Repo-Harness completion run.

Start with staged context loading:
1. Read the latest `.agent/runs/<timestamp>/finish-summary.md` first.
2. Identify the failing gates and the exact result filenames referenced there.
3. Read only the result files for the failing gates:
   - `check-agent-md-result.txt` for `check-agent-md`
   - `scope-result.txt` for `check-scope`
   - `policy-result.txt` for `check-policy`
   - `tdd-evidence-result.txt` for `check-tdd-evidence`
   - `subagent-evidence-result.txt` for `check-subagent-evidence`
   - `acceptance-result.txt` for `check-acceptance`
   - `review-result.txt` for `check-review-evidence`
   - `failure-attribution-result.txt` for `check-failure-attribution`
   - `interventions-result.txt` for `check-interventions`
   - `verify-result.txt` for `agent-verify`
4. Do not read unrelated files unless the failing gate requires it.

Recovery playbook by gate:
- `check-agent-md`: repair `agent.md` so it reflects the current task state and required handoff details without adding unrelated process changes.
- `check-scope`: make the smallest change that brings the work back inside the approved task scope. Do not broaden task scope without explicit human approval.
- `check-policy`: fix the concrete policy violation named in `policy-result.txt`. Do not create or modify high-risk approval files unless the user explicitly instructs it.
- `check-tdd-evidence`: restore real red/green evidence or rerun the required test flow. Do not fabricate TDD red/green evidence.
- `check-subagent-evidence`: repair missing or invalid delegated-work evidence named in `subagent-evidence-result.txt`. Do not invent subagent runs, statuses, packets, or results.
- `check-acceptance`: satisfy the stated acceptance gap with the smallest implementation or documentation change needed.
- `check-review-evidence`: update review evidence honestly. Do not fabricate review approval or fake reviewer sign-off.
- `check-failure-attribution`: update `.agent/failure-attribution.yml` with real `failure_attribution.root_cause`, evidence, repair, and verification. Do not fabricate attribution details.
- `check-interventions`: update `.agent/interventions.yml` only with interventions that actually happened. Do not invent approvals, scope changes, or runtime overrides.
- `agent-verify`: fix the specific verification failure reported in `verify-result.txt` and rerun the relevant checks.

General repair rules:
- Make the smallest fix that resolves the reported failure.
- Rule: do not fabricate evidence, approvals, or completed steps.
- Do not broaden task scope without explicit human approval.
- Do not create or modify high-risk approval files unless the user explicitly instructs it.
- If `.agent/task.yml` requires failure attribution, record root cause, evidence, repair, and verification in `.agent/failure-attribution.yml`.

After the fix:
1. Rerun `scripts/agent-finish.sh`.
2. Classify the rerun outcome as exactly one of:
   - `REPAIRED_AND_PASSED`
   - `REPAIRED_BUT_STILL_FAILING`
   - `BLOCKED_NEEDS_HUMAN`
   - `SCOPE_OR_POLICY_NEEDS_APPROVAL`
3. Update `handoff.md` with the repair outcome, latest run directory, failure cause, fix applied, and any remaining blockers.
```
