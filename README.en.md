# Agent-Repo-Harness

Chinese version: [README.md](README.md)

## Goal

This repository is evolving `Agent-Repo-Guide` into `Agent-Repo-Harness`.

The key design rule is unchanged:

- **Do not replace Superpowers**
- **Superpowers remains the development workflow engine**
- **Agent-Repo-Harness provides the repo-aware control layer**

The split is:

```text
Superpowers
  = brainstorming / writing-plans / subagent-driven-development
  = test-driven-development / code review / finishing branch

Agent-Repo-Harness
  = agent.md / handoff.md / policy gates / verification gates
  = subagent context packets / discoveries memory / domain risk review
```

## Quick Start

1. Install the harness into a target repo:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
```

2. In the target repo, run:

```bash
bash scripts/agent-preflight.sh
bash scripts/check-agent-md.sh agent.md
bash scripts/agent-verify.sh
```

3. Use `harness-entrypoint` before non-trivial repo work.
4. Use Superpowers for design, planning, TDD, execution, and review.

## What This Repo Now Provides

- `templates/`
  - `agent.md` and `handoff.md` templates
  - `docs/agent/` long-term and short-term memory templates
  - `scripts/` safe-by-default preflight, verification, policy, and context helpers
  - `.agent/` harness and policy configuration
- `skills/`
  - `harness-entrypoint`
  - `repo-context-bootstrap`
  - `repo-map-maintenance`
  - `handoff-update`
  - `subagent-context-packet`
  - `policy-gate`
  - `verification-gate`
  - `discoveries-memory`
  - `domain-risk-review`
- `install-agent-harness.sh`
  - copies the `templates/` payload into a target repository
- `examples/`
  - Go IoT platform
  - RAG contract system

## Relationship To The Existing Guide Skills

This migration is additive first. The original skills remain in place:

- `project-agent-docs`
- `project-map-agent-md`
- `update-agent-handoff`

Mapping:

| Existing concept | New harness module |
| --- | --- |
| `project-agent-docs` | `harness-entrypoint` + `repo-context-bootstrap` |
| `project-map-agent-md` | `repo-map-maintenance` |
| `update-agent-handoff` | `handoff-update` |

The legacy content stays until the harness replacements are fully established.

## Install

Install the harness payload into a target repository:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
```

Existing files are skipped by default. Use `--force` only when you intentionally want to overwrite them.
Use `--backup` together with `--force` when you want overwritten files preserved as `.bak`.

## Typical Workflow

1. Install the harness templates into a target repo.
2. Use `harness-entrypoint` or `repo-context-bootstrap` to load repo-aware context.
3. Use Superpowers for design, planning, TDD, implementation, review, and branch finishing.
4. Before dispatching subagents, use `subagent-context-packet`.
5. Before claiming completion, run:

```bash
scripts/check-policy.sh
scripts/agent-verify.sh
```

6. Update `handoff.md` and `docs/agent/discoveries.md`.

## File Responsibilities

- `agent.md`: stable repo map and repo-specific operating rules
- `handoff.md`: current task state only
- `docs/agent/known-issues.md`: durable gotchas and repeated pitfalls
- `docs/agent/discoveries.md`: short-term findings for later subagents
- `.agent/harness.yml`: harness behavior and workflow expectations
- `.agent/policy.yml`: high-risk patterns and finish gates
- `scripts/`: preflight, policy, context, and verification helpers

## Example Prompts

- `Use $harness-entrypoint before implementing this feature in the current repo.`
- `Use $repo-context-bootstrap to initialize Agent-Repo-Harness files for this project.`
- `Use $subagent-context-packet before dispatching a coding subagent for the auth fix.`
- `Use $handoff-update after this session and keep the result concise.`
- `Use $domain-risk-review on this retrieval pipeline change.`

## Design Principles

- Superpowers stays in charge of the development workflow
- Agent-Repo-Harness adds project-aware control, not a new runtime
- stable repo map and current task state stay separate
- policy and verification are explicit gates before completion
- discoveries should be captured and reused across sessions

## FAQ

**Does this replace Superpowers?**
No. It is designed to wrap around Superpowers and provide repo-aware control.

**Does this ship a runtime or MCP server?**
No. This repo only provides templates, scripts, skills, and examples.

**Should every repo use the default scripts unchanged?**
No. They are safe defaults and should be customized per target repo.

**Should `agent.md` contain the current implementation plan?**
No. Plans belong in planning docs, not in the stable repo map.

## Validation And Limits

This repository currently validates:

- shell script syntax
- installer script syntax
- template presence
- `templates/agent.md` structure via `check-agent-md.sh`

Current limits:

- this is not a full agent runtime
- this does not ship an MCP server
- `agent-verify.sh` provides best-effort checks and should be customized per target repo
- `check-policy.sh` is lightweight pattern matching, not a full policy engine

## References And Carried-Forward Assets

- shared labels and boundaries: [references/shared-spec.md](references/shared-spec.md)
- migration mapping: [references/harness-migration.md](references/harness-migration.md)
- regression cases: [references/evals/regression-cases.md](references/evals/regression-cases.md)
- legacy router skill: [project-agent-docs/SKILL.md](project-agent-docs/SKILL.md)
- legacy map maintenance skill: [project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md)
- legacy handoff update skill: [update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md)
