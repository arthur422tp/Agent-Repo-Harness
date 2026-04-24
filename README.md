# Agent-Repo-Harness

English version: [README.en.md](README.en.md)

## 這個 Repo 的目標

這個 repo 正在把 `Agent-Repo-Guide` 演進成 `Agent-Repo-Harness`。

核心原則不變：

- **不要取代 Superpowers**
- **Superpowers 繼續負責開發流程**
- **Agent-Repo-Harness 負責 repo-aware control layer**

分工如下：

```text
Superpowers
  = brainstorming / writing-plans / subagent-driven-development
  = test-driven-development / code review / finishing branch

Agent-Repo-Harness
  = agent.md / handoff.md / policy gates / verification gates
  = subagent context packets / discoveries memory / domain risk review
```

## Quick Start

1. 先把 harness 安裝到目標 repo：

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
```

2. 在目標 repo 執行：

```bash
bash scripts/agent-preflight.sh
bash scripts/check-agent-md.sh agent.md
bash scripts/agent-verify.sh
```

3. 在非 trivial 的 repo 任務前先用 `harness-entrypoint`。
4. 設計、計畫、TDD、執行、review 仍由 Superpowers 處理。

## 現在提供什麼

- `templates/`
  - `agent.md` 與 `handoff.md` 樣板
  - `docs/agent/` 長期與短期記憶樣板
  - `scripts/` 安全預設的 preflight / verify / policy / context scripts
  - `.agent/` harness 與 policy 設定
- `skills/`
  - `harness-entrypoint`
  - `repo-context-bootstrap`
  - `repo-map-maintenance`
  - `handoff-update`
  - `subagent-context-packet`
  - `policy-gate`
  - `verification-gate`
  - `discoveries-memory`
  - `domain-risk-review`
- `install-agent-harness.sh`
  - 將 `templates/` 複製到目標 repo
- `examples/`
  - RAG contract system

## 與既有 Agent-Repo-Guide 的關係

這次 migration 採用 additive 方式，先保留原本 skill：

- `project-agent-docs`
- `project-map-agent-md`
- `update-agent-handoff`

對應關係：

| 舊概念 | 新 harness 模組 |
| --- | --- |
| `project-agent-docs` | `harness-entrypoint` + `repo-context-bootstrap` |
| `project-map-agent-md` | `repo-map-maintenance` |
| `update-agent-handoff` | `handoff-update` |

在新 skill 完整取代前，不會強制刪除舊內容。

## 安裝方式

把樣板安裝到目標 repo：

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
```

如果目標 repo 已經有同名檔案，installer 預設會跳過，不會覆蓋。要覆蓋必須顯式加 `--force`。
如果你要保留被覆蓋檔案，可搭配 `--backup` 產生 `.bak`。

## 典型使用流程

1. 在目標 repo 安裝 harness 樣板。
2. 用 `harness-entrypoint` 或 `repo-context-bootstrap` 讀取 repo context。
3. 用 Superpowers 做設計、計畫、TDD、實作、review。
4. dispatch subagent 前用 `subagent-context-packet` 準備 repo-aware context。
5. 完成前跑：

```bash
scripts/check-policy.sh
scripts/agent-verify.sh
```

6. 更新 `handoff.md` 與 `docs/agent/discoveries.md`。

## File Responsibilities

- `agent.md`：穩定的 repo map 與 repo-specific 規則
- `handoff.md`：只記錄目前 task state
- `docs/agent/known-issues.md`：長期 gotchas 與重複踩雷點
- `docs/agent/discoveries.md`：短期 discoveries，供後續 subagent 重用
- `.agent/harness.yml`：harness 行為與 workflow 要求
- `.agent/policy.yml`：高風險 pattern 與完成前 gate
- `scripts/`：preflight、policy、context、verification helpers

## Example Prompts

- `Use $harness-entrypoint before implementing this feature in the current repo.`
- `Use $repo-context-bootstrap to initialize Agent-Repo-Harness files for this project.`
- `Use $subagent-context-packet before dispatching a coding subagent for the auth fix.`
- `Use $handoff-update after this session and keep the result concise.`
- `Use $domain-risk-review on this retrieval pipeline change.`

## Design Principles

- Superpowers 繼續負責開發流程
- Agent-Repo-Harness 只增加 project-aware control，不建立新 runtime
- stable repo map 與 current task state 必須分離
- policy 與 verification 在 completion 前必須明確檢查
- discoveries 應被記錄並跨 session 重用

## FAQ

**這會取代 Superpowers 嗎？**
不會。它是包在 Superpowers 外層的 repo-aware control layer。

**這個 repo 有提供 runtime 或 MCP server 嗎？**
沒有。這裡只提供 templates、scripts、skills、examples。

**預設 scripts 應該原封不動直接用嗎？**
不應該。它們是安全預設，安裝到目標 repo 後應再客製。

**`agent.md` 應該放目前 implementation plan 嗎？**
不應該。plan 應留在 planning docs，不應放進 stable repo map。

## 驗證與限制

目前這個 repo 只驗證：

- shell scripts 語法正確
- 安裝腳本語法正確
- 模板檔案存在且 `check-agent-md.sh` 能檢查 `templates/agent.md`
- `validate-harness.sh` 可重跑安裝與 installed-target smoke checks

尚未做的事：

- 沒有建立完整 agent runtime
- 沒有建立 MCP server
- `agent-verify.sh` 會依 repo 類型做 best-effort checks，但目標 repo 仍應自行客製
- `check-policy.sh` 使用的是輕量 pattern matching，不是完整 policy engine

## 參考與既有資產

- 共享 label 與 guidance 邊界：[references/shared-spec.md](references/shared-spec.md)
- migration 對照：[references/harness-migration.md](references/harness-migration.md)
- regression cases：[references/evals/regression-cases.md](references/evals/regression-cases.md)
- 舊 router skill：[project-agent-docs/SKILL.md](project-agent-docs/SKILL.md)
- 舊 map maintenance skill：[project-map-agent-md/SKILL.md](project-map-agent-md/SKILL.md)
- 舊 handoff update skill：[update-agent-handoff/SKILL.md](update-agent-handoff/SKILL.md)
