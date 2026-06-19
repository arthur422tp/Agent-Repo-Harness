# Superpowers Integration

Agent-Repo-Harness is designed to work alongside
[obra/superpowers](https://github.com/obra/superpowers), not replace it.
Superpowers drives agent behavior and workflow. Agent-Repo-Harness enforces
repo-local contracts, validation gates, and durable evidence.

The harness makes Superpowers workflows auditable and repo-specific. A coding
agent should still use the relevant Superpowers skill for planning, TDD,
subagent orchestration, review, verification, and completion. The harness then
records the accepted task shape, local boundaries, evidence files, and command
results inside the repository.

## Responsibility Split

Superpowers skills should respect staged context loading. Planning and execution skills can ask for focused evidence, but they should prefer `agent.md`, `handoff.md`, `.agent/task.yml`, `.agent/policy.yml`, and `scripts/collect-context.sh` before loading broad raw source or historical plans.

Sandbox verification is an optional final verification envelope. It records
evidence from a configured external runner without taking over Superpowers
verification discipline.

Command ledger evidence complements Superpowers
`verification-before-completion` by recording important local verification
commands run explicitly through `scripts/agent-run.sh`. It does not replace
the skill's evidence discipline or capture commands outside that runner.

| Concern | Superpowers skill | Agent-Repo-Harness component |
|---|---|---|
| Planning | `writing-plans` | `.agent/task.yml` |
| Exploration / ideation | `brainstorming` | `docs/agent/decisions/` |
| Git isolation | `using-git-worktrees` | `scripts/agent-preflight.sh` |
| TDD discipline | `test-driven-development` | `.agent/tdd-evidence.yml` + `scripts/check-tdd-evidence.sh` |
| Subagent orchestration | `subagent-driven-development` | `.agent/subagent-packet.yml` + `.agent/subagent-runs/<timestamp>-<role>-<task_id>/` |
| Spec review | `subagent-driven-development` / `requesting-code-review` | subagent packet role: `spec_reviewer` |
| Quality review | `subagent-driven-development` / `requesting-code-review` | subagent packet role: `quality_reviewer` |
| Verification | `verification-before-completion` | `scripts/agent-verify.sh` |
| Command ledger | `verification-before-completion` | `scripts/agent-run.sh` + `.agent/command-runs/<timestamp>/` |
| Isolated final verification | `verification-before-completion` | `scripts/agent-sandbox-run.sh` + `.agent/sandbox-runs/<timestamp>/` |
| Completion | `finishing-a-development-branch` | `scripts/agent-finish.sh` + `.agent/runs/<timestamp>/finish-summary.md` |
| Handoff | `finishing-a-development-branch` / handoff-update style workflow | `handoff.md` |

## Example Flow

1. Use Superpowers `writing-plans` to define the task.
2. Translate the accepted task into `.agent/task.yml`.
3. Use Superpowers `test-driven-development` while implementing.
4. Record red/green evidence in `.agent/tdd-evidence.yml` when required.
5. If delegating work, create `.agent/subagent-packet.yml`.
6. Validate the packet with `scripts/validate-subagent-packet.sh`.
7. Optionally record delegated results under
   `.agent/subagent-runs/<timestamp>-<role>-<task_id>/`.
8. Run `scripts/check-scope.sh`, `scripts/check-policy.sh`,
   `scripts/check-tdd-evidence.sh`, and `scripts/agent-verify.sh`.
9. If `.agent/task.yml` requires sandbox verification, run
   `scripts/agent-sandbox-run.sh` before `scripts/agent-finish.sh`. The finish
   gate validates the resulting sandbox evidence; it does not dispatch the
   sandbox run itself.
10. Run `scripts/agent-finish.sh`.
11. Update `handoff.md` with results and next action.

## Subagent Packet Alignment

The obra/superpowers `subagent-driven-development` workflow emphasizes:

- fresh subagent per task
- precise context provided by the controller
- status values such as `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, and
  `BLOCKED`
- spec review before quality review

`.agent/subagent-packet.yml` supports this by making handoff context explicit
and repeatable. It gives the controller a repo-local place to record the task
text, role, allowed paths, relevant files, required verification, expected
status enum, and any notes the subagent needs. The packet is optional and is
validated separately with `scripts/validate-subagent-packet.sh`.

`subagent-driven-development` can be paired with both
`.agent/subagent-packet.yml` and
`.agent/subagent-runs/<timestamp>-<role>-<task_id>/`. The packet records the
handoff context; the run directory records trace evidence after delegation,
including the copied `packet.yml`, `result.md`, and `status.txt`. This harness
records that evidence but does not dispatch subagents.

## What the Harness Should Not Do

- It should not replace Superpowers.
- It should not decide the whole workflow by itself.
- It should not make subagent packets mandatory for every task yet.
- It should not make subagent run evidence mandatory for every task yet.
- It should not treat evidence files as proof of semantic correctness.
- It should not hide human judgment or review.

## Non-goals

- This harness does not dispatch subagents.
- This harness does not integrate subagent packet validation into
  `scripts/agent-finish.sh` yet.
- This harness does not integrate subagent run evidence into
  `scripts/agent-finish.sh` yet.
- This harness does not change when TDD evidence is required.
- This harness does not replace Superpowers verification workflows with
  sandbox orchestration.
- This harness is not a sandbox or runtime orchestrator.
- This harness assumes repo-owned config is trusted.
