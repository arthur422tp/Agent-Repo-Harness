# Project Agent Docs Skills

Chinese version: [README.md](README.md)

This repo contains three repo-guidance skills:

- `project-agent-docs`: the ONLY router
- `project-map-agent-md`: canonical map builder
- `update-agent-handoff`: handoff updater and minimal patch engine

## Model

- `agent.md` is the map
- planning docs are navigation
- handoff is the current position

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
  evals/
    regression-cases.md
```

## References

- Routing, precedence, and patch-vs-rebuild rules live in [project-agent-docs/SKILL.md](project-agent-docs/SKILL.md).
- Map-building rules live in [project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md).
- Handoff and patch rules live in [update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md).
- Good examples live in [project-map-agent-md/references/examples.md](project-map-agent-md/references/examples.md) and [update-agent-handoff/references/handoff-example.md](update-agent-handoff/references/handoff-example.md).
- Bad-output examples live in [project-map-agent-md/references/bad-output-examples.md](project-map-agent-md/references/bad-output-examples.md) and [update-agent-handoff/references/bad-output-examples.md](update-agent-handoff/references/bad-output-examples.md).
- Release-check cases live in [references/evals/regression-cases.md](references/evals/regression-cases.md).

## Install

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

## Maintenance

- Keep routing logic in `project-agent-docs` ONLY.
- Keep examples in `references/`, not in `SKILL.md`.
- Keep `SKILL.md` files concise and execution-focused.
- Treat regression cases and bad-output examples as release gates.
