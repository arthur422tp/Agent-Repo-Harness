# Context Loading Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-efficient context loading policy to Agent-Repo-Harness so agents load concise durable context first and expand to raw files only when justified.

**Architecture:** Define the policy once in the installed repo entrypoints and stable repo map template, then mirror it in the bootstrap skill, Codex/Claude adapters, usage docs, and the context collection script. Keep the policy textual and shell-only so it remains universal across supported agents.

**Tech Stack:** Markdown templates, Bash harness scripts, existing shell validation harness.

---

## File Structure

- Modify `templates/AGENTS.md`: add the canonical startup context budget and staged loading rules for installed repos.
- Modify `templates/CLAUDE.md`: mirror the same context loading policy for Claude Code installs.
- Modify `adapters/codex/AGENTS.md`: make Codex-specific guidance point to staged loading before broader inspection.
- Modify `adapters/codex/codex-start-prompt.md`: replace broad read instructions with budgeted startup instructions.
- Modify `adapters/claude-code/CLAUDE.md`: mirror the adapter-level staged loading policy.
- Modify `templates/agent.md`: add stable repository memory guidance for repo authors: keep summaries concise, link deeper docs, and avoid task state.
- Modify `skills/repo-context-bootstrap/SKILL.md`: update the bootstrap workflow to build compact context before reading broad source files.
- Modify `templates/scripts/collect-context.sh`: reduce default output size, include task scope, and add an explicit full mode for deeper debugging.
- Modify `README.md`: document the policy in the quick-start and agent entrypoint sections.
- Modify `docs/USAGE_WITH_AGENTS.md`: add a dedicated "Context Loading Policy" section with copyable prompts.
- Modify `docs/codex-usage.md`: align Codex usage with the new policy.
- Modify `docs/superpowers-integration.md`: clarify how Superpowers skills should respect staged context loading.
- Modify `tests/harness/static-install.sh`: assert required files and installed outputs contain the new policy text.
- Modify `tests/harness/repo-verification.sh`: add coverage for `collect-context.sh --full` and the default compact output.
- Run `bash validate-harness.sh`: verify shell syntax, install smoke tests, doc links, and harness behavior.

---

### Task 1: Add Canonical Context Loading Policy To Installed Entrypoints

**Files:**
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Test: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing assertions for installed entrypoints**

Edit `tests/harness/static-install.sh` in the installed target checks block, after `assert_exists "$target_root/AGENTS.md"` and `assert_exists "$target_root/CLAUDE.md"` have run, by adding:

```bash
  assert_contains "$target_root/AGENTS.md" "## Context Loading Policy"
  assert_contains "$target_root/AGENTS.md" "Start compact: read summaries and task boundaries before raw source."
  assert_contains "$target_root/AGENTS.md" "Expand only for files directly relevant to the current task."
  assert_contains "$target_root/CLAUDE.md" "## Context Loading Policy"
  assert_contains "$target_root/CLAUDE.md" "Start compact: read summaries and task boundaries before raw source."
  assert_contains "$target_root/CLAUDE.md" "Expand only for files directly relevant to the current task."
```

- [x] **Step 2: Run validation to verify the assertions fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `== Installed target checks ==` because `AGENTS.md` and `CLAUDE.md` do not yet contain `## Context Loading Policy`.

- [x] **Step 3: Update `templates/AGENTS.md` with the canonical policy**

Insert this section after the opening "Start here before editing" list and before "During the task":

```markdown
## Context Loading Policy

Start compact: read summaries and task boundaries before raw source.

Default startup budget:

1. Read this file.
2. Read `agent.md` for stable facts, but treat linked deeper docs as optional until needed.
3. Read `handoff.md` for current task state.
4. Read `.agent/task.yml` for allowed paths, forbidden paths, and completion requirements.
5. Read `.agent/policy.yml` only for policy rules that apply to files you expect to touch.
6. Run `scripts/collect-context.sh` when available instead of pasting large context into the prompt.

Expand only for files directly relevant to the current task. Prefer `rg`, file lists, symbol search, and targeted `sed -n` ranges over reading whole directories or long files. Load broad docs, generated files, lockfiles, logs, and historical plans only when they answer a concrete question.

When context grows, summarize what was learned in `handoff.md` or `docs/agent/discoveries.md` and continue from that summary instead of reloading the same raw files.
```

