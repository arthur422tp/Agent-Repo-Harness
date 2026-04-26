# agent.md

> Put stable repo facts here.
> Do not use this file for one-time task instructions or repeated workflow
> prompts.

## Project Overview
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

## Superpowers Contract
This repo assumes Superpowers is installed.

Before implementation:
- Use Superpowers brainstorming or writing-plans when appropriate.
- Use git worktrees for feature work.
- Use TDD for feature, bugfix, refactor, and behavior changes.

During implementation:
- Keep changes within `.agent/task.yml`.
- Check `.agent/policy.yml` before touching high-risk areas.
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
