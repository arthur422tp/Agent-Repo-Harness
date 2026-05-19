---
name: handoff-update
description: Update Agent-Repo-Harness handoff.md with concise current task state.
---

# Handoff Update

Use this skill when task state changes or before ending a session.

Update `handoff.md` with:

- current task
- current state
- confirmed facts
- changed files
- verification commands and results
- latest `.agent/runs/<timestamp>/finish-summary.md` path when available
- open issues or blockers
- next recommended action

When the work follows a failed `scripts/agent-finish.sh` run, include a repair
outcome section with:

- Repair outcome (`REPAIRED_AND_PASSED`, `REPAIRED_BUT_STILL_FAILING`,
  `BLOCKED_NEEDS_HUMAN`, or `SCOPE_OR_POLICY_NEEDS_APPROVAL`)
- Latest run directory
- Failing gate before repair
- Fix applied
- Remaining blocker
- Next action

Keep `handoff.md` current-task focused. Stable repo facts belong in `agent.md`.
Machine-readable task boundaries belong in `.agent/task.yml`.
