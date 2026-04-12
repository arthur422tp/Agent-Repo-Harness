---
name: |
  project-map-agent-md
description: |
  Build or rebuild canonical repo guidance from concrete
  repository evidence.
---

# Project Map Agent.md

Build the stable repo map only after routing is complete.

## Core Model

- `agent.md` is the map.
- Planning docs are navigation.
- Handoff is the current position.
- NEVER store planning or session state here.

## Preconditions

- You MUST assume routing is already decided.
- You MUST have concrete repo evidence before building a full map.
- You MUST stop if the repo is only a bare folder, vague idea text, or lacks manifest, README, entrypoint, test, config, infra, or schema evidence.
- If evidence is insufficient, you MUST output a minimal low-evidence fallback only.

## Workflow

1. Run the readiness gate.
2. Scan only enough evidence to identify stable architecture.
3. Preserve an existing valid canonical root filename. Otherwise use `agent.md`.
4. Keep only one full canonical root guidance file.
5. Build the root map first.
6. Add module guidance ONLY when local complexity or risk would otherwise bloat the root map.
7. Keep every uncertain fact labeled.

## Scan Order

1. Existing guidance and `README*`
2. Manifests, lockfiles, workspace config
3. Entrypoints, bootstrap, apps, CLI entrypoints
4. Tests, CI, lint, format config
5. Infra, deploy, Docker, env files
6. Schemas, migrations, OpenAPI, GraphQL, protobuf, shared contracts
7. Risk boundaries: auth, billing, secrets, permissions, integrations, generated code

## Stop Criteria

You MUST stop scanning once all of these are true:

- the main entrypoint or startup path is known or explicitly `TODO:`
- the main runtime, app, or workspace boundary is known
- the most important modules, contracts, or risks can be named with evidence labels
- the `Fast-Start Map` can point to concrete read-first paths
- more scanning would add detail more than navigation

## Evidence Rules

- `Verified:` ONLY for facts confirmed by files, executable repo config, or command output.
- `Inferred:` ONLY for facts suggested by names, imports, conventions, or framework patterns.
- `TODO:` ONLY for facts still worth confirming.
- `Verified command` MUST come from package scripts, Makefile, task config, CI invocation, or direct execution.
- `Verified dependency edge` MUST come from bootstrap wiring, router wiring, DI config, manifest linkage, schema ownership, external contract reference, or runtime config.
- You MUST NEVER promote `Inferred:` or `TODO:` to `Verified:` without stronger evidence.

## Output Constraints

- Root output MUST use ONLY these sections:
  - `Project Overview`
  - `Fast-Start Map`
  - `Repository Tree`
  - `Module Index`
  - `Pseudo-DSL`
  - `Adjacency List`
  - `Risk Map`
  - `Tooling & Commands`
  - `Known Gaps / TODO`
- `Fast-Start Map` MUST list concrete read-first paths, not vague folder names.
- `Module Index` MUST include ONLY defensible modules.
- `Pseudo-DSL` and `Adjacency List` MUST show runtime, ownership, or contract edges only.
- You MUST NEVER rewrite the directory tree as fake runtime edges.
- You MUST NEVER optimize for section completeness over navigational usefulness.
- If evidence is weak, you MUST output a smaller map.
- The root map MUST stay under 120 lines unless the repo shape makes that impossible.
- Module guidance MUST stay under 80 lines per file.

## Low-Evidence Fallback

If evidence is partial but not empty:

- You MUST keep only `Project Overview`, `Fast-Start Map`, and `Known Gaps / TODO`.
- You MUST add `Module Index` only for modules you can defend.
- You MUST point `Fast-Start Map` to the files most likely to resolve uncertainty.
- You MUST use references for examples instead of embedding examples here.

## Module Threshold

Create module guidance ONLY when at least one is true:

- the module has an independent runtime or entrypoint
- the module owns a contract, schema, migration, deploy boundary, auth flow, billing flow, or security boundary
- the module is a frequent task entrypoint
- omitting local guidance would bloat the root map

## Final Checks

- one full canonical root file only
- no handoff state
- no planning detail
- labels remain distinct
- commands and edges use evidence thresholds
