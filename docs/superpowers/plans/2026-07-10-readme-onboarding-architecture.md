# README Onboarding And Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the long public README pair with a bilingual, onboarding-first entrypoint that takes a first-time adopter from installation through a trustworthy first finish run and routes advanced material to focused references.

**Architecture:** Keep the README pair as the public onboarding facade and preserve `docs/USAGE_WITH_AGENTS.md`, `docs/agent/gate-guide.md`, `docs/runtime-boundaries.md`, and `docs/stability-contract.md` as deeper layers. Encode the new information architecture in `tests/harness/doc-consistency.sh`, then rewrite both language variants together without changing runtime behavior.

**Tech Stack:** Markdown, Bash document assertions, repository-local link checker, Agent-Repo-Harness validation suite

## Global Constraints

- The primary reader is a first-time adopter.
- `README.md` and `README.zh-TW.md` must have matching structure, commands, links, and public claims.
- Greenfield and existing-project adoption remain parallel visible paths.
- Repository-owned verification commands remain authoritative; a selected `task.verification_profile` replaces the default required command set.
- `scripts/agent-finish.sh` remains the canonical completion boundary.
- Handoff freshness remains a workflow expectation, not an enforced finish gate.
- Do not claim sandboxing, runtime orchestration, provider tracing, token accounting, or semantic correctness guarantees.
- Do not modify runtime scripts, schemas, installed templates, CLI behavior, gate semantics, or generated `.agent/` state.
- Preserve the existing untracked `.agent/` directory and do not push without explicit publication approval.

## File Structure

- `tests/harness/doc-consistency.sh`: onboarding navigation, lifecycle, boundary, bilingual, and size contract.
- `README.md`: English onboarding entrypoint and reference router.
- `README.zh-TW.md`: Traditional Chinese onboarding entrypoint with matching semantics.
- `docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md`: execution status and observed evidence.

---

### Task 1: Define The Onboarding README Contract

**Files:**
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md`
- Test: `tests/harness/doc-consistency.sh`

**Interfaces:**
- Consumes: `assert_contains`, `fail`, and `pass` from `tests/harness/lib.sh`.
- Produces: the exact README headings, lifecycle references, and size ceiling implemented by Task 2.

- [x] **Step 1: Add the new bilingual section assertions**

Retain existing assertions that protect versioning, platform support, runtime boundaries, verification semantics, evidence/handoff semantics, and installed entrypoints. Add:

```bash
assert_contains "$repo_root/README.md" "## Quick Start"
assert_contains "$repo_root/README.md" "## Configure The Repository"
assert_contains "$repo_root/README.md" "## Run The First Task"
assert_contains "$repo_root/README.md" "## When Finish Fails"
assert_contains "$repo_root/README.md" "## Choose An Adoption Path"
assert_contains "$repo_root/README.md" "## Choose Verification And Gates"
assert_contains "$repo_root/README.md" "## Architecture And Boundaries"
assert_contains "$repo_root/README.md" "## Examples And References"
assert_contains "$repo_root/README.zh-TW.md" "## 快速開始"
assert_contains "$repo_root/README.zh-TW.md" "## 設定 Repository"
assert_contains "$repo_root/README.zh-TW.md" "## 執行第一個任務"
assert_contains "$repo_root/README.zh-TW.md" "## Finish 失敗時"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇導入路徑"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇 Verification 與 Gates"
assert_contains "$repo_root/README.zh-TW.md" "## 架構與邊界"
assert_contains "$repo_root/README.zh-TW.md" "## 範例與參考資料"
```

- [x] **Step 2: Assert canonical lifecycle and reference routing**

Add these exact assertions for both README files:

```bash
assert_contains "$repo_root/README.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/README.md" "scripts/agent-preflight.sh"
assert_contains "$repo_root/README.md" "scripts/agent-finish.sh"
assert_contains "$repo_root/README.md" "docs/agent/repair-failed-run.md"
assert_contains "$repo_root/README.md" "docs/USAGE_WITH_AGENTS.md"
assert_contains "$repo_root/README.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/README.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.md" "docs/stability-contract.md"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-preflight.sh"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-finish.sh"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/repair-failed-run.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/USAGE_WITH_AGENTS.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/stability-contract.md"
```

- [x] **Step 3: Add an entrypoint size ceiling**

```bash
readme_lines="$(wc -l < "$repo_root/README.md" | tr -d ' ')"
readme_zh_lines="$(wc -l < "$repo_root/README.zh-TW.md" | tr -d ' ')"
[ "$readme_lines" -le 320 ] || fail "README.md exceeds the 320-line onboarding entrypoint ceiling"
[ "$readme_zh_lines" -le 320 ] || fail "README.zh-TW.md exceeds the 320-line onboarding entrypoint ceiling"
pass "README onboarding entrypoints stay concise"
```

- [x] **Step 4: Run the red phase**

Run: `bash validate-harness.sh`

Expected: FAIL in document consistency because a new heading is absent or an existing README exceeds 320 lines. Record the first observed failure beneath this step.

Observed: `bash validate-harness.sh` exited 1 in `== Doc consistency ==` with `ERROR: expected output to contain: ## Quick Start` for `README.md`.

- [x] **Step 5: Commit the failing contract**

```bash
git add tests/harness/doc-consistency.sh docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md
git commit -m "test: define onboarding README contract"
```

Do not stage `.agent/`.

Observed commit: `f624c50` (`test: define onboarding README contract`).

---

