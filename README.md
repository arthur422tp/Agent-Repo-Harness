# Project Agent Docs Skills 使用說明

English version: [README.en.md](README.en.md)

這個 repo 提供三個給 Codex / agent 使用的 skills。核心設計維持三層，且不混用：

- `agent.md` 是地圖
- planning docs 是導航
- handoff 是目前所在位置

重點不是讓文件看起來完整，而是讓下一個模型更穩定地理解 repo、知道現在在哪，並且不要做多餘更新。

## Included Skills

| Skill | 用途 |
| --- | --- |
| `project-agent-docs` | Router / dispatcher，負責把請求導到最窄且最穩定的 repo-guidance workflow。 |
| `project-map-agent-md` | 依 concrete repository evidence 建立或重建 canonical repo guidance。 |
| `update-agent-handoff` | 維護精簡 handoff，並判斷現有 canonical map 是否只需要最小 patch。 |

## 何時用哪個 Skill

| 目標 | 建議 Skill |
| --- | --- |
| 不確定該走哪個 repo-guidance workflow | `$project-agent-docs` |
| 第一次從 concrete repo evidence 建立 canonical map | `$project-map-agent-md` |
| repo 已有 canonical guidance，但可能過時，需要刷新 | `$update-agent-handoff` |
| 只想同步目前 focus / blockers / resume context | `$update-agent-handoff` |
| 需要 detailed implementation plan、test plan、file-by-file breakdown | 不用這三個 repo-guidance skills，改走 planning workflow，例如 `writing-plans` |
| repo 仍只是 idea 或 bare folder | 先補 concrete repo evidence，不要硬建完整 canonical map |

## Router 決策原則

- 預設優先 patch 既有 canonical guidance，不預設 rebuild。
- 只有在 canonical guidance 缺失、失真、壞掉，或已不值得 patch 時，才重建。
- 若請求混合「整理 repo guidance」與「給我下一步」，先處理 guidance，再只留下短 pointer 或 plan link。
- planning docs 仍是未來步驟的來源。
- handoff 只記錄 current focus、progress delta、blockers 與 related-plan pointer。
- 即使 changed files 很少，只要命中高影響檔案，仍要做 deeper significance review。

高影響檔案包括：

- workspace config
- package manifests / lockfiles
- CI / deploy config
- Docker / compose / infra config
- env example / env schema
- migrations / schema / OpenAPI / GraphQL / protobuf / generated client
- shared packages / common contracts / bootstrap files / router registration
- auth / billing / permissions / secrets / external integrations

These files may imply architecture, runtime, contract, or command changes even when the local directory diff looks small.

## Canonical `agent.md` 形狀

`project-map-agent-md` 應維持根文件精簡、可導航、且有證據：

- `Project Overview`
- `Fast-Start Map`
- `Repository Tree`
- `Module Index`
- `Pseudo-DSL`
- `Adjacency List`
- `Risk Map`
- `Tooling & Commands`
- `Known Gaps / TODO`

限制如下：

- `Fast-Start Map` 必須列出真正有導航價值的 read-first paths。
- `Module Index` 在 evidence 足夠時，優先包含 `role`、`path`、`owns`、`depends_on`、`used_by`、`risk`。
- `Pseudo-DSL` 與 `Adjacency List` 應表達 runtime / ownership / contract edges，而不是把目錄樹重寫一次。
- 若 evidence 不足，寧可輸出更小但高訊號的 map。
- Do not optimize for section completeness at the cost of navigational usefulness.

## Handoff 形狀

`update-agent-handoff` 只維護瘦身、狀態導向的 handoff：

- `Last updated`
- `Current focus`
- `Progress`
- `Next pointer`
- `Blockers`
- `Related plan`

規則：

- `Next pointer` 必須是一句短 pointer，不可變成 multi-step plan。
- `Progress` 只記錄相對於 related plan 或前一個 session 最重要的 delta。
- 不保留 history logs、長篇說明或 execution narratives。
- 若詳細下一步已存在，應 link 到 planning doc，不要複製進 handoff。

## 何時該更新 `agent.md`

`update-agent-handoff` 只應在 architecture-significant facts 改變時 patch canonical guidance，例如：

1. repository tree 或 module boundaries 改變
2. entry points 或 startup path 改變
3. cross-module dependencies 或 data flow 改變
4. external contracts，例如 API、schema、migration、integration 改變
5. 有 executable repo evidence 支撐的 tooling commands 改變
6. risk map 或 skip zones 改變
7. 重要的 `TODO:` / `Inferred:` 現在被驗證了

校準規則：

- code-level dependency change 不等於 architecture-level dependency change
- internal refactor 不等於 module ownership change
- new file 不等於 new module
- 新增測試通常不需要更新 `agent.md`，除非它揭露新的 entry point、runtime boundary、external contract 或 previously unknown structure
- docs 提到 command，不等於 verified command
- import 關係不自動等於 runtime dependency
- shared type / DTO / schema / contract 變動要提升審查層級
- 若只是函式內部實作、局部 helper、命名、測試覆蓋、文案變更，通常不更新 `agent.md`

## Evidence Labels

把 labels 當成方法，不是外觀：

- `Verified command`: 出現在 package scripts、Makefile、task-runner config、CI invocation，或已直接執行並確認
- `Inferred command`: 只有 docs 提到，或只是依 framework / tooling 慣例猜測
- `Verified dependency edge`: 有 router wiring、bootstrap registration、DI config、manifest / workspace linkage、schema ownership、external contract reference、runtime config 等證據
- `Inferred dependency edge`: 只有 import、命名或目錄慣例支撐
- `TODO`: 仍未知但值得確認

不要在證據不足時把 `Inferred:` 或 `TODO:` 升級成 `Verified:`。

## 評估與回歸案例

回歸樣本放在 [references/evals/regression-cases.md](references/evals/regression-cases.md)，涵蓋：

- 小型單體 repo
- frontend/backend split repo
- monorepo
- infra-heavy repo
- 已有過時 `agent.md` 的 repo
- 只有 planning doc、沒有 canonical map 的 repo
- changed files 很少但實際改到 shared contract 的 repo

每個案例至少記錄：

- input context
- expected route
- whether `agent.md` should update
- whether handoff should update
- common failure mode to avoid

## Install

以 Windows PowerShell 為例，把三個 skill 目錄複製到 Codex skills 目錄：

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

- `project-agent-docs` 應維持 router / conflict resolver 角色，不複製完整 schema。
- `project-map-agent-md` 應維持 stable repo mapping，不承擔 planning 或 session state。
- `update-agent-handoff` 應維持 compact state sync 與 significance assessment，不承擔 multi-step planning。
- 優先寫結構化 decision rules，不要把 prompt 拉長成更模糊的 prose。
- 不要預設 full-repo rescan；先做最小、可驗證的 patch 判斷。
