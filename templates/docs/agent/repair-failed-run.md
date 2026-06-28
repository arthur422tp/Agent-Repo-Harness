# Repair Failed Finish Runs

Use this protocol when `scripts/agent-finish.sh` exits non-zero. A failed
finish run means the agent must inspect the run evidence, repair the failing
condition, rerun the relevant check, and rerun `scripts/agent-finish.sh`
before claiming completion.

Do not claim completion from a failed finish run. Do not widen scope, weaken
policy, or mark evidence as passing only to make the gate pass.

## Evidence Location

Each finish run writes evidence under `.agent/runs/<timestamp>/`.

Start with:

- `finish-summary.md`
- `finish-summary.json`
- the gate-specific `*-result.txt` file named by the failing row
- `changed-files.txt`
- `git-diff-stat.txt`

## Failure Classes

| Failure class | Primary evidence file | Meaning | Agent repair procedure | Human escalation condition |
| --- | --- | --- | --- | --- |
| `check-agent-md` failed | `check-agent-md-result.txt` | Required stable agent context is missing or invalid. | Restore or update the required agent context file, then rerun the check. | Escalate if the repo intentionally removed the context contract. |
| `check-scope` failed | `scope-result.txt`, `changed-files.txt` | Changed files are outside `.agent/task.yml` scope. | Revert unrelated edits or ask for explicit scope expansion. Do not silently widen `allowed_paths`. | Escalate when the task truly requires paths outside the approved scope. |
| `check-policy` failed | `policy-result.txt` | A policy or protected-path rule blocked the change. | Avoid the protected path if possible. If required, stop for explicit human approval. | Escalate for any high-risk approval or protected path that must change. |
| `check-tdd-evidence` failed | `tdd-evidence-result.txt` | Required TDD evidence is missing or malformed. | Fill the structured TDD evidence from real test commands and rerun the check. | Escalate if the task is intentionally non-testable. |
| `check-acceptance` failed | `acceptance-result.txt` | Acceptance criteria are missing, unmet, or weakly evidenced. | Fix `.agent/acceptance.yml`. If strict refs are enabled, bind run artifacts with `scripts/agent-evidence-bind.sh`, rerun `scripts/check-acceptance.sh`, then rerun finish. | Escalate if criteria need product clarification. |
| `check-review-evidence` failed | `review-result.txt` | Required review evidence is missing or not accepted. | Add real review evidence or perform the requested review step. | Escalate if human review is required. |
| `check-architecture-evidence` failed | `architecture-evidence-result.txt` | Architecture evidence is missing, malformed, or says an invariant is violated. | Determine whether the invariant is actually violated. Fix design if violated; otherwise add command-backed evidence. | Escalate if the invariant conflicts with the requested change. |
| `check-failure-attribution` failed | `failure-attribution-result.txt` | Required failure attribution is missing or incomplete. | Record the failed command, cause, fix, and verification before rerunning finish. | Escalate if the cause cannot be determined after investigation. |
| `check-interventions` failed | `interventions-result.txt` | Required intervention records are missing or incomplete. | Record human intervention or approval details that actually occurred. | Escalate if the needed approval did not occur. |
| `check-command-ledger` failed | `command-ledger-result.txt` | Required command ledger evidence is missing or inconsistent. | Record real commands and outcomes; rerun the command if evidence is stale. | Escalate if a required command cannot be rerun. |
| `check-sandbox-evidence` failed | `sandbox-evidence-result.txt` | Required sandbox evidence is missing, failed, or skipped without allowed reason. | Run the sandbox helper where available or record an allowed skip. | Escalate when the task requires sandbox evidence but no runner is available. |
| `check-subagent-evidence` failed | `subagent-evidence-result.txt` | Required delegated-run evidence is missing or incomplete. | Add real subagent packet and run evidence. | Escalate if delegation was required but not performed. |
| `validate-episode` failed | `episode-result.txt`, `episode-summary.json` | Episode package metadata is missing or invalid. | Fix episode metadata and regenerate validation evidence. | Escalate if the episode contract is not applicable. |
| `agent-verify` failed | `verify-result.txt` | Repository verification failed. | Fix code or tests, rerun verification, then rerun finish. | Escalate when the failure is environmental or contradicts task requirements. |
| `resource-envelope` failed | `resource-envelope-result.txt` | Finish duration or changed-file count exceeded configured limits. | Reduce scope or ask for explicit limit changes. | Escalate if the configured limit is too small for the approved task. |

## Repair Loop

1. Read `.agent/runs/<timestamp>/finish-summary.md`.
2. Open the primary evidence file for the failing gate.
3. Repair the underlying cause.
4. Rerun the specific failing check when possible.
5. Rerun `scripts/agent-finish.sh`.
6. Update `handoff.md` with the new run evidence.
7. Claim completion only after the final finish run passes.
