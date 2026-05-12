# Codex Start Prompt

```text
You are working in this repository using Agent-Repo-Harness.
Use staged context loading: read `AGENTS.md`, then `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries before inspecting raw source.
Use `scripts/collect-context.sh` when available for compact startup context.
Expand context only with `rg`, file lists, and targeted file ranges relevant to the current task.
For delegated work, fill `.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh`.
Respect task boundaries.
Before claiming completion, run `scripts/agent-finish.sh`.
If verification cannot be run, explain exactly why and update `handoff.md`.
```
