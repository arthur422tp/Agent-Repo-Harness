# Project Agent Docs Skills Usage Guide

Chinese version: [README.md](README.md)

This repo contains three skills for Codex or agent workflows. The design is intentionally three-layered:

- `agent.md` is the map
- planning docs are navigation
- handoff is the current position

Do not mix them.

## Included Skills

| Skill | Purpose |
| --- | --- |
| `project-agent-docs` | Router and dispatcher for repo-guidance work. |
| `project-map-agent-md` | Creates or rebuilds canonical repo guidance from concrete repository evidence. |
| `update-agent-handoff` | Updates compact handoff state and decides whether an existing canonical map needs a minimal patch. |

## Routing Rules

| Goal | Recommended Skill |
| --- | --- |
| Unsure which repo-guidance workflow to use | `$project-agent-docs` |
| First canonical repo map from concrete repo evidence | `$project-map-agent-md` |
| Existing canonical guidance may be stale and needs patch-level refresh | `$update-agent-handoff` |
| Session state, current focus, blockers, or resume context | `$update-agent-handoff` |
| Detailed implementation plan, test plan, or file-by-file task breakdown | Use a planning workflow such as `writing-plans`, not these repo-guidance skills |
| Repo is still mostly an idea or a bare folder | Gather concrete repo evidence first; do not force a full canonical map |

## Router Decisions That Must Stay Stable

- Prefer patching existing canonical guidance before rebuilding it.
- Rebuild only when the current canonical guidance is missing, broken, or too misleading to patch safely.
- If a request mixes "refresh repo understanding" with "tell me what to do next", handle repo guidance first and keep the next-step output to a short pointer or plan link.
- Planning docs remain the source of future steps.
- Handoff records only current focus, progress delta, blockers, and a related-plan pointer.
- Small diffs in high-impact files still require deeper significance review.

High-impact files include:

- workspace config
- package manifests and lockfiles
- CI or deploy config
- Docker, compose, or infra config
- env examples or env schema
- migrations, schema, OpenAPI, GraphQL, protobuf, or generated clients
- shared packages, common contracts, bootstrap files, or router registration
- auth, billing, permissions, secrets, or external integrations

These files may imply architecture, runtime, contract, or command changes even when the local directory diff looks small.

## Canonical agent.md Shape

`project-map-agent-md` keeps the root guidance compact, navigable, and evidence-based:

- `Project Overview`
- `Fast-Start Map`
- `Repository Tree`
- `Module Index`
- `Pseudo-DSL`
- `Adjacency List`
- `Risk Map`
- `Tooling & Commands`
- `Known Gaps / TODO`

Constraints:

- `Fast-Start Map` should list read-first paths with real navigational value.
- `Module Index` should prefer `role`, `path`, `owns`, `depends_on`, `used_by`, and `risk` when evidence exists.
- `Pseudo-DSL` and `Adjacency List` should show runtime, ownership, and contract edges, not rephrase the directory tree.
- If evidence is thin, produce a smaller high-signal map.
- Do not optimize for section completeness at the cost of navigational usefulness.

## Handoff Shape

`update-agent-handoff` keeps handoff intentionally thin and state-only:

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

Rules:

- `Next pointer` must be one short pointer, not a multi-step plan.
- `Progress` should capture only the most important delta since the related plan or prior session.
- Do not preserve history logs, long explanations, or execution narratives.
- If detailed next steps exist, link to the planning doc instead of copying them into handoff.

## When agent.md Should Change

`update-agent-handoff` should patch canonical guidance only when architecture-significant facts changed, such as:

1. repository tree or module boundaries
2. entry points or startup path
3. cross-module dependencies or data flow
4. external contracts such as APIs, schemas, migrations, or integrations
5. tooling commands backed by executable repo evidence
6. risk map or skip zones
7. an important `TODO:` or `Inferred:` fact that is now verified

Calibration rules:

- code-level dependency change does not automatically mean architecture-level dependency change
- internal refactor does not automatically mean module ownership change
- a new file does not automatically mean a new module
- new tests usually do not require `agent.md` updates unless they reveal a new entry point, runtime boundary, external contract, or previously unknown structure
- docs mentioning a command do not make it a verified command
- imports do not automatically equal runtime dependencies
- shared type, DTO, schema, or contract changes require elevated review
- function-internal changes, local helpers, naming, test coverage, or copy changes usually do not require `agent.md` updates

## Evidence Labels

Use labels as a method, not decoration:

- `Verified command`: present in package scripts, Makefile, task-runner config, CI invocation, or directly executed and confirmed
- `Inferred command`: docs mention only, or a conventional framework or tooling guess
- `Verified dependency edge`: proven by router wiring, bootstrap registration, DI config, manifest or workspace linkage, schema ownership, external contract reference, or runtime config
- `Inferred dependency edge`: suggested only by imports, names, or directory conventions
- `TODO`: still unknown and worth confirming

Never promote `Inferred:` or `TODO:` to `Verified:` without stronger evidence.

## Evaluation Cases

Regression examples live in [references/evals/regression-cases.md](references/evals/regression-cases.md). They cover:

- small monolith repo
- frontend/backend split repo
- monorepo
- infra-heavy repo
- repo with stale `agent.md`
- repo with planning docs but no canonical map
- small diff that actually changes a shared contract

Each case records:

- input context
- expected route
- whether `agent.md` should update
- whether handoff should update
- failure mode to avoid

## Install

Copy the three skill directories into your Codex skills directory. For example, on Windows PowerShell:

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

## Example Prompts

```text
Use $project-agent-docs to choose the right canonical repo guidance workflow.
```

```text
Use $project-map-agent-md to create a compact canonical repo guidance map from this repo's concrete files and docs.
```

```text
Use $update-agent-handoff to refresh compact current-state guidance and patch agent.md only if the architecture-significance gate passes.
```

## Repository Layout

```text
project-agent-docs/
  SKILL.md
  agents/openai.yaml
project-map-agent-md/
  SKILL.md
  agents/openai.yaml
  references/examples.md
  references/scenarios.md
update-agent-handoff/
  SKILL.md
  agents/openai.yaml
  references/handoff-example.md
references/
  evals/
    regression-cases.md
```

## Notes For Maintainers

- Keep `project-agent-docs` as a router and conflict resolver, not a duplicate schema.
- Keep `project-map-agent-md` focused on stable repo mapping, not planning or session state.
- Keep `update-agent-handoff` focused on compact state sync and significance assessment, not multi-step planning.
- Prefer structured decision rules over broad prose.
- Do not default to full-repo rescans when a minimal patch decision is enough.
