---
name: repair-failed-harness-run
description: Repair a failed Agent-Repo-Harness finish run using staged context loading and minimal scoped fixes.
---

# Repair Failed Harness Run

Use this skill after `scripts/agent-finish.sh` fails.

## Staged Context Loading

1. Preserve staged context loading.
2. Read the latest `.agent/runs/<timestamp>/finish-summary.md` first.
3. Identify the failing gates and the exact result filenames referenced there.
4. Read only the result files for the failing gates:
   - `check-agent-md` -> `check-agent-md-result.txt`
   - `check-scope` -> `scope-result.txt`
   - `check-policy` -> `policy-result.txt`
   - `check-tdd-evidence` -> `tdd-evidence-result.txt`
   - `check-acceptance` -> `acceptance-result.txt`
   - `check-review-evidence` -> `review-result.txt`
   - `check-subagent-evidence` -> `subagent-evidence-result.txt`
   - `agent-verify` -> `verify-result.txt`
5. Do not read unrelated files unless the failing gate requires it.
6. Do not read all historical `.agent/runs/` directories.

## Repair Rules By Gate

- `check-agent-md`: repair `agent.md` so it reflects the current task state and required handoff details without adding unrelated process changes.
- `check-scope`: make the smallest change that brings the work back inside the approved task scope. Do not broaden scope without explicit human approval.
- `check-policy`: fix the concrete policy violation named in `policy-result.txt`. Do not create or modify high-risk approval files without explicit human approval.
- `check-tdd-evidence`: restore real red/green evidence or rerun the required test flow. Do not fabricate TDD evidence.
- `check-acceptance`: satisfy the stated acceptance gap with the smallest implementation or documentation change needed.
- `check-review-evidence`: update review evidence honestly. Do not fabricate review approval or reviewer sign-off.
- `check-subagent-evidence`: repair the missing or invalid delegated-work evidence named in `subagent-evidence-result.txt`. Do not invent subagent runs, statuses, packets, or results.
- `agent-verify`: fix the specific verification failure reported in `verify-result.txt` and rerun the relevant checks.

## General Rules

- Make the smallest fix that resolves the reported failure.
- do not fabricate evidence, approvals, delegated work, or completed steps.
- Do not broaden task scope without explicit human approval.
- Do not create or modify high-risk approval files without explicit human approval.

## After The Fix

1. Rerun `scripts/agent-finish.sh`.
2. Classify the outcome as exactly one of:
   - `REPAIRED_AND_PASSED`
   - `REPAIRED_BUT_STILL_FAILING`
   - `BLOCKED_NEEDS_HUMAN`
   - `SCOPE_OR_POLICY_NEEDS_APPROVAL`
3. Update `handoff.md` with:
   - repair outcome
   - latest run directory
   - failure cause
   - fix applied
   - remaining blockers
   - next action
