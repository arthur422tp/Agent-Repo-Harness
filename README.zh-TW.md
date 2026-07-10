# Agent-Repo-Harness

[English](README.md)

[![CI](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur422tp/Agent-Repo-Harness/actions/workflows/ci.yml)

**Agent-Repo-Harness 是給 AI coding agent 使用的 repo-local completion gate。**

它在 agent 宣稱完成前，明確要求 task scope、policy、repository-owned
verification 與持久 finish evidence。它不是 sandbox、完整的 agent runtime，
也不保證語意正確性。

目前版本：`0.2.0`。版本變更請見 [CHANGELOG.md](CHANGELOG.md)、
[versioning](docs/versioning.md) 與 [stability contract](docs/stability-contract.md)。

## 快速開始

先預覽 installer，再安裝到目標 repository；要求 agent 修改產品檔案前，先
提交乾淨的 baseline：

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
cd /path/to/target-repo
git add AGENTS.md CLAUDE.md agent.md handoff.md .agent docs/agent scripts schemas
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

Platform Support：主要支援 Linux、macOS、WSL 與 Git Bash。Agent-Repo-Harness 以 Unix-like
shell environments 為目標，目前不把原生 PowerShell 支援列為目標。

## 設定 Repository

安裝後填寫 repository 自己擁有的 context 與控制規則：

- `agent.md`：穩定的 repository facts 與操作規則。
- `.agent/harness.yml`：具權威性的 verification 命令。
- `.agent/policy.yml`：受保護路徑與核准規則。
- `handoff.md`：給人與下一位 agent 的目前狀態摘要。

repo-defined commands 是具權威性的驗證來源；沒有設定時才保留 heuristic fallback。

```yaml
# .agent/harness.yml
verification:
  required:
    - name: unit-tests
      command: uv run pytest
    - name: lint
      command: uv run ruff check .
```

若任務只需要驗證目前階段已存在的 artifact，可使用 verification profile：

```yaml
verification:
  profiles:
    bootstrap:
      required:
        - name: package-import
          command: uv run python -c "import package_name"
```

```yaml
# .agent/task.yml
task:
  verification_profile: bootstrap
```

`task.verification_profile` 會取代 `verification.required`，不會與預設命令
合併。只有在 tests、CLI、build 與 lint targets 都存在後，才使用 final 或
release profile。

## 執行第一個任務

先讀取安裝後的 entrypoint 與持久 context：`AGENTS.md` 或 `CLAUDE.md`、
`agent.md`、`handoff.md`、`.agent/task.yml`，以及適用的
`.agent/policy.yml` entries。接著依序執行：

1. 用 `scripts/agent-task-profile.sh` 產生有範圍限制的 task state。
2. 執行 `scripts/agent-preflight.sh`。
3. 只在 task boundaries 內修改。
4. 執行 canonical `scripts/agent-finish.sh` gate。
5. 檢查 `.agent/runs/<timestamp>/finish-summary.json` 與相關結果檔案。
6. 若啟用 strict acceptance，使用 `scripts/agent-evidence-bind.sh` 綁定 run
   artifacts，再重新執行 acceptance 與 finish checks。
7. 更新 `handoff.md` 的變更檔案、驗證結果、阻擋事項與下一步後，才能宣稱完成。

典型的 helper-first 命令流程：

```bash
bash scripts/agent-task-profile.sh standard \
  --goal "Implement the current task" \
  --current-task "Complete the scoped change" \
  --allowed "src/**" \
  --allowed "tests/**" \
  --verification-profile feature
bash scripts/agent-preflight.sh
bash scripts/agent-finish.sh
```

finish gate 會檢查 scope 與 policy、套用啟用的 evidence gates、執行
verification，並產生持久 evidence。`finish-summary.json` 是給工具使用的
machine-readable summary；Markdown 與 text 檔案適合人工除錯。

### Evidence Vs Handoff

`.agent/runs/<timestamp>/` 是特定 finish run 的權威 evidence。`handoff.md`
是給人與未來 agent 使用的 continuity artifact；`.agent/handoff.yml` 是可選的
結構化鏡像。task 可以設定 `completion.expects_handoff_update: true` 表達流程
期待，但 `agent-finish.sh` 不會強制 handoff freshness。

## Finish 失敗時

finish run 失敗後不要宣稱完成。讀取失敗結果並依照
[Repair Failed Finish Runs](docs/agent/repair-failed-run.md) 處理：

1. 找出失敗的 gate，檢查它的 evidence file。
2. 修復造成失敗的 task、設定或 evidence。
3. 重新執行 `scripts/agent-finish.sh`，檢查最新 run directory。
4. 只有在引用的 run 通過後，才綁定 strict acceptance evidence。
5. 在 `handoff.md` 記錄修復結果與仍存在的阻擋事項。

Evidence references 能改善追溯性，但不會超越設定檢查而保證語意正確性。
完整差異請見 [Handoff And Evidence](docs/handoff.md)。

## 選擇導入路徑

Agent-Repo-Harness 同時支援從頭開始的新專案，以及已經開發中的 repository。
請依 baseline 狀態選擇路徑。

### 從頭開發的新專案

1. 建立 repository 後立即安裝 harness。
2. 在 `agent.md` 填入預期的 repository shape 與 coding rules。
3. 在 `.agent/harness.yml` 設定第一組真實 verification 命令。
4. 在 `.agent/policy.yml` 設定受保護路徑。
5. 將 harness files 與初始 project scaffold 一起提交。
6. 每個變更產生 Minimal、Standard 或選擇性的 High-Risk task profile，再透過
   `scripts/agent-finish.sh` 完成。

### 既有或開發中的專案

1. 先用 `--dry-run`，檢查既有 entrypoints、scripts、docs 與 `.agent/` 的衝突。
2. 檢查衝突後才使用 `--backup` 或 `--force`。
3. 根據具體 repository facts 填寫 `agent.md`，讓 `handoff.md` 聚焦目前狀態。
4. 設定專案真正的 test、lint、build 或 type-check 命令。
5. 將 harness scaffold 提交為乾淨 baseline，再開始功能工作。

若分支已有未完成的產品變更，盡可能使用獨立 branch 或 worktree。否則先
commit 或 stash 無關工作，讓 `check-scope.sh` 能區分 scaffold 與功能變更。

## 選擇 Verification 與 Gates

Task profiles 是寫入 `.agent/task.yml` 的建議；harness 會執行產生出的 flags，
不是在 finish 時讀取 profile 名稱。

- **Minimal**：小型、低風險維護所需的 scope、policy、verification 與 handoff。
- **Standard**：行為變更加入 TDD，以及任務需要的 acceptance 或 review evidence。
- **High-Risk**：只加入能回答具名風險的 architecture、command ledger、sandbox、
  subagent、failure-attribution 或 intervention evidence。

請見 [Gate Guide](docs/agent/gate-guide.md) 的 decision matrix、profile 範例、
evidence 要求與失敗含義。Optional evidence gates 預設停用；只有在能回答具體
completion risk 時才啟用。

## 架構與邊界

Harness 將穩定的 repository facts 與目前 task state 分離：

- `agent.md`：repository facts 與操作規則。
- `.agent/task.yml`：目前 task scope 與啟用的 gates。
- `.agent/policy.yml`：policy 與 protected paths。
- `.agent/runs/<timestamp>/`：finish orchestration 產生的每次執行 evidence。
- `handoff.md`：給下一位人或 agent 的 continuity notes。

finish gate 是流程邊界。Scope 與 policy 是 process guardrails，不是 security
boundaries。Harness 不會隔離 filesystem、network、secrets、provider tokens 或
model cost。請見 [Runtime Boundaries](docs/runtime-boundaries.md) 的 Implemented
與 Not Implemented 說明。

Resource Envelope 可以限制 finish duration 與 changed-file count，但不會量測
provider tokens 或 hosted model cost。Command ledger、sandbox verification、
architecture sensors、episode、failure-attribution 與 intervention evidence 都是
選用的 local contracts，不是 provider-native runtime tracing。

## 範例與參考資料

依任務類型選擇範例：

- [Docs-only change](examples/docs-only-change/README.md)
- [Bugfix with strict evidence refs](examples/bugfix-with-evidence-refs/README.md)
- [High-risk policy change](examples/high-risk-policy-change/README.md)
- [RAG contract adoption fixture](examples/rag-contract-system/README.md)

進階文件：

- [Usage With Agents](docs/USAGE_WITH_AGENTS.md)
- [Gate Guide](docs/agent/gate-guide.md)
- [Architecture Sensors](docs/agent/architecture-sensors.md)
- [Codex usage](docs/codex-usage.md)
- [Agent support matrix](docs/agent-support-matrix.md)
- [Public packaging](docs/public-packaging.md)

CI 使用的相同 repository validation 可在本機執行：

```bash
bash validate-harness.sh
```

Validation 會檢查 script syntax、config 與 task schema、install smoke tests、
document links、scope 與 policy、configured verification、evidence gates、finish
evidence、examples 與 stability contract。
