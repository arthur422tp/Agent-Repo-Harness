# Project Agent Docs Skills Usage Guide

Chinese version: [README.md](README.md)

This repo contains three skills for Codex / agent workflows. They are designed to create, route, and update project guidance documents without mixing stable repo knowledge, planning, and current-session state.

## Core Principle

- `agent.md` is the map
- planning docs are navigation
- handoff is the current position

Do not mix them.

## Included Skills

| Skill | Purpose |
| --- | --- |
| `project-agent-docs` | Router. Use this when you are not sure whether to create a repo map, update a handoff, or send the work to planning. |
| `project-map-agent-md` | Initializes canonical repo guidance such as `agent.md` or `AGENTS.md` from concrete repository evidence. |
| `update-agent-handoff` | Updates minimal handoff state in existing canonical guidance and decides whether a small `agent.md` patch is actually needed. |

## When To Use Which

| Goal | Recommended Skill |
| --- | --- |
| You are not sure which repo-guidance workflow to use | `$project-agent-docs` |
| The repo already has concrete evidence such as README, manifests, entry points, tests, infra, or schemas, and you want a canonical map | `$project-map-agent-md` |
| You only want to sync concise next-session state | `$update-agent-handoff` |
| You need a detailed implementation plan, test plan, or file-by-file task breakdown | Do not use these three repo-guidance skills; use a planning skill such as `writing-plans` |
| The repo is still just an idea or a bare folder with little concrete evidence | Create concrete repo evidence first, then use `$project-map-agent-md` |

## Canonical agent.md Shape

`project-map-agent-md` keeps the root guidance stable, compact, and low-token:

- `Project Overview`
- `Fast-Start Map`
- `Repository Tree`
- `Module Index`
- `Pseudo-DSL`
- `Adjacency List`
- `Risk Map`
- `Tooling & Commands`
- `Known Gaps / TODO`

The preferred representation is tree structure, bullets, pseudo-DSL, and adjacency lists rather than long prose.

## Handoff Shape

`update-agent-handoff` keeps handoff intentionally thin:

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

The handoff should answer only:

- what is being worked on now
- how far it got
- the shortest next pointer
- whether anything is blocked
- where the detailed plan lives

## When agent.md Should Change

`update-agent-handoff` should not update `agent.md` after every code change. It should patch canonical guidance only when one of these changed:

1. repository tree or module boundaries
2. entry points or startup path
3. cross-module dependencies or data flow
4. external contracts such as APIs, schemas, migrations, or integrations
5. tooling commands or package-manager evidence
6. risk map or skip zones
7. an important `TODO:` or `Inferred:` fact that is now verified and belongs in canonical guidance

If none of those changed:

- do not update `agent.md`
- update only handoff, or do nothing

## Change Impact Assessment

The update flow is intentionally narrow:

`changed files -> impacted modules -> architecture significance assessment -> yes: patch agent.md minimally -> no: update only handoff or do nothing`

This means:

- no default full-repo scan
- no full rewrite of `agent.md`
- minimal necessary updates first
- inspect changed files, adjacent impacted modules, and existing canonical guidance only

## Install

Copy the three skill directories into your Codex skills directory. For example, on Windows PowerShell:

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

If you use a different Codex home or skills path, replace `$target` with the correct location. If your current Codex session does not see the new skills after copying them, starting a new session is usually enough.

## Example Prompts

```text
Use $project-agent-docs to choose the right canonical repo guidance workflow.
```

```text
Use $project-map-agent-md to create a compact canonical repo guidance map from this repo's concrete files and docs.
```

```text
Use $update-agent-handoff to update compact session state in the existing canonical repo guidance.
```

You can also phrase the request naturally:

```text
Create an agent.md for this scaffolded repo so the next agent can onboard quickly.
```

```text
Update the handoff so it only keeps the current status, the shortest next pointer, blockers, and a link to the planning doc.
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
```

Each `SKILL.md` contains the main rules. Each `agents/openai.yaml` provides UI metadata and the default prompt. Files in `references/` are loaded only when needed, so the main skills stay short and stable.

## Notes For Maintainers

Keep the boundaries between these three skills clear:

- `project-agent-docs` should only route requests and should not duplicate full schemas.
- `project-map-agent-md` should only maintain the stable repo map and should not store session state or planning detail.
- `update-agent-handoff` should only maintain compact state and impact assessment, not detailed plans.
- If the content starts needing ordered execution steps, testing strategy, or file-level tasks, move that detail into planning docs and keep only a pointer in guidance.
