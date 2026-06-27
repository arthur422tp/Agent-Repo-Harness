# Agent Task Profile Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `scripts/agent-task-profile.sh` so agents can generate valid `.agent/task.yml` files from deterministic Minimal, Standard, and High-Risk profiles.

**Architecture:** Implement a Bash CLI in `templates/scripts/agent-task-profile.sh` that renders the repo's existing YAML subset and preserves profile semantics from the spec. The helper writes `.agent/task.yml` by default, supports `--dry-run`, supports repeated `--allowed` and `--forbidden` flags, and never silently enables high-risk gates except those explicitly selected.

**Tech Stack:** POSIX-ish Bash, existing `templates/scripts/validate-task.sh`, JSON Schema, harness shell tests, Markdown docs.

---

## Source Coverage

This plan implements Capability 2 from:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

## File Structure

Create:

- `templates/scripts/agent-task-profile.sh`: installed helper script for `.agent/task.yml` generation.
- `tests/harness/task-profile.sh`: focused tests for minimal, standard, high-risk selected gates, dry-run, repeated path flags, and output validation.

Modify:

- `tests/harness/lib.sh`: add temporary roots used by `task-profile.sh`.
- `tests/harness/static-install.sh`: require the new helper to ship into installed targets.
- `validate-harness.sh`: add the new test suite.
- `README.md`: mention task profile generation in Quick Start or Gate Profile guidance.
- `README.zh-TW.md`: mirror the helper guidance.
- `docs/agent/gate-guide.md`: replace profile hand-writing guidance with helper-first examples.
- `templates/docs/agent/gate-guide.md`: installed mirror.
- `adapters/codex/AGENTS.md`: instruct Codex agents to prefer the helper when creating task state.
- `adapters/claude-code/CLAUDE.md`: instruct Claude Code agents to prefer the helper when creating task state.

## Task 1: Add Failing Test Coverage

**Files:**
- Create: `tests/harness/task-profile.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `validate-harness.sh`

- [x] **Step 1: Add temporary roots**

In `tests/harness/lib.sh`, add:

```bash
task_profile_minimal_root="$tmp_root/task-profile-minimal"
task_profile_standard_root="$tmp_root/task-profile-standard"
task_profile_high_risk_root="$tmp_root/task-profile-high-risk"
task_profile_dry_run_root="$tmp_root/task-profile-dry-run"
task_profile_invalid_root="$tmp_root/task-profile-invalid"
```

- [x] **Step 2: Add static install assertions**

In `tests/harness/static-install.sh`, add source and installed target assertions:

```bash
assert_file_exists "$repo_root/templates/scripts/agent-task-profile.sh"
assert_file_exists "$target_root/scripts/agent-task-profile.sh"
```

- [x] **Step 3: Add validation suite entry**

In `validate-harness.sh`, add:

```bash
run_test "task profile helper" bash tests/harness/task-profile.sh
```

- [x] **Step 4: Create the focused test suite**

Create `tests/harness/task-profile.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

