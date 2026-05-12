# Context Loading Policy

Agent-Repo-Harness uses staged context loading to keep agent runs token-efficient.

## Default Startup Context

Start compact. For ordinary tasks, read only:

1. `AGENTS.md` or `CLAUDE.md`
2. `agent.md`
3. `handoff.md`
4. `.agent/task.yml`
5. applicable entries from `.agent/policy.yml`

Do not read all docs, examples, schemas, scripts, generated files, logs, lockfiles, or historical plans by default.

## Compact Context Collection

Use:

```bash
scripts/collect-context.sh
```

The default compact mode prints startup-critical context only:

- git status and recent commits
- `agent.md`
- `handoff.md`
- `.agent/task.yml`
- `.agent/policy.yml`

## Full Context Collection

Use:

```bash
scripts/collect-context.sh --full
```

Use full mode only when debugging stale repo memory, policy drift, handoff gaps, or repeated pitfalls. Full mode may include optional files such as:

- `docs/agent/known-issues.md`
- `docs/agent/discoveries.md`

## Expanding Context

Expand only to files directly relevant to the current task.

Prefer:

- `rg`
- file lists
- symbol search
- targeted file ranges such as `sed -n '1,120p' path/to/file`

Avoid reading whole directories or long files unless the task specifically requires it.

## Failed Gate Workflow

After `scripts/agent-finish.sh` fails:

1. Read `.agent/runs/<latest>/finish-summary.md`.
2. Read only the failing gate result file, such as:
   - `scope-result.txt`
   - `policy-result.txt`
   - `tdd-evidence-result.txt`
   - `acceptance-result.txt`
   - `review-result.txt`
   - `verify-result.txt`
3. Fix the smallest relevant scope.
4. Rerun `scripts/agent-finish.sh`.

Do not read all historical `.agent/runs/` directories.

## Persisting Discoveries

When context grows, summarize reusable findings in:

- `handoff.md` for current task state
- `docs/agent/discoveries.md` for reusable discoveries
- `agent.md` only for stable repo facts

Prefer concise summaries and links over copying raw file contents into repo memory.
