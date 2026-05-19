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

Optional lifecycle prompts are also available under `adapters/codex/`:

- `codex-repair-prompt.md` for focused post-failure repair after
  `scripts/agent-finish.sh`, including a repair outcome convention
  (`REPAIRED_AND_PASSED`, `REPAIRED_BUT_STILL_FAILING`,
  `BLOCKED_NEEDS_HUMAN`, or `SCOPE_OR_POLICY_NEEDS_APPROVAL`)
- `codex-verify-prompt.md` for strict completion verification
- `codex-handoff-prompt.md` for concise durable `handoff.md` updates

These prompts are optional adapter documentation. They are not auto-installed
into target repositories.

Canonical reusable start prompt: `adapters/codex/codex-start-prompt.md`
Use it to keep staged context loading instructions identical to the adapter.

Optional repair prompt: `adapters/codex/codex-repair-prompt.md`

Optional verify prompt: `adapters/codex/codex-verify-prompt.md`

Optional handoff prompt: `adapters/codex/codex-handoff-prompt.md`