### Task 2: Rewrite The Bilingual Onboarding Entry Point

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md`
- Test: `tests/harness/doc-consistency.sh`

**Interfaces:**
- Consumes: Task 1's contract; runtime facts from `docs/runtime-boundaries.md`; public interface classifications from `docs/stability-contract.md`; gate rules from `docs/agent/gate-guide.md`.
- Produces: matching English and Traditional Chinese onboarding entrypoints, each no longer than 320 lines.

- [x] **Step 1: Rewrite the English README in the approved sequence**

Use these level-two headings in this order after the title, language links, badge, product statement, and concise version information:

```markdown
## Quick Start
## Configure The Repository
## Run The First Task
## When Finish Fails
## Choose An Adoption Path
### Greenfield Project
### Existing Or Mid-Development Project
## Choose Verification And Gates
## Architecture And Boundaries
## Examples And References
```

Retain this concise product contract:

```markdown
**Agent-Repo-Harness is a repo-local completion gate for AI coding agents.**

It makes task scope, policy, repository-owned verification, and durable finish
evidence explicit before an agent claims completion. It is not a sandbox, a
full agent runtime, or a semantic correctness guarantee.
```

Use one copy-ready installation block:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh /path/to/target-repo
cd /path/to/target-repo
git add AGENTS.md CLAUDE.md agent.md handoff.md .agent docs/agent scripts schemas
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

Show one repository-owned verification example:

```yaml
verification:
  required:
    - name: unit-tests
      command: uv run pytest
    - name: lint
      command: uv run ruff check .
```

Use this helper-first first-task command block:

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

The surrounding numbered flow must cover, in order: read installed context; generate task state; preflight; implement inside scope; finish; inspect `finish-summary.json`; repair failures; bind strict acceptance evidence when enabled; update handoff before claiming completion.

Remove the exhaustive individual-check list, full evidence schema example, complete gate matrix, and platform-by-platform walkthroughs from the README.

Observed: the English README now follows the approved sequence and is 228 lines.

- [x] **Step 2: Rewrite the Traditional Chinese README with structural parity**

Use the same command and YAML blocks with these headings:

```markdown
## 快速開始
## 設定 Repository
## 執行第一個任務
## Finish 失敗時
## 選擇導入路徑
### 從頭開發的新專案
### 既有或開發中的專案
## 選擇 Verification 與 Gates
## 架構與邊界
## 範例與參考資料
```

Translate the prose naturally while preserving: authoritative repo-owned verification; selected profiles replace default commands; task profiles generate enforced flags; `.agent/runs/<timestamp>/` is authoritative evidence; `handoff.md` is continuity state not freshness-enforced by finish; scope and policy are process guardrails rather than security boundaries.

Observed: the Traditional Chinese README uses the matching section order and is 214 lines.

- [x] **Step 3: Verify structural parity and formatting**

```bash
rg -n '^## ' README.md
rg -n '^## ' README.zh-TW.md
wc -l README.md README.zh-TW.md
git diff --check -- README.md README.zh-TW.md
```

Expected: matching approved section order, each README at most 320 lines, and `git diff --check` exit 0.

Observed: headings match the approved order, line counts are 228 and 214, and `git diff --check` exited 0.

- [x] **Step 4: Run the green phase**

Run: `bash validate-harness.sh`

Expected: exit 0, including `DOC_LINKS_RESULT=pass` and `README onboarding entrypoints stay concise`.

Observed: `bash validate-harness.sh` exited 0 with both markers and all sourced suites passing.

- [x] **Step 5: Commit the synchronized rewrite**

```bash
git add README.md README.zh-TW.md docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md
git commit -m "docs: streamline README onboarding flow"
```

Do not stage `.agent/`.

Observed commit: `9be2fb9` (`docs: streamline README onboarding flow`).

---

### Task 3: Verify Scope And Close The Documentation Change

**Files:**
- Modify: `docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md`
- Test: `README.md`
- Test: `README.zh-TW.md`
- Test: `tests/harness/doc-consistency.sh`

**Interfaces:**
- Consumes: the completed contract and synchronized README pair.
- Produces: fresh scope, link, whitespace, and full-suite evidence for the completion claim.

- [x] **Step 1: Check final scope**

```bash
git status --short
git diff --check HEAD~2..HEAD
git diff --name-only HEAD~2..HEAD
```

Expected implementation files:

```text
README.md
README.zh-TW.md
tests/harness/doc-consistency.sh
```

The plan file may also appear. No `templates/scripts/`, `schemas/`, or `.agent/` file may appear.

Observed: `git status --short` showed only the pre-existing untracked `.agent/`; the two implementation commits changed only the planned README, consistency-test, and plan files. `git diff --check HEAD~2..HEAD` exited 0.

- [x] **Step 2: Run document link verification**

Run: `bash templates/scripts/check-doc-links.sh .`

Expected: exit 0 and `DOC_LINKS_RESULT=pass`.

Observed: `bash templates/scripts/check-doc-links.sh .` exited 0 with `DOC_LINKS_RESULT=pass`.

- [x] **Step 3: Run full verification**

Run: `bash validate-harness.sh`

Expected: exit 0 with every sourced harness suite passing.

Observed: the final `bash validate-harness.sh` exited 0 with `PASS: validation completed` and all sourced suites passing.

- [x] **Step 4: Record observed evidence and complete checkboxes**

Change completed steps to `[x]` and record observed commit SHAs and command results below their steps. Do not mark a step complete before its command succeeds.

Observed: all Task 1, Task 2, and Task 3 checkboxes are now complete with command and commit evidence.

- [x] **Step 5: Commit the completion record**

```bash
git add docs/superpowers/plans/2026-07-10-readme-onboarding-architecture.md
git commit -m "chore: mark README onboarding plan complete"
```

Expected: only the plan completion record is committed. Do not stage `.agent/` and do not push.

Observed commit: pending until this completion-record commit is created.
