# Codex Usage

Use Agent-Repo-Harness with Codex as a short repo-local contract.

1. Open the target repository in Codex.
2. Ensure `AGENTS.md`, `agent.md`, `handoff.md`, `.agent/policy.yml`, and
   `.agent/task.yml` exist.
3. Ask Codex to read `AGENTS.md` first.
4. For scoped tasks, fill `.agent/task.yml` before asking Codex to modify code.
5. Ask Codex to run `scripts/agent-preflight.sh` before making changes.
6. Ask Codex to follow `allowed_paths` and `forbidden_paths` in
   `.agent/task.yml`.
7. Ask Codex to run `scripts/agent-finish.sh` before final response.
8. Ask Codex to update `handoff.md` with changed files, verification commands,
   remaining blockers, and next recommended action.

Reusable start prompt:

```text
You are working in this repository using Agent-Repo-Harness.
First read `AGENTS.md`, then follow its instructions.
Before editing, inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.
Respect task boundaries.
Before claiming completion, run `scripts/agent-finish.sh`.
If verification cannot be run, explain exactly why and update `handoff.md`.
```
