# Agent-Repo-Harness

[English](README.md) | [繁體中文](README.zh-TW.md)

[![CI](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml)

**Agent-Repo-Harness 是供 AI coding agent 使用、放置於 repository 內的完成閘門。**

它為 Codex、Claude Code 與通用 AI coding agent 提供一組由 repository
擁有的小型契約與指令稿，讓 agent 在宣稱工作完成前檢查成果。它能協助
AI coding agent 避免在尚未完成下列事項前便宣告完成：

- 保持在任務範圍內
- 通過政策檢查
- 執行驗證
- 留下可持續保存的執行證據與精簡 continuity note

`scripts/agent-finish.sh` 是標準完成閘門。它會檢查本地範圍與政策規則、
套用已啟用的證據閘門、執行驗證，並記錄該次執行的持久證據。根據結果
更新 `handoff.md` 是文件所定義的工作流程步驟，不是 finish gate 強制
執行的檢查。

## 版本管理

目前版本：`0.1.0`。

變更內容請見 [CHANGELOG.md](CHANGELOG.md)，版本管理與升級預期請見
[docs/versioning.md](docs/versioning.md)。

公開 repository metadata 與 `v0.1.0` 發行檢查清單請見
[docs/public-packaging.md](docs/public-packaging.md)。

## 三個步驟開始試用

1. 預覽並將 harness 安裝至目標 repository。
2. 進入該目標 repository。
3. 執行一次完成閘門，查看工作流程。

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
cd /path/to/target-repo
bash scripts/agent-finish.sh --best-effort
```

針對實際任務，請編輯 `.agent/task.yml`，再執行一次
`scripts/agent-finish.sh`。

## 它不是什麼

Agent-Repo-Harness 不是：

- 完整的 agent runtime
- MCP server
- sandbox
- 語意正確性的保證

它會將完成工作的預期明確化；除了 repository 設定的檢查之外，它不會
判定功能是否正確。作業邊界請見[防護措施，不是 Sandbox](#防護措施不是-sandbox)。

## 平台支援

Agent-Repo-Harness 以類 Unix shell 環境為目標。主要支援環境為 Linux、
macOS、WSL 與 Git Bash。目前不以支援原生 PowerShell 為目標。

## 驗證策略

`scripts/agent-verify.sh` 內含針對常見 Node、Go、Python 與 Docker
Compose repository 的便利啟發式檢查。實際專案應優先在
`.agent/harness.yml` 中定義由 repository 擁有的驗證命令，例如：

```yaml
verification:
  required:
    - name: "unit tests"
      command: "uv run pytest tests/unit"
    - name: "lint"
      command: "uv run ruff check ."
```

當專案特定工具與預設啟發式檢查不同時，以 repository 定義的驗證命令
為準。

## 選擇 Gate Profile

Profiles 是使用現有 `.agent/task.yml` flags 的建議組合；harness 不會讀取
profile 名稱或自動啟用 gates。

- **Minimal：** 適合低風險維護，使用 scope、policy、verification 與 handoff
  expectation。
- **Standard：** 在 Minimal 之上，對行為變更加上 TDD，並依任務需求啟用
  acceptance 或 review evidence。
- **High-Risk：** 在 Standard 之上，只啟用能回答具體風險的 architecture、
  command ledger、sandbox、subagent、failure attribution 或 intervention
  evidence。

完整決策矩陣、profile 範例與 evidence 要求請見
[Gate Guide](docs/agent/gate-guide.md)。

## 防護措施，不是 Sandbox

範圍與政策閘門是流程防護措施，不是安全邊界。它們會檢查 Git 變更與
repository 內的政策模式；它們不會隔離檔案系統、網路、secrets 或命令
的副作用，也不保證語意正確性。

## Resource Envelope

Agent-Repo-Harness 可以強制套用本地 finish-run 限制，例如最大 finish
duration 與最大 changed-file count：

```yaml
runtime:
  resource_limits:
    max_finish_seconds: 300
    max_changed_files: 20
```

值為 `0` 代表停用該項限制。這些限制是本地 shell run 控制，不會衡量
provider tokens 或 hosted model cost。

完整 runtime 邊界請看 [docs/runtime-boundaries.md](docs/runtime-boundaries.md)。

## 運作方式

Harness 會將穩定的 repository 事實與目前任務狀態分開保存：

- `agent.md`：穩定的 repository 導覽與操作規則
- `handoff.md`：目前任務狀態與下一個動作
- `.agent/handoff.yml`：選用、可由機器讀取的 handoff 狀態
- `.agent/task.yml`：可由機器讀取的目前任務範圍與已啟用閘門
- `.agent/policy.yml`：repository 內的政策檢查與受保護路徑
- `.agent/tdd-evidence.yml`：選用的結構化 TDD 證據
- `.agent/acceptance.yml`：選用的驗收條件證據
- `.agent/review.yml`：選用的 review 證據
- `.agent/episode.yml`：選用的 episode package metadata
- `.agent/failure-attribution.yml`：選用的 failure attribution 證據
- `.agent/interventions.yml`：選用的 intervention record
- `.agent/subagent-packet.yml`：選用的 controller-to-subagent 交接封包
- `.agent/subagent-runs/`：選用的委派執行持久證據

安裝後的入口點為 `AGENTS.md` 與 `CLAUDE.md`。Agent 會搭配上述持久
context 使用這些檔案，並透過 `scripts/agent-finish.sh` 完成工作。

## Evidence Vs Handoff

`.agent/runs/<timestamp>/` 是由 `scripts/agent-finish.sh` 產生的權威
完成證據。它會記錄特定 finish run 的命令、模式、閘門結果、驗證輸出、
變更檔案與 diff 摘要。

每次 finish run 也會寫入 `finish-summary.json`。這是給工具和 CI 使用的
machine-readable 摘要，包含 run directory、mode、overall result、gate
statuses、changed-file evidence、diff-stat evidence、elapsed seconds，以及
保留的 resource-envelope result。人類除錯仍以 Markdown summary 和各 gate 的
文字輸出為主。

`handoff.md` 是由 model 撰寫、供人類與未來 agent 延續工作的 continuity
artifact。它應摘要變更內容、應檢查哪份 run evidence、哪些項目已通過、
仍有哪些開放事項，以及下一個建議動作。`.agent/handoff.yml` 則是選用的
結構化 continuity mirror，供需要 machine-readable handoff 的工具使用。

`.agent/task.yml` 可設定 `completion.expects_handoff_update: true`，用來
記錄 workflow 預期 finish 後更新 handoff。這是 advisory；`agent-finish.sh`
不會強制檢查 handoff freshness。

## 設定細節

必要條件：

- Bash
- Python（建議使用 `python3`；亦接受 `python`）
- 在一般 repository 工作流程中，需要 Git 提供範圍、diff 與完成證據

安裝後，請填寫下列檔案中的 repository 特定內容：

- `agent.md`
- `handoff.md`
- `.agent/policy.yml`
- `.agent/task.yml`

Harness 設定檔使用小型 shared-reader YAML 子集合，說明位於
[docs/config-format.md](docs/config-format.md)。

開始功能開發前，請檢查安裝後的檔案，並提交一份乾淨的 harness baseline：

```bash
git add .
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

範圍閘門會將任務變更與 Git 狀態比較。已提交的 baseline 可避免剛安裝
的 scaffold 檔案被回報為功能任務變更。

建議使用結構化的高風險核准。安裝後的專案會在
`docs/agent/policy-approval.md` 記載其契約；若未取得明確的人工作業
指示，agent 不得記錄核准。

## 證據與選用閘門

`agent-finish.sh` 會將權威 evidence 寫入 `.agent/runs/<timestamp>/`，包含
`finish-summary.md`、`finish-summary.json`、各檢查結果檔案、變更檔案與
diff stat。

選用 evidence gates 預設停用；只有在能回答具體完成風險時才啟用。可用
類別包括 TDD、acceptance、review、architecture、failure attribution、
interventions、command ledger、sandbox verification 與 delegated subagent
runs。

詳細 flag 選擇與 evidence 要求請見 [Gate Guide](docs/agent/gate-guide.md)；
run evidence 與 continuity notes 的差異請見
[Handoff And Evidence](docs/handoff.md)，containment 與 tracing 限制請見
[Runtime Boundaries](docs/runtime-boundaries.md)。

## 常用命令

在診斷任務或整合 harness 時，可以個別執行檢查：

```bash
bash scripts/agent-preflight.sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/validate-handoff.sh
bash scripts/validate-subagent-packet.sh
bash scripts/check-doc-links.sh
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/check-tdd-evidence.sh
bash scripts/check-acceptance.sh
bash scripts/check-review-evidence.sh
bash scripts/check-architecture-evidence.sh
bash scripts/check-subagent-evidence.sh
bash scripts/agent-verify.sh --best-effort
bash scripts/agent-finish.sh --best-effort
```

## 典型工作流程

1. 在 AI coding agent 中開啟目標 repository。
2. 要求它讀取 `AGENTS.md` 或 `CLAUDE.md`。
3. 在 `.agent/task.yml` 中定義有範圍限制的工作。
4. 執行 `scripts/agent-preflight.sh`。
5. 在任務邊界內進行變更。
6. 執行 `scripts/agent-finish.sh`。
7. 在 `handoff.md` 中更新變更檔案、驗證結果、阻擋事項，以及建議的
   下一個動作。可選擇同步結構化狀態至 `.agent/handoff.yml`。

## Context 載入政策

Agent-Repo-Harness 是針對分階段載入 context 所設計。Agent 應先讀取
精簡且持久的 context：

1. `AGENTS.md` 或安裝後的 adapter 入口點
2. `agent.md`
3. `handoff.md`
4. `.agent/task.yml`
5. 適用的 `.agent/policy.yml` 條目

接著，agent 可依目前任務使用 `rg`、檔案清單與指定檔案範圍擴展
context。`scripts/collect-context.sh` 預設輸出精簡啟動 context；
`scripts/collect-context.sh --full` 則會納入選用的已知問題與發現，
供深入除錯使用。

## Agent 相容性

Codex：

- 將 `templates/AGENTS.md` 安裝或複製至目標 repository 根目錄
- 參閱 [docs/codex-usage.md](docs/codex-usage.md)
- 可重複使用的 prompt：`adapters/codex/codex-start-prompt.md`
- 可選用且不會自動安裝到目標 repository 的 lifecycle prompts：
  `adapters/codex/codex-repair-prompt.md`、
  `adapters/codex/codex-verify-prompt.md` 與
  `adapters/codex/codex-handoff-prompt.md`

Claude Code：

- 將 `templates/CLAUDE.md` 安裝或複製至目標 repository 根目錄
- 選用的 project skills 位於 `adapters/claude-code/.claude/skills/`

通用 AI coding agents：

- 讀取 `AGENTS.md`
- 檢查 `agent.md`、`handoff.md`、`.agent/task.yml` 以及適用的
  `.agent/policy.yml` 條目
- 直接執行 scripts

仍支援相容於 Superpowers 的 agent。`skills/` 中現有的 skills 可提供
planning、TDD、delegation、review 與 branch finishing 等工作流程規律；
此 harness 則提供 repository 內的契約、閘門與證據。請見
[docs/superpowers-integration.md](docs/superpowers-integration.md)。

詳細 agent 工作流程與支援邊界請見
[docs/USAGE_WITH_AGENTS.md](docs/USAGE_WITH_AGENTS.md) 與
[docs/agent-support-matrix.md](docs/agent-support-matrix.md)。

## Repository 內容

- `templates/`：複製至目標 repository 的檔案
- `templates/scripts/`：低相依性的閘門與驗證器
- `skills/`：相容於 Superpowers 的 skills
- `adapters/`：agent 特定的入口點與 skill layouts
- `schemas/`：harness、policy、task 與 handoff 結構的 JSON Schemas
- `examples/`：安裝後形態與任務流程範例
- `install-agent-harness.sh`：template installer
- `validate-harness.sh`：repository 驗證與 smoke tests

## 驗證

CI 會在每次 push 與 pull request 時執行驗證。在本機以相同方式執行
repository 驗證：

```bash
bash validate-harness.sh
```

驗證內容涵蓋 script syntax、YAML 與 JSON syntax、必要 harness 檔案、
安裝 smoke tests、本地文件連結、範圍與政策行為、設定的驗證命令、
subagent packet/run 驗證、TDD 證據行為、驗收/review gate 行為，以及
finish evidence 的建立。
