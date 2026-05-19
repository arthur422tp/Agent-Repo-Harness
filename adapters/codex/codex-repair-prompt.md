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
   - `acceptance-result.txt` for `check-acceptance`
   - `review-result.txt` for `check-review-evidence`
   - `verify-result.txt` for `agent-verify`
4. Do not read unrelated files unless the failing gate requires it.

Recovery playbook by gate:
- `check-agent-md`: repair `agent.md` so it reflects the current task state and required handoff details without adding unrelated process changes.
- `check-scope`: make the smallest change that brings the work back inside the approved task scope. Do not broaden task scope without explicit human approval.
- `check-policy`: fix the concrete policy violation named in `policy-result.txt`. Do not create or modify high-risk approval files unless the user explicitly instructs it.
- `check-tdd-evidence`: restore real red/green evidence or rerun the required test flow. Do not fabricate TDD red/green evidence.
- `check-acceptance`: satisfy the stated acceptance gap with the smallest implementation or documentation change needed.
- `check-review-evidence`: update review evidence honestly. Do not fabricate review approval or fake reviewer sign-off.
- `agent-verify`: fix the specific verification failure reported in `verify-result.txt` and rerun the relevant checks.

General repair rules:
- Make the smallest fix that resolves the reported failure.
- Rule: do not fabricate evidence, approvals, or completed steps.
- Do not broaden task scope without explicit human approval.
- Do not create or modify high-risk approval files unless the user explicitly instructs it.

After the fix:
1. Rerun `scripts/agent-finish.sh`.
2. Classify the rerun outcome as exactly one of:
   - `REPAIRED_AND_PASSED`
   - `REPAIRED_BUT_STILL_FAILING`
   - `BLOCKED_NEEDS_HUMAN`
   - `SCOPE_OR_POLICY_NEEDS_APPROVAL`
3. Update `handoff.md` with the repair outcome, latest run directory, failure cause, fix applied, and any remaining blockers.
```
