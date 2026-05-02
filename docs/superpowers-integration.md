# Superpowers Integration

Agent-Repo-Harness assumes the coding agent already has Superpowers installed.
Superpowers defines the agent workflow. This harness defines the repo-local
context, boundaries, risk policy, verification commands, and completion gates.

## Conceptual Split

Superpowers controls:

- brainstorming
- writing plans
- using git worktrees
- TDD
- subagent-driven development
- requesting reviews
- finishing a development branch

Agent-Repo-Harness controls:

- repo-local memory
- current handoff state
- task scope
- optional subagent context packet shape
- high-risk path policy
- verification commands
- completion gates

## Skill Bridge

| Superpowers skill | Agent-Repo-Harness bridge |
|---|---|
| `using-superpowers` | Agent must follow Superpowers first, then repo-local harness rules |
| `using-git-worktrees` | Run `scripts/agent-preflight.sh` inside the selected worktree |
| `writing-plans` | Translate the current plan task/files section into `.agent/task.yml` |
| `subagent-driven-development` | Use repo context from `agent.md`, `handoff.md`, `.agent/task.yml`, and optional `.agent/subagent-packet.yml` when preparing subagent prompts |
| `test-driven-development` | Use `scripts/agent-verify.sh` to preserve verification evidence |
| `finishing-a-development-branch` | Run `scripts/agent-finish.sh`, then update `handoff.md` |

## Typical Flow

1. Install Superpowers.
2. Install Agent-Repo-Harness into the target repo.
3. Run `scripts/agent-preflight.sh`.
4. Use Superpowers to brainstorm and write a plan.
5. Translate the current Superpowers plan task into `.agent/task.yml`.
6. For delegated work, fill `.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh`.
7. Execute with Superpowers subagent-driven development.
8. Run `scripts/agent-finish.sh`.
9. Update `handoff.md`.

## Non-goals

- This harness does not dispatch subagents.
- This harness does not require subagent packets in `agent-finish.sh` yet.
- This harness does not replace Superpowers skills.
- This harness is not a sandbox.
- This harness assumes repo-owned config is trusted.

## Limitations

- Not a sandbox.
- Does not prevent malicious shell commands.
- Does not replace human code review.
- Does not prove semantic correctness.
- Assumes repo-owned config is trusted.
