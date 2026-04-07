# Project Agent Docs Skills Usage Guide

This repo contains three skills for Codex / agent workflows. They help create, route, and update agent guidance documents inside a project. This is not a package that needs to be built; it is closer to a small set of workflow templates that you can copy into your Codex skills directory.

Chinese version: [README.md](README.md)

## Included Skills

| Skill | Purpose |
| --- | --- |
| `project-agent-docs` | Routing entry point. Use this when you are not sure whether to create a repo map, update a handoff, or write a plan. |
| `project-map-agent-md` | Initializes a canonical repo guidance map, such as `agent.md` or `AGENTS.md`, so future agents can onboard quickly. |
| `update-agent-handoff` | Updates short handoff state in existing canonical guidance, such as the active task, next step, blocker, or verified command. |

## When To Use Which

| Goal | Recommended Skill |
| --- | --- |
| You are not sure which guidance workflow to use | `$project-agent-docs` |
| You want to create an agent onboarding / repo map for a repo for the first time | `$project-map-agent-md` |
| You only want to leave short state for the next session in existing guidance | `$update-agent-handoff` |
| You need a detailed implementation plan, test plan, or file-by-file task breakdown | Do not use these repo-specific skills; use a planning skill such as `writing-plans` instead |

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
Use $project-map-agent-md to create a compact canonical repo guidance map for this repo.
```

```text
Use $update-agent-handoff to update compact session state in the existing canonical repo guidance.
```

You can also phrase the request naturally:

```text
Create an agent.md for this repo so the next agent can onboard quickly.
```

```text
Update the handoff with what changed this session and what the next session should read first.
```

## Repository Layout

```text
project-agent-docs/
  SKILL.md
  agents/openai.yaml
project-map-agent-md/
  SKILL.md
  agents/openai.yaml
update-agent-handoff/
  SKILL.md
  agents/openai.yaml
```

Each `SKILL.md` contains the main skill instructions. Each `agents/openai.yaml` provides display metadata for OpenAI / Codex interfaces, including the display name, short description, and default prompt.

## Notes For Maintainers

Keep the boundaries between these three skills clear:

- `project-agent-docs` should only route requests; do not copy the full schema from the target skills into it.
- `project-map-agent-md` should only create repo maps / onboarding guidance; it should not maintain session state.
- `update-agent-handoff` should only update short state; it should not write detailed implementation plans.
- If the content starts needing multi-step implementation, a testing strategy, or file-level tasks, link to a planning document or planning skill instead of putting those details into the guidance map.
