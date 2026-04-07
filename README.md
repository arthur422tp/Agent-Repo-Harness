# Project Agent Docs Skills 使用指南

English version: [README.en.md](README.en.md)

這個 repo 收錄三個給 Codex / agent 使用的 skills，用來建立、路由與更新專案中的 agent guidance 文件。它不是一個需要 build 的套件，比較像一組可以複製到 Codex skills 目錄的工作流程模板。

## Included Skills

| Skill | 用途 |
| --- | --- |
| `project-agent-docs` | 路由入口。當你不確定該建立 repo map、更新 handoff，還是改寫 plan 時，先用這個 skill。 |
| `project-map-agent-md` | 初始化 canonical repo guidance map，例如 `agent.md` / `AGENTS.md`，讓之後的 agent 可以快速理解 repo。 |
| `update-agent-handoff` | 更新既有 canonical guidance 裡的短 handoff 狀態，例如 active task、下一步、blocker、verified command。 |

## When To Use Which

| 你想做的事 | 建議使用 |
| --- | --- |
| 不確定要用哪個 guidance workflow | `$project-agent-docs` |
| 第一次替一個 repo 建立 agent onboarding / repo map | `$project-map-agent-md` |
| 只想在現有 guidance 裡留下下一次 session 的短狀態 | `$update-agent-handoff` |
| 要寫詳細 implementation plan、測試計畫或檔案級步驟 | 不用這個 repo 的專用 skills，改用 planning 類 skill，例如 `writing-plans` |

## Install

把三個 skill 目錄複製到你的 Codex skills 目錄即可。以 Windows PowerShell 為例：

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

如果你使用的是不同的 Codex home 或 skills path，請把 `$target` 換成對應位置。複製後若目前的 Codex session 沒有看到新 skills，重新開一個 session 通常就可以載入。

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

也可以用比較自然的說法，例如：

```text
幫我幫這個 repo 建一份 agent.md，讓下一個 agent 能快速 onboarding。
```

```text
幫我更新 handoff，記錄這次改了什麼和下次要先看哪裡。
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

每個 `SKILL.md` 是 skill 的主要指令；`agents/openai.yaml` 提供在 OpenAI / Codex 介面中顯示用的名稱、簡介與預設 prompt。`references/` 裡放的是按需讀取的範例與場景提示，用來降低輸出漂移，但避免把主 skill 寫得太長。

## Notes For Maintainers

維護時建議保持這三個 skills 的界線清楚：

- `project-agent-docs` 只負責路由，不要塞入目標 skill 的完整 schema。
- `project-map-agent-md` 只做 repo map / onboarding，不維護 session state；詳細樣板放在 `project-map-agent-md/references/`。
- `update-agent-handoff` 只更新短狀態，不寫詳細 implementation plan；handoff 示例放在 `update-agent-handoff/references/`。
- 如果內容開始需要多步驟實作、測試策略或檔案級任務，應該連到 planning 文件或 planning skill，而不是把細節塞進 guidance map。