- [x] **Step 4: Update `templates/CLAUDE.md` with the same policy**

Insert the same `## Context Loading Policy` section after Claude's initial startup instructions and before task execution rules. If `templates/CLAUDE.md` uses different headings, keep its existing order and insert the section before the first "During" or "Before completion" guidance.

- [x] **Step 5: Run validation to verify the entrypoint checks pass**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS through `== Installed target checks ==`; unrelated later failures must be investigated before continuing.

- [x] **Step 6: Commit**

```bash
git add templates/AGENTS.md templates/CLAUDE.md tests/harness/static-install.sh
git commit -m "docs: add context loading policy to entrypoints"
```

---

### Task 2: Align Agent Adapters With Staged Context Loading

**Files:**
- Modify: `adapters/codex/AGENTS.md`
- Modify: `adapters/codex/codex-start-prompt.md`
- Modify: `adapters/claude-code/CLAUDE.md`
- Test: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing assertions for adapter files**

In `tests/harness/static-install.sh`, in the repository required files section after the adapter `assert_exists` loop succeeds, add:

```bash
assert_contains "$repo_root/adapters/codex/AGENTS.md" "## Context Loading Policy"
assert_contains "$repo_root/adapters/codex/codex-start-prompt.md" "Use staged context loading"
assert_contains "$repo_root/adapters/claude-code/CLAUDE.md" "## Context Loading Policy"
```

- [x] **Step 2: Run validation to verify the assertions fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because adapter files do not yet contain the staged loading text.

- [x] **Step 3: Update `adapters/codex/AGENTS.md`**

Add this section near the top, after the file identifies itself as a Codex adapter:

```markdown
## Context Loading Policy

Use staged context loading before editing:

1. Read root `AGENTS.md`.
2. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and only the policy entries in `.agent/policy.yml` that apply to the expected files.
3. Prefer `scripts/collect-context.sh` for startup context.
4. Use `rg` and targeted file ranges to expand context for the active task.

Do not load large directories, generated outputs, historical plans, or unrelated docs unless the task specifically depends on them.
```

- [x] **Step 4: Update `adapters/codex/codex-start-prompt.md`**

Replace the current recommended prompt block with:

```text
You are working in this repository using Agent-Repo-Harness.
Use staged context loading: read `AGENTS.md`, then `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries before inspecting raw source.
Use `scripts/collect-context.sh` when available for compact startup context.
Expand context only with `rg`, file lists, and targeted file ranges relevant to the current task.
For delegated work, fill `.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh`.
Respect task boundaries.
Before claiming completion, run `scripts/agent-finish.sh`.
If verification cannot be run, explain exactly why and update `handoff.md`.
```

- [x] **Step 5: Update `adapters/claude-code/CLAUDE.md`**

Add the same `## Context Loading Policy` section used for `adapters/codex/AGENTS.md`, replacing "Codex" wording with "Claude Code" only if the surrounding file needs that term for clarity.

- [x] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for adapter assertions and doc link validation.

- [x] **Step 7: Commit**

```bash
git add adapters/codex/AGENTS.md adapters/codex/codex-start-prompt.md adapters/claude-code/CLAUDE.md tests/harness/static-install.sh
git commit -m "docs: align adapters with staged context loading"
```

---

### Task 3: Make Stable Repo Memory Token-Efficient By Default

**Files:**
- Modify: `templates/agent.md`
- Modify: `skills/repo-context-bootstrap/SKILL.md`
- Test: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing assertions for repo memory policy**

In `tests/harness/static-install.sh`, after installed target assertions for `agent.md`, add:

