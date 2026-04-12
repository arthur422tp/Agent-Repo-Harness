# Project Agent Docs Skills

English version: [README.en.md](README.en.md)

這個 repo 提供三個 repo-guidance skills：

- `project-agent-docs`：唯一 router
- `project-map-agent-md`：canonical map builder
- `update-agent-handoff`：handoff updater 與最小 patch engine

## 三層模型

- `agent.md` 是地圖
- planning docs 是導航
- handoff 是目前所在位置

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

- 路由、precedence、patch-vs-rebuild 規則在 [project-agent-docs/SKILL.md](project-agent-docs/SKILL.md)
- map-building 規則在 [project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md)
- handoff 與 patch 規則在 [update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md)
- good examples 在 [project-map-agent-md/references/examples.md](project-map-agent-md/references/examples.md) 與 [update-agent-handoff/references/handoff-example.md](update-agent-handoff/references/handoff-example.md)
- bad-output examples 在 [project-map-agent-md/references/bad-output-examples.md](project-map-agent-md/references/bad-output-examples.md) 與 [update-agent-handoff/references/bad-output-examples.md](update-agent-handoff/references/bad-output-examples.md)
- release-check cases 在 [references/evals/regression-cases.md](references/evals/regression-cases.md)

## Install

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

## Maintenance

- 路由邏輯只能放在 `project-agent-docs`
- examples 只能放在 `references/`，不要放進 `SKILL.md`
- `SKILL.md` 必須保持精簡且 execution-focused
- regression cases 與 bad-output examples 視為 release gates
