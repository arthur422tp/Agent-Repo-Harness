# Project Agent Docs Skills

Chinese version: [README.md](README.md)

## What Problem This Repo Solves

This repo helps an agent keep three kinds of repo guidance separate and stable:

- `agent.md`: the stable repo map
- planning docs: future execution steps
- handoff: current position for the next session

Without this split, agents tend to rewrite maps too often, leak planning into handoff, or lose track of what changed.

## When To Use Each Skill

| Skill | Use it when | Do not use it for |
| --- | --- | --- |
| `project-agent-docs` | You need to decide the correct repo-guidance path | Building the map or updating handoff directly |
| `project-map-agent-md` | You need the first canonical map, or the current map is unusable | Session status, blockers, or detailed planning |
| `update-agent-handoff` | You need to sync current state or patch an existing map after meaningful changes | Initial repo mapping or multi-step planning |

## Six Real Scenarios

| Scenario | Use | Why |
| --- | --- | --- |
| New scaffolded repo with README, manifest, and entrypoint | `project-map-agent-md` | Canonical map does not exist yet |
| Existing `agent.md`, only current blockers and next-session state changed | `update-agent-handoff` | This is handoff-only work |
| Existing `agent.md`, shared schema or CI changed | `update-agent-handoff` | Needs architecture-sensitive patch review |
| Existing `agent.md`, but the file describes the wrong repo shape | `project-map-agent-md` | Patch is not trustworthy; rebuild |
| User asks for “what should we do next?” | planning workflow | This is navigation, not repo guidance |
| Mixed request: refresh repo guidance and give next steps | `project-agent-docs` first | Router chooses the path, then planning stays separate |

## Common Misuses

- Using handoff as a mini plan
- Rebuilding `agent.md` when a small patch is enough
- Mapping a repo from vague intention instead of concrete evidence
- Treating imports alone as verified runtime edges
- Letting examples or narratives leak into `SKILL.md`

## Minimal Install

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

## Minimal Success Case

1. Open a repo that already has `README.md`, a manifest, and an entrypoint.
2. Ask: `Use $project-agent-docs to choose the right canonical repo guidance workflow.`
3. If it routes to `project-map-agent-md`, create the first `agent.md`.
4. In a later session, ask `update-agent-handoff` to sync blockers and current focus without copying the plan.

## First Read

- Shared vocabulary and labels: [references/shared-spec.md](references/shared-spec.md)
- Router and precedence: [project-agent-docs/SKILL.md](project-agent-docs/SKILL.md)
- Map builder: [project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md)
- Handoff and patch engine: [update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md)

## References

- Good map examples: [project-map-agent-md/references/examples.md](project-map-agent-md/references/examples.md)
- Good handoff example: [update-agent-handoff/references/handoff-example.md](update-agent-handoff/references/handoff-example.md)
- Bad-output examples: [project-map-agent-md/references/bad-output-examples.md](project-map-agent-md/references/bad-output-examples.md), [update-agent-handoff/references/bad-output-examples.md](update-agent-handoff/references/bad-output-examples.md)
- Release checks: [references/evals/regression-cases.md](references/evals/regression-cases.md)

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
  references/bad-output-examples.md
update-agent-handoff/
  SKILL.md
  agents/openai.yaml
  references/handoff-example.md
  references/bad-output-examples.md
references/
  shared-spec.md
  evals/
    regression-cases.md
```