```bash
  assert_contains "$target_root/agent.md" "## Context Loading"
  assert_contains "$target_root/agent.md" "Keep this file compact enough to read at task start."
  assert_contains "$repo_root/skills/repo-context-bootstrap/SKILL.md" "Build compact context before broad source inspection."
```

- [x] **Step 2: Run validation to verify the assertions fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/agent.md` and `skills/repo-context-bootstrap/SKILL.md` do not yet contain these exact policy lines.

- [x] **Step 3: Update `templates/agent.md`**

Insert after `## Project Overview`:

```markdown
## Context Loading

Keep this file compact enough to read at task start. Store stable facts, entrypoints, commands, risks, and links to deeper docs. Do not paste long source excerpts, historical plans, generated output, logs, or one-time task instructions here.

Use this loading order for ordinary tasks:

1. Read `AGENTS.md` or the installed agent entrypoint.
2. Read this file for stable facts.
3. Read `handoff.md` for current state.
4. Read `.agent/task.yml` for scope and completion requirements.
5. Read only applicable `.agent/policy.yml` rules.
6. Expand to source files with `rg` and targeted ranges.

When a repeated discovery matters, add a short `Verified:` or `Inferred:` note here or in `docs/agent/discoveries.md` instead of requiring future agents to rediscover it from raw files.
```

- [x] **Step 4: Update `skills/repo-context-bootstrap/SKILL.md`**

Replace the current `## Steps` list with:

```markdown
## Steps

1. Build compact context before broad source inspection.
2. Read installed entrypoints: `AGENTS.md`, `CLAUDE.md`, or adapter guidance that exists in the target repo.
3. Read `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries.
4. Run `scripts/agent-preflight.sh` if available.
5. Inspect README files, manifests, entrypoints, tests, config, and infra files only when needed to verify missing or stale facts.
6. Create or refresh `agent.md` from concrete evidence.
7. Create or refresh `handoff.md` with current state only.
8. Create `docs/agent/known-issues.md` if repeated pitfalls exist.
9. Create or refresh scripts and `.agent` config if they are missing.
10. Mark uncertain items as `Inferred:` with the file or command that led to the inference.
```

Keep the existing `## Hard Rules` section, and add this bullet to it:

```markdown
- Prefer concise summaries and links over copying raw file contents into repo memory.
```

- [x] **Step 5: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for repo memory policy assertions.

- [x] **Step 6: Commit**

```bash
git add templates/agent.md skills/repo-context-bootstrap/SKILL.md tests/harness/static-install.sh
git commit -m "docs: make repo memory compact by default"
```

---

### Task 4: Add Compact And Full Modes To Context Collection

**Files:**
- Modify: `templates/scripts/collect-context.sh`
- Modify: `tests/harness/repo-verification.sh`

- [x] **Step 1: Add failing tests for compact and full collection modes**

Append this block to `tests/harness/repo-verification.sh`:

```bash
echo
echo "== Context collection modes =="
context_root="$tmp_root/context-collection"
mkdir -p "$context_root/.agent" "$context_root/docs/agent" "$context_root/scripts/lib"
git init -q "$context_root"
(
  cd "$context_root"
  cp "$repo_root/templates/scripts/collect-context.sh" scripts/collect-context.sh
  chmod +x scripts/collect-context.sh
  printf '%s\n' "# Agent" "stable line" > agent.md
  printf '%s\n' "# Handoff" "current state" > handoff.md
  printf '%s\n' "# Known" "known issue" > docs/agent/known-issues.md
  printf '%s\n' "# Discoveries" "discovery" > docs/agent/discoveries.md
  printf '%s\n' "status: active" "allowed_paths:" "  - src/**" > .agent/task.yml
  printf '%s\n' "high_risk_paths:" "  - secrets/**" > .agent/policy.yml
  compact_log="$context_root/compact.log"
  full_log="$context_root/full.log"
  bash scripts/collect-context.sh >"$compact_log" 2>&1
  bash scripts/collect-context.sh --full >"$full_log" 2>&1
  assert_contains "$compact_log" "== Context Loading Policy =="
  assert_contains "$compact_log" "Mode: compact"
  assert_contains "$compact_log" "== Task Scope =="
  assert_contains "$compact_log" "== Policy =="
  assert_contains "$full_log" "Mode: full"
  assert_contains "$full_log" "== Known Issues =="
  assert_contains "$full_log" "== Discoveries =="
)
pass "context collection modes"
```

