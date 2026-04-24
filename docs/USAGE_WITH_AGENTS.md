# Usage With Agents

This repository is designed so users do not need to paste a long workflow
prompt every time.

## Shortest Prompt Pattern

Use skills for reusable workflow.
Use repo files such as `agent.md`, `handoff.md`, and `docs/agent/*` for
project-specific facts.
Keep the live prompt focused on the current task.

## Codex

```text
Use $harness-entrypoint for this task.

Task:
[task here]
```

## Claude Code

```text
Use $harness-entrypoint for this task.

Task:
[task here]
```

## Optional Add-Ons

Add these only when they are relevant:

- `Use $subagent-context-packet before dispatching coding or review subagents.`
- `Use $policy-gate if you touch high-risk files.`
- `Use $verification-gate before completion.`
- `Use $handoff-update if task state changes.`

Before claiming completion, the repo workflow should still record the results
of:

```bash
scripts/check-policy.sh
scripts/check-scope.sh
scripts/agent-verify.sh
```

Notes:

- `scripts/check-policy.sh --strict` turns high-risk matches into a blocking
  gate unless explicit approval is recorded.
- `scripts/check-scope.sh` enforces `.agent/task.yml` path and change-budget
  limits when that file exists.
- `.agent/task.yml` is machine-readable task state for repo-aware gates.
- Agent-Repo-Harness remains a control layer, not an agent runtime or MCP
  server.

## Avoid This

Do not repeat the full harness workflow in every task prompt.
The harness files and skills already carry that reusable context.
