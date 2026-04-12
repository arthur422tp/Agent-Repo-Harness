# Project Agent Docs Skills 使用說明

English version: [README.en.md](README.en.md)

這個 repo 提供三個給 Codex / agent 使用的 skills，用來建立、路由、以及更新專案內的 guidance 文件。它不是需要 build 的套件，而是一組可複用的 workflow templates。

## 核心原則

- `agent.md` 是地圖
- planning docs 是導航
- handoff 是目前所在位置

三者不能混用。

## Included Skills

| Skill | 用途 |
| --- | --- |
| `project-agent-docs` | Router。當你不確定該建立 repo map、更新 handoff、還是改寫 planning doc 時，先用這個。 |
| `project-map-agent-md` | 根據 repo 內的具體證據初始化 canonical guidance，例如 `agent.md` 或 `AGENTS.md`。 |
| `update-agent-handoff` | 更新既有 canonical guidance 裡的極短 handoff 狀態，並判斷是否真的需要最小幅度 patch `agent.md`。 |

## 什麼時候用哪個

| 目標 | 建議 Skill |
| --- | --- |
| 不確定該走哪條 guidance workflow | `$project-agent-docs` |
| repo 已有 README、manifests、entry points、tests、infra、schema 等具體證據，想建立 canonical map | `$project-map-agent-md` |
| 只想同步下一個 session 需要的狀態 | `$update-agent-handoff` |
| 需要詳細 implementation plan、test plan、file-by-file task breakdown | 不要用這三個 repo-guidance skills，改用 planning skill，例如 `writing-plans` |
| repo 還只是想法或空資料夾，缺乏 concrete evidence | 先建立具體 repo evidence，再用 `$project-map-agent-md` |

## Canonical agent.md 內容

`project-map-agent-md` 會把 root guidance 固定成低 token、穩定、可長期維護的 schema：

- `Project Overview`
- `Fast-Start Map`
- `Repository Tree`
- `Module Index`
- `Pseudo-DSL`
- `Adjacency List`
- `Risk Map`
- `Tooling & Commands`
- `Known Gaps / TODO`

表達方式以樹狀、條列、pseudo-DSL、adjacency list 為主，不以長 prose 為主。

## Handoff 原則

`update-agent-handoff` 只維護極短狀態，不承擔 planning：

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

handoff 只回答：

- 現在在做什麼
- 做到哪裡
- 下一步最短指向是什麼
- 有沒有阻塞
- 詳細 plan 在哪裡

## 什麼情況才更新 agent.md

`update-agent-handoff` 不會每次都改 `agent.md`。只有當以下任一項發生時，才會最小幅度 patch canonical guidance：

1. repository tree 或 module boundaries 改變
2. entry points 或 startup path 改變
3. cross-module dependencies 或 data flow 改變
4. external contracts 改變，例如 API、schema、migrations、integrations
5. tooling commands 或 package-manager evidence 改變
6. risk map 或 skip zones 改變
7. 重要的 `TODO:` / `Inferred:` 事實被驗證，值得進入 canonical guidance

如果不符合：

- 不更新 `agent.md`
- 只更新 handoff，或完全不更新

## Change Impact Assessment

更新流程刻意保持低成本：

`changed files -> impacted modules -> architecture significance assessment -> yes: patch agent.md minimally -> no: update only handoff or do nothing`

這表示：

- 不做預設 full repo scan
- 不重寫整份 `agent.md`
- 優先最小必要更新
- 只掃 changed files、相鄰受影響模組、以及現有 canonical guidance

## Install

把三個 skill 目錄複製到你的 Codex skills 目錄。例如在 Windows PowerShell：

```powershell
$target = "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse -Force .\project-agent-docs $target
Copy-Item -Recurse -Force .\project-map-agent-md $target
Copy-Item -Recurse -Force .\update-agent-handoff $target
```

如果你使用不同的 Codex home 或 skills path，請把 `$target` 換成正確位置。若複製後目前 session 還看不到新 skill，通常重開一個 session 就足夠。

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

也可以直接自然語言描述：

```text
幫這個已經有 scaffold 的 repo 建立 agent.md，讓下一個 agent 可以快速 onboarding。
```

```text
幫我更新 handoff，只保留現在做到哪裡、下一步指向、blockers，詳細步驟放 planning doc。
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

`SKILL.md` 是主要規則；`agents/openai.yaml` 是 OpenAI / Codex 介面的顯示資訊與 default prompt；`references/` 只在需要時提供範例與情境片段，避免主 skill 膨脹。

## Notes For Maintainers

維持三個 skill 的邊界清楚：

- `project-agent-docs` 只負責 router，不重複 target skill 的完整 schema。
- `project-map-agent-md` 只負責 stable repo map，不寫 session state 或 planning。
- `update-agent-handoff` 只負責 compact state 與 impact assessment，不寫 detailed plan。
- 當內容開始需要多步驟執行、測試策略、或 file-level task breakdown 時，把細節移到 planning docs，guidance 只保留 link。