- [x] **Step 2: Run validation to verify the test fails**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `== Context collection modes ==` because `collect-context.sh` does not yet support `--full` or print the policy/mode headings.

- [x] **Step 3: Replace `templates/scripts/collect-context.sh` with compact/full behavior**

Use this complete script:

```bash
#!/usr/bin/env bash
set -euo pipefail

mode="compact"
if [ "${1:-}" = "--full" ]; then
  mode="full"
elif [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: collect-context.sh [--full]"
  echo "Default compact mode prints startup-critical context only."
  exit 0
elif [ "${1:-}" != "" ]; then
  echo "ERROR: unknown argument: $1" >&2
  echo "Usage: collect-context.sh [--full]" >&2
  exit 2
fi

in_git_repo=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git_repo=1
fi

line_limit=80
if [ "$mode" = "full" ]; then
  line_limit=200
fi

show_file() {
  local file="$1"
  local title="$2"
  local required="${3:-optional}"

  echo
  echo "== $title =="
  if [ -f "$file" ]; then
    sed -n "1,${line_limit}p" "$file"
  elif [ "$required" = "required" ]; then
    echo "MISSING: $file"
  else
    echo "SKIP: $file not found"
  fi
}

echo "== Context Loading Policy =="
echo "Mode: $mode"
echo "Start compact. Expand only to files directly relevant to the current task."
echo "Use --full when debugging stale repo memory, policy drift, or handoff gaps."

echo
echo "== Git status =="
if [ "$in_git_repo" -eq 1 ]; then
  git status --short || true
else
  echo "SKIP: not a git repository"
fi

echo
echo "== Recent commits =="
if [ "$in_git_repo" -eq 1 ]; then
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git log --oneline -5
  else
    echo "SKIP: no commits yet"
  fi
else
  echo "SKIP: not a git repository"
fi

show_file "agent.md" "agent.md" required
show_file "handoff.md" "handoff.md" required
show_file ".agent/task.yml" "Task Scope" required
show_file ".agent/policy.yml" "Policy" required

if [ "$mode" = "full" ]; then
  show_file "docs/agent/known-issues.md" "Known Issues"
  show_file "docs/agent/discoveries.md" "Discoveries"
fi
```

- [x] **Step 4: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for `== Context collection modes ==` and shell syntax checks.

- [x] **Step 5: Commit**

```bash
git add templates/scripts/collect-context.sh tests/harness/repo-verification.sh
git commit -m "feat: add compact context collection mode"
```

---

### Task 5: Document The Policy In User-Facing Guides

**Files:**
- Modify: `README.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/codex-usage.md`
- Modify: `docs/superpowers-integration.md`
- Test: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing assertions for documentation coverage**

In `tests/harness/static-install.sh`, after repository doc link validation passes, add:

```bash
assert_contains "$repo_root/README.md" "## Context Loading Policy"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "## Context Loading Policy"
assert_contains "$repo_root/docs/codex-usage.md" "staged context loading"
assert_contains "$repo_root/docs/superpowers-integration.md" "staged context loading"
```

- [x] **Step 2: Run validation to verify documentation assertions fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because these docs do not yet include the new policy text.

- [x] **Step 3: Update `README.md`**

Add this section after "Typical Workflow":

```markdown
## Context Loading Policy

Agent-Repo-Harness is designed for staged context loading. Agents should read compact, durable context first:

1. `AGENTS.md` or the installed adapter entrypoint
2. `agent.md`
3. `handoff.md`
4. `.agent/task.yml`
5. applicable entries from `.agent/policy.yml`

Then they should expand with `rg`, file lists, and targeted file ranges for the active task. `scripts/collect-context.sh` prints compact startup context by default; `scripts/collect-context.sh --full` includes optional known issues and discoveries for deeper debugging.
```

