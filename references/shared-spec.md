# Shared Repo-Guidance Spec

Use this file for shared vocabulary and hard boundaries only.

## Three-Layer Model

- `agent.md`: stable repo map
- planning docs: future execution steps
- handoff: current position and short next-session state

These layers MUST stay separate.

## Shared Labels

- `Verified:` confirmed by files, executable repo config, or command output
- `Inferred:` suggested by names, imports, conventions, or framework patterns only
- `TODO:` worth confirming before promotion to `Verified:`

Promotion rules:

- `Verified command` ONLY from package scripts, Makefile, task config, CI invocation, or direct execution
- `Verified dependency edge` ONLY from runtime wiring, manifest linkage, schema ownership, external contract reference, or runtime config
- `Inferred command` ONLY from docs or conventional tooling guesses
- `Inferred dependency edge` ONLY from imports, naming, or directory convention

## Shared Boundaries

- planning docs MUST own detailed next steps, execution order, and file-by-file tasks
- `agent.md` MUST NOT store session state or plan detail
- handoff MUST NOT become a plan, history log, or execution narrative
- examples and long explanations MUST stay in `references/`, not in `SKILL.md`

## Shared File Rules

- keep only one full canonical root guidance file
- preserve the existing canonical filename when valid
- do not create parallel full-content root guidance files
