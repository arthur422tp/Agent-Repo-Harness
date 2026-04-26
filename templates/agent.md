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
scripts/check-policy.sh
scripts/check-scope.sh
scripts/agent-verify.sh
```

Only claim verified if the required commands pass.

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