- [x] **Step 4: Update `docs/USAGE_WITH_AGENTS.md`**

Add this section after "Shared Pattern":

````markdown
## Context Loading Policy

Use staged context loading to keep agent runs token-efficient:

1. Start with durable context: `AGENTS.md`, `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries.
2. Run `scripts/collect-context.sh` when available instead of pasting long prompt context.
3. Expand to raw source only for files directly relevant to the current task.
4. Prefer `rg`, file lists, symbol search, and targeted file ranges over reading whole directories.
5. Save repeated discoveries in `docs/agent/discoveries.md` or compact stable facts in `agent.md`.

Short prompt:

```text
Use staged context loading.
Read the installed agent entrypoint, stable repo memory, handoff, task scope, and applicable policy first.
Use `scripts/collect-context.sh` if available.
Expand only into files relevant to this task.
```
````

- [x] **Step 5: Update `docs/codex-usage.md`**

Find the Codex startup guidance and replace any broad "inspect everything" wording with:

```markdown
Use staged context loading for Codex sessions. Start with `AGENTS.md`, `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries. Then use `rg` and targeted file ranges for the active task.
```

- [x] **Step 6: Update `docs/superpowers-integration.md`**

Add this paragraph in the section that maps Superpowers skills to harness contracts:

```markdown
Superpowers skills should respect staged context loading. Planning and execution skills can ask for focused evidence, but they should prefer `agent.md`, `handoff.md`, `.agent/task.yml`, `.agent/policy.yml`, and `scripts/collect-context.sh` before loading broad raw source or historical plans.
```

- [x] **Step 7: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for documentation assertions and doc link validation.

- [x] **Step 8: Commit**

```bash
git add README.md docs/USAGE_WITH_AGENTS.md docs/codex-usage.md docs/superpowers-integration.md tests/harness/static-install.sh
git commit -m "docs: document staged context loading"
```

---

### Task 6: Final Verification And Handoff

**Files:**
- Modify: `handoff.md` only if this repository has a live root `handoff.md`; otherwise no handoff file is changed.

- [x] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS with all harness checks complete.

- [x] **Step 2: Inspect final diff**

Run:

```bash
git diff --stat
git diff -- templates/AGENTS.md templates/CLAUDE.md templates/agent.md skills/repo-context-bootstrap/SKILL.md templates/scripts/collect-context.sh
git diff -- README.md docs/USAGE_WITH_AGENTS.md docs/codex-usage.md docs/superpowers-integration.md
git diff -- tests/harness/static-install.sh tests/harness/repo-verification.sh
```

Expected: Diff is limited to context loading policy docs, script behavior, and validation assertions.

- [x] **Step 3: Update handoff if present**

If root `handoff.md` exists, append or update its current task state with:

```markdown
## Current Task State

- Added staged context loading policy to installed entrypoints, adapters, repo memory template, bootstrap skill, and user docs.
- Updated `scripts/collect-context.sh` so compact mode is default and `--full` includes optional known issues and discoveries.
- Verified with `bash validate-harness.sh`.

## Next Recommended Action

- Return to the paused implementation plan under `docs/plans/` and continue from its next unchecked task.
```

- [x] **Step 4: Commit final handoff update if a handoff file changed**

Run only if `handoff.md` exists and was modified:

```bash
git add handoff.md
git commit -m "docs: update handoff after context policy work"
```

---

## Self-Review

Spec coverage:

- Main topic is token-efficient context loading: covered by Tasks 1, 3, 4, and 5.
- Do this before returning to `docs/plans`: Task 6 records the next recommended action to resume `docs/plans/`.
- Keep plan implementation-ready: every task lists exact files, commands, expected outcomes, and concrete text or script content.

Placeholder scan:

- No deferred implementation placeholders are used.

Type and name consistency:

- The policy heading is consistently `## Context Loading Policy`.
- The context script mode flag is consistently `--full`.
- Test assertions match the exact text added in implementation steps.
