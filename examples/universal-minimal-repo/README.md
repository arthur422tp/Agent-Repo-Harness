# Universal Minimal Repo Example

This example shows the intended installed shape for a small repository that
supports Codex, Claude Code, Superpowers-compatible agents, and generic agents.

Files included:

- `AGENTS.md`: generic and Codex-compatible entrypoint
- `CLAUDE.md`: Claude Code-compatible entrypoint
- `agent.md`: stable repo map
- `handoff.md`: current task state
- `.agent/harness.yml`: harness configuration
- `.agent/policy.yml`: policy configuration
- `.agent/task.yml`: task scope
- `scripts/`: dependency-light harness gates

Typical flow:

```bash
bash scripts/agent-preflight.sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/check-scope.sh
bash scripts/check-policy.sh
bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

After `agent-finish.sh`, inspect `.agent/runs/<timestamp>/finish-summary.md`
for the recorded gate summary.
