# Project Agent Docs Skills

English version: [README.en.md](README.en.md)

## 這個 Repo 解決什麼問題

這個 repo 用來幫 agent 把三種 repo guidance 分開且維持穩定：

- `agent.md`：穩定的 repo 地圖
- planning docs：未來執行步驟
- handoff：下一個 session 要接手的目前位置

如果沒有這個分層，agent 很容易過度重寫地圖、把 planning 塞進 handoff，或搞不清楚這次到底改了什麼。

## 三個 Skill 何時用

| Skill | 什麼時候用 | 不要拿來做什麼 |
| --- | --- | --- |
| `project-agent-docs` | 你需要先決定 repo-guidance 應該走哪條路 | 直接建立 map 或直接更新 handoff |
| `project-map-agent-md` | 你要建立第一份 canonical map，或現有 map 已不可信 | session 狀態、blockers、詳細 planning |
| `update-agent-handoff` | 你要同步目前狀態，或在既有 map 上做最小 patch | 初始 repo mapping 或 multi-step planning |

## 六個真實情境對照

| 情境 | 用哪個 | 原因 |
| --- | --- | --- |
| 新 scaffold repo，已有 README、manifest、entrypoint | `project-map-agent-md` | 還沒有 canonical map |
| 已有 `agent.md`，但只想更新 blockers 與下一個 session 狀態 | `update-agent-handoff` | 這是 handoff-only 工作 |
| 已有 `agent.md`，但 shared schema 或 CI 剛改過 | `update-agent-handoff` | 需要 architecture-sensitive patch review |
| 已有 `agent.md`，但內容描述的是錯的 repo 形狀 | `project-map-agent-md` | patch 已不可信，應 rebuild |
| 使用者問「下一步該做什麼？」 | planning workflow | 這是導航，不是 repo guidance |
| 混合需求：整理 repo guidance 再告訴我下一步 | `project-agent-docs` 先 | 先由 router 決策，planning 保持分離 |

## 常見誤用

- 把 handoff 當成 mini plan
- 明明只要 patch，卻整份重建 `agent.md`
- repo 還只有想法，就硬做 canonical map
- 只憑 import 就把依賴邊標成 verified
- 把 examples 或長解釋塞回 `SKILL.md`

## 最小安裝

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

## 最小成功案例

1. 打開一個已經有 `README.md`、manifest、entrypoint 的 repo。
2. 問：`Use $project-agent-docs to choose the right canonical repo guidance workflow.`
3. 如果它路由到 `project-map-agent-md`，就建立第一份 `agent.md`。
4. 下一個 session 再用 `update-agent-handoff` 同步 blockers 與 current focus，但不要複製 planning 內容。

## 先看哪裡

- 共用術語與 labels：[references/shared-spec.md](references/shared-spec.md)
- router 與 precedence：[project-agent-docs/SKILL.md](project-agent-docs/SKILL.md)
- map builder：[project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md)
- handoff 與 patch engine：[update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md)

## References

- 好的 map examples：[project-map-agent-md/references/examples.md](project-map-agent-md/references/examples.md)
- 好的 handoff example：[update-agent-handoff/references/handoff-example.md](update-agent-handoff/references/handoff-example.md)
- bad-output examples：[project-map-agent-md/references/bad-output-examples.md](project-map-agent-md/references/bad-output-examples.md)、[update-agent-handoff/references/bad-output-examples.md](update-agent-handoff/references/bad-output-examples.md)
- release checks：[references/evals/regression-cases.md](references/evals/regression-cases.md)

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