setup_profile_root() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/.agent" "$root/scripts/lib" "$root/scripts"
  cp "$repo_root/templates/scripts/agent-task-profile.sh" "$root/scripts/agent-task-profile.sh"
  cp "$repo_root/templates/scripts/validate-task.sh" "$root/scripts/validate-task.sh"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" "$root/scripts/lib/read-yaml.py"
  chmod +x "$root/scripts"/*.sh
}

echo "== Minimal task profile =="
setup_profile_root "$task_profile_minimal_root"
(
  cd "$task_profile_minimal_root"
  bash scripts/agent-task-profile.sh minimal \
    --goal "Update docs." \
    --current-task "Clarify README." \
    --allowed "README.md" \
    --forbidden "schemas/**" > profile.log 2>&1
  assert_contains profile.log "AGENT_TASK_PROFILE_RESULT=pass"
  assert_contains .agent/task.yml 'goal: "Update docs."'
  assert_contains .agent/task.yml "requires_tdd_evidence: false"
  assert_contains .agent/task.yml "requires_acceptance_check: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "minimal task profile"

echo
echo "== Standard task profile =="
setup_profile_root "$task_profile_standard_root"
(
  cd "$task_profile_standard_root"
  bash scripts/agent-task-profile.sh standard \
    --goal "Add behavior." \
    --current-task "Implement helper." \
    --allowed "templates/scripts/**" \
    --allowed "tests/harness/**" > profile.log 2>&1
  assert_contains .agent/task.yml "requires_tdd_evidence: true"
  assert_contains .agent/task.yml "requires_acceptance_check: true"
  assert_contains .agent/task.yml "requires_review_evidence: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "standard task profile"

echo
echo "== High-risk selected gates =="
setup_profile_root "$task_profile_high_risk_root"
(
  cd "$task_profile_high_risk_root"
  bash scripts/agent-task-profile.sh high-risk \
    --goal "Change protected workflow." \
    --current-task "Update policy path." \
    --allowed ".agent/policy.yml" \
    --architecture \
    --review \
    --command-ledger > profile.log 2>&1
  assert_contains .agent/task.yml "requires_tdd_evidence: true"
  assert_contains .agent/task.yml "requires_acceptance_check: true"
  assert_contains .agent/task.yml "requires_review_evidence: true"
  assert_contains .agent/task.yml "requires_architecture_evidence: true"
  assert_contains .agent/task.yml "requires_command_ledger: true"
  assert_contains .agent/task.yml "requires_sandbox_verification: false"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "high-risk selected gates"

echo
echo "== Dry-run does not write =="
setup_profile_root "$task_profile_dry_run_root"
(
  cd "$task_profile_dry_run_root"
  bash scripts/agent-task-profile.sh minimal --goal "Preview only." --allowed "README.md" --dry-run > dry-run.log 2>&1
  assert_contains dry-run.log "task:"
  assert_contains dry-run.log "AGENT_TASK_PROFILE_RESULT=pass"
  if [ -f .agent/task.yml ]; then
    echo "ERROR: dry-run wrote .agent/task.yml"
    exit 1
  fi
)
pass "dry-run does not write"

echo
echo "== Invalid profile fails =="
setup_profile_root "$task_profile_invalid_root"
(
  cd "$task_profile_invalid_root"
  if bash scripts/agent-task-profile.sh risky --goal "Bad profile." > invalid.log 2>&1; then
    echo "ERROR: expected invalid profile failure"
    exit 1
  fi
  assert_contains invalid.log "ERROR: unsupported profile: risky"
)
pass "invalid profile fails"
```

- [x] **Step 5: Run the new suite to verify it is red**

Run:

```bash
bash tests/harness/task-profile.sh
```

Expected: FAIL because `templates/scripts/agent-task-profile.sh` does not exist yet.

## Task 2: Implement `agent-task-profile.sh`

**Files:**
- Create: `templates/scripts/agent-task-profile.sh`

- [x] **Step 1: Add the helper script**

Create `templates/scripts/agent-task-profile.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-task-profile.sh PROFILE [options]

Profiles:
  minimal
  standard
  high-risk

Options:
  --goal TEXT
  --current-task TEXT
  --source-plan PATH_OR_TEXT
  --allowed GLOB
  --forbidden GLOB
  --max-changed-files N
  --max-diff-lines N
  --architecture
  --review
  --command-ledger
  --sandbox
  --subagent
  --failure-attribution
  --intervention-record
  --status STATUS
  --output PATH
  --dry-run
  -h, --help
EOF
}

quote_yaml() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

profile="${1:-}"
case "$profile" in
  -h|--help) usage; exit 0 ;;
  minimal|standard|high-risk) shift ;;
  "") usage; exit 2 ;;
  *) echo "ERROR: unsupported profile: $profile"; usage; exit 2 ;;
esac

goal=""
current_task=""
source_plan=""
status="in_progress"
output=".agent/task.yml"
max_changed_files=""
max_diff_lines=""
dry_run="false"
allowed_paths=()
forbidden_paths=()
requires_review_evidence="false"
requires_architecture_evidence="false"
requires_failure_attribution="false"
requires_intervention_record="false"
requires_command_ledger="false"
requires_sandbox_verification="false"
requires_subagent_evidence="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --goal) goal="${2:-}"; shift 2 ;;
    --current-task) current_task="${2:-}"; shift 2 ;;
    --source-plan) source_plan="${2:-}"; shift 2 ;;
    --allowed) allowed_paths+=("${2:-}"); shift 2 ;;
    --forbidden) forbidden_paths+=("${2:-}"); shift 2 ;;
    --max-changed-files) max_changed_files="${2:-}"; shift 2 ;;
    --max-diff-lines) max_diff_lines="${2:-}"; shift 2 ;;
    --architecture) requires_architecture_evidence="true"; shift ;;
    --review) requires_review_evidence="true"; shift ;;
    --command-ledger) requires_command_ledger="true"; shift ;;
    --sandbox) requires_sandbox_verification="true"; shift ;;
    --subagent) requires_subagent_evidence="true"; shift ;;
    --failure-attribution) requires_failure_attribution="true"; shift ;;
    --intervention-record) requires_intervention_record="true"; shift ;;
    --status) status="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unsupported option: $1"; usage; exit 2 ;;
  esac
done

case "$status" in
  not_started|in_progress|blocked|ready_for_review|complete) ;;
  *) echo "ERROR: unsupported status: $status"; exit 2 ;;
esac

case "$profile" in
  minimal)
    requires_tdd_evidence="false"
    requires_acceptance_check="false"
    ;;
  standard|high-risk)
    requires_tdd_evidence="true"
    requires_acceptance_check="true"
    ;;
esac

if [ -z "$goal" ]; then
  echo "ERROR: --goal is required"
  exit 2
fi

render_array() {
  local -n items_ref="$1"
  if [ "${#items_ref[@]}" -eq 0 ]; then
    printf ' []\n'
    return 0
  fi
  printf '\n'
  local item
  for item in "${items_ref[@]}"; do
    printf '    - %s\n' "$(quote_yaml "$item")"
  done
}

render_task() {
  printf 'task:\n'
  printf '  status: %s\n' "$(quote_yaml "$status")"
  printf '  goal: %s\n' "$(quote_yaml "$goal")"
  if [ -n "$source_plan" ]; then
    printf '  source_plan: %s\n' "$(quote_yaml "$source_plan")"
  fi
  if [ -n "$current_task" ]; then
    printf '  current_task: %s\n' "$(quote_yaml "$current_task")"
  fi
  printf '  allowed_paths:'
  render_array allowed_paths
  printf '  forbidden_paths:'
  render_array forbidden_paths
  if [ -n "$max_changed_files" ]; then
    printf '  max_changed_files: %s\n' "$max_changed_files"
  fi
  if [ -n "$max_diff_lines" ]; then
    printf '  max_diff_lines: %s\n' "$max_diff_lines"
  fi
  printf '  completion:\n'
  printf '    requires_scope_check: true\n'
  printf '    requires_policy_check: true\n'
  printf '    requires_verification: true\n'
  printf '    expects_handoff_update: true\n'
  printf '    requires_tdd_evidence: %s\n' "$requires_tdd_evidence"
  printf '    requires_acceptance_check: %s\n' "$requires_acceptance_check"
  printf '    requires_review_evidence: %s\n' "$requires_review_evidence"
  printf '    requires_architecture_evidence: %s\n' "$requires_architecture_evidence"
  printf '    requires_failure_attribution: %s\n' "$requires_failure_attribution"
  printf '    requires_intervention_record: %s\n' "$requires_intervention_record"
  printf '    requires_command_ledger: %s\n' "$requires_command_ledger"
  printf '    requires_sandbox_verification: %s\n' "$requires_sandbox_verification"
  printf '    requires_subagent_evidence: %s\n' "$requires_subagent_evidence"
}

echo "Profile: $profile" >&2
echo "Output: $output" >&2
echo "Enabled high-risk gates:" >&2
echo "- review: $requires_review_evidence" >&2
echo "- architecture: $requires_architecture_evidence" >&2
echo "- command_ledger: $requires_command_ledger" >&2
echo "- sandbox: $requires_sandbox_verification" >&2
echo "- subagent: $requires_subagent_evidence" >&2
echo "- failure_attribution: $requires_failure_attribution" >&2
echo "- intervention_record: $requires_intervention_record" >&2

if [ "$dry_run" = "true" ]; then
  render_task
else
  mkdir -p "$(dirname "$output")"
  render_task > "$output"
fi

echo "AGENT_TASK_PROFILE_RESULT=pass"
```

- [x] **Step 2: Make the helper executable**

Run:

```bash
chmod +x templates/scripts/agent-task-profile.sh
```

- [x] **Step 3: Run focused tests**

Run:

```bash
bash tests/harness/task-profile.sh
```

Expected: PASS.

## Task 3: Document Helper-First Task State

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/agent/gate-guide.md`
- Modify: `templates/docs/agent/gate-guide.md`
- Modify: `adapters/codex/AGENTS.md`
- Modify: `adapters/claude-code/CLAUDE.md`

- [x] **Step 1: Add README example**

Add this example near the current task setup instructions:

```bash
bash scripts/agent-task-profile.sh standard \
  --goal "Add artifact-backed acceptance evidence" \
  --current-task "Implement the evidence ref validator" \
  --allowed "templates/scripts/**" \
  --allowed "tests/harness/**" \
  --allowed "schemas/**" \
  --allowed "docs/**"
```

- [x] **Step 2: Mirror README guidance in Traditional Chinese**

Add the same command to `README.zh-TW.md` with a short sentence explaining that agents should prefer the helper over hand-writing `.agent/task.yml`.

- [x] **Step 3: Update Gate Guide profile examples**

In both gate guide files, replace hand-written profile examples with helper-first examples:

```bash
bash scripts/agent-task-profile.sh minimal --goal "Docs cleanup" --allowed "docs/**"
bash scripts/agent-task-profile.sh standard --goal "Bugfix with tests" --allowed "src/**" --allowed "tests/**"
bash scripts/agent-task-profile.sh high-risk --goal "Policy change" --allowed ".agent/policy.yml" --review --command-ledger
```

- [x] **Step 4: Update adapters**

In `adapters/codex/AGENTS.md` and `adapters/claude-code/CLAUDE.md`, add this instruction:

```markdown
When starting a task in a repo that has `scripts/agent-task-profile.sh`, prefer
that helper to generate `.agent/task.yml`. Do not manually widen allowed paths
or enable high-risk gates to make unrelated edits pass.
```

- [x] **Step 5: Run doc link checks**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
```

Expected: PASS.

## Task 4: Full Verification And Commit

**Files:**
- Modify: all files from Tasks 1-3.
- Modify: `docs/superpowers/plans/2026-06-27-agent-task-profile-helper.md`

- [x] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [x] **Step 2: Mark completed plan steps**

After verification passes, update completed checkboxes in this plan from `- [ ]` to `- [x]`.

- [x] **Step 3: Commit**

```bash
git add templates/scripts/agent-task-profile.sh tests/harness/task-profile.sh tests/harness/lib.sh tests/harness/static-install.sh validate-harness.sh README.md README.zh-TW.md docs/agent/gate-guide.md templates/docs/agent/gate-guide.md adapters/codex/AGENTS.md adapters/claude-code/CLAUDE.md docs/superpowers/plans/2026-06-27-agent-task-profile-helper.md
git commit -m "feat: add agent task profile helper"
```
