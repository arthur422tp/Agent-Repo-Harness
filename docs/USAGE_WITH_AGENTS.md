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
scripts/agent-verify.sh
```

## Avoid This

Do not repeat the full harness workflow in every task prompt.
The harness files and skills already carry that reusable context.
