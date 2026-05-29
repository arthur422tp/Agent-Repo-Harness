# Handoff And Evidence Model

Agent-Repo-Harness separates completion evidence from continuity handoff state.
This keeps the harness a low-friction repo-local completion gate instead of a
runtime, orchestrator, sandbox, or semantic correctness system.

## Layer 1: Script-Generated Run Evidence

`.agent/runs/<timestamp>/` is the authoritative evidence for a completion run.
It is created by `scripts/agent-finish.sh` and is tied to one command
invocation.

Typical files include:

- `finish-summary.md`
- `scope-result.txt`
- `policy-result.txt`
- `verification-result.txt`
- `tdd-evidence-result.txt`
- `acceptance-result.txt`
- `review-result.txt`
- `subagent-evidence-result.txt`
- `changed-files.txt`
- `git-diff-stat.txt`

Use this layer to answer what the finish gate actually checked, which gates
passed or failed, and what repository changes existed at finish time.

## Layer 2: Human-Readable Handoff

`handoff.md` is written by the model or human operator. It is a concise
continuity note, not a gate result and not a complete execution log.

It should include:

- current task state
- changed files
- verification commands and results
- the latest `.agent/runs/<timestamp>/finish-summary.md` path when available
- open blockers or remaining issues
- next recommended action

Updating `handoff.md` is a documented workflow step. `scripts/agent-finish.sh`
does not enforce that it is fresh.

## Layer 3: Optional Structured Handoff

`.agent/handoff.yml` is an optional machine-readable mirror of the handoff
state. It exists for validators, CI, controller agents, and future automation
that need structured fields.

Validate it directly with:

```bash
bash scripts/validate-handoff.sh
```

That validator is standalone. It checks the structured handoff file when asked;
it is not part of `scripts/agent-finish.sh`.

## Task Flag Semantics

`.agent/task.yml` may set:

```yaml
completion:
  expects_handoff_update: true
```

This means the workflow expects an operator or model to update `handoff.md`
after completion or pause. It does not mean handoff freshness is a mandatory
completion gate.

The authoritative completion evidence remains `.agent/runs/<timestamp>/`.
