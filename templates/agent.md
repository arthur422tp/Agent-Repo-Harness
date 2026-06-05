# agent.md

> Put stable repo facts here.
> Do not use this file for one-time task instructions or repeated workflow
> prompts.

## Project Overview

## Context Loading

Keep this file compact enough to read at task start. Store stable facts, entrypoints, commands, risks, and links to deeper docs. Do not paste long source excerpts, historical plans, generated output, logs, or one-time task instructions here.

Use this loading order for ordinary tasks:

1. Read `AGENTS.md` or the installed agent entrypoint.
2. Read this file for stable facts.
3. Read `handoff.md` for current state.
4. Read `.agent/task.yml` for scope and completion requirements.
5. Read only applicable `.agent/policy.yml` rules.
6. Expand to source files with `rg` and targeted ranges.

When a repeated discovery matters, add a short `Verified:` or `Inferred:` note here or in `docs/agent/discoveries.md` instead of requiring future agents to rediscover it from raw files.

TODO: Describe what this repository does.

## Architecture Map
TODO: Describe the major modules and data flow.

## Important Entrypoints
- TODO

## Common Commands
- Install: TODO
- Test: TODO
- Lint: TODO
- Build: TODO
- Run: TODO

## Verification
Before claiming completion, run:

```bash
scripts/agent-finish.sh
```

Only claim verified if the finish gate passes. It runs the required policy,
scope, repo map, and verification checks.

Optional lifecycle evidence:
- Episode package metadata: `docs/agent/episode-package.md`
- Failure attribution: `docs/agent/failure-attribution.md`
- Intervention records: `docs/agent/interventions.md`
- Entropy audit: `docs/agent/entropy-audit.md`

Use `scripts/agent-audit.sh` for maintenance drift checks, not as a substitute
for `scripts/agent-finish.sh`.

## Superpowers Contract
This repo assumes Superpowers is installed.

Before implementation:
- Use Superpowers brainstorming or writing-plans when appropriate.
- Use git worktrees for feature work.
- Use TDD for feature, bugfix, refactor, and behavior changes.

During implementation:
- Keep changes within `.agent/task.yml`.
- Keep `.agent/episode.yml` objective and status aligned when present.
- Check `.agent/policy.yml` before touching high-risk areas.
- Fill required `.agent/failure-attribution.yml` and `.agent/interventions.yml`
  evidence when task completion flags require them.
- Keep commits small and task-scoped.

Before completion:
- Run `scripts/agent-finish.sh`.
- Update `handoff.md`.

## Risk Areas
- TODO: files or modules that should not be changed casually

## Agent Rules
- Do not invent repo facts.
- Mark uncertain items as `TODO:` or `Inferred:` until stronger evidence exists.
- Use `Verified:` only for facts backed by files, executable config, or command
  output.
- Prefer minimal patches over broad rewrites.
- Do not rewrite architecture unless explicitly requested.
- Do not claim verified unless the required policy, scope, and verification
  gates passed.
- Keep reusable workflow in skills and keep one-time task instructions in the
  live user prompt.
