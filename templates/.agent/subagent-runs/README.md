# Subagent Run Evidence

This directory is an optional place for controller agents to record durable
evidence from delegated subagent work. It is a trace convention only; the
harness does not dispatch subagents and this evidence is not part of
`scripts/agent-finish.sh` yet.

Use one directory per delegated run:

```text
.agent/subagent-runs/<timestamp>-<role>-<task_id>/
  packet.yml
  result.md
  status.txt
```

- `packet.yml` is the exact handoff packet used for the subagent.
- `result.md` records what the subagent did, inspected, changed, verified,
  found, and recommends next.
- `status.txt` contains exactly one final status:
  `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.

Validate a run directory with:

```bash
bash scripts/validate-subagent-run.sh .agent/subagent-runs/<timestamp>-<role>-<task_id>
```
