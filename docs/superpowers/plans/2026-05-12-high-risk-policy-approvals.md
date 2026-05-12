# High-Risk Policy Approvals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add structured high-risk approval files to Agent-Repo-Harness strict policy checks while preserving legacy approval compatibility.

**Architecture:** Keep high-risk detection in `templates/scripts/check-policy.sh`, but split approval detection into structured and legacy paths. Structured approval lives at `.agent/approvals/high-risk-approved.yml`, is validated with the existing `scripts/lib/read-yaml.py` YAML subset reader, and must cover every matched high-risk changed file before strict mode can pass. Legacy environment and file approvals remain accepted only when no structured approval file exists.

**Tech Stack:** Bash harness scripts, existing YAML subset reader at `templates/scripts/lib/read-yaml.py`, Markdown docs, existing shell validation harness.

---

## Required Semantics

- Strict mode must prefer `.agent/approvals/high-risk-approved.yml` over legacy approval mechanisms.
- If `.agent/approvals/high-risk-approved.yml` exists and is malformed, strict mode must fail even if `AGENT_APPROVED_HIGH_RISK=1` or `.agent/approvals/high-risk-approved` is present.
- If `.agent/approvals/high-risk-approved.yml` exists and does not cover every matched high-risk changed file, strict mode must fail even if a legacy approval is also present.
- Structured approval passes only when:
  - `approval.approved_by` exists and is non-empty.
  - `approval.reason` exists and is non-empty.
  - `approval.approved_paths` exists, is a non-empty list, and contains non-empty path patterns.
  - Every high-risk changed file matched by `.agent/policy.yml` is covered by at least one `approval.approved_paths` pattern.
- `approval.approved_at` and `approval.task_id` are recommended metadata, but they are not required to pass the gate in this change.
- Path coverage should use the same Bash glob matching style already used for policy patterns: `[[ "$file" == $pattern ]]`.
- Warn mode should keep reporting high-risk matches and should not require approval.
- Legacy approvals remain backward compatible:
  - `AGENT_APPROVED_HIGH_RISK=1` passes strict mode when no structured approval file exists, and emits `WARN: legacy high-risk approval from environment is accepted but structured approval is recommended.`
  - `.agent/approvals/high-risk-approved` passes strict mode when no structured approval file exists, and emits `WARN: legacy high-risk approval file is accepted but structured approval is recommended.`

---

## File Structure

- Create `templates/.agent/approvals/high-risk-approved.yml`: installed template for explicit human high-risk approvals.
- Create `templates/docs/agent/policy-approval.md`: concise canonical documentation for high-risk approval behavior.
- Modify `templates/scripts/check-policy.sh`: collect matched high-risk files, validate structured approvals, preserve legacy fallback with warnings, and update help text.
- Modify `tests/harness/policy.sh`: add strict-mode coverage for structured approval success, malformed structured approvals, path coverage, and legacy warnings.
- Modify `tests/harness/static-install.sh`: assert the new template approval file and documentation are present in the source templates and installed target.
- Modify `templates/AGENTS.md`: add one short pointer to `docs/agent/policy-approval.md` only if no existing high-risk policy approval pointer exists.
- Modify `templates/CLAUDE.md`: add the same short pointer only if needed.
- Modify `README.md`: add a short note only if README already discusses policy gates; link or refer to installed docs instead of duplicating policy details.
- Run `bash validate-harness.sh`: verify policy behavior, install coverage, shell syntax, and doc links.

---

### Task 1: Add Failing Policy Tests For Structured Approval

**Files:**
- Modify: `tests/harness/policy.sh`
- Test: `tests/harness/policy.sh`

- [ ] **Step 1: Add a helper pattern for strict policy fixtures**

In `tests/harness/policy.sh`, keep the existing standalone test style. If duplication becomes hard to read, add this helper near the top after `set -euo pipefail`:

```bash
write_auth_policy() {
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
}
```

If the file does not use shared helpers elsewhere, this helper is optional. Do not introduce a broader test framework.

- [ ] **Step 2: Add valid structured approval coverage**

Append this block after the existing `== Strict policy semantics ==` test:

```bash
echo
echo "== Strict policy structured approval =="
rm -rf "$policy_structured_root"
mkdir -p "$policy_structured_root/.agent/approvals" "$policy_structured_root/src/auth"
git init -q "$policy_structured_root"
(
  cd "$policy_structured_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  approved_at: "2026-05-12T00:00:00Z"' \
    '  task_id: "structured-approval-test"' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  structured_log="$policy_structured_root/policy-structured.log"
  bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$structured_log" 2>&1
  assert_contains "$structured_log" "High-risk approval detected from .agent/approvals/high-risk-approved.yml."
  assert_contains "$structured_log" "Strict policy gate passed with structured approval."
)
pass "strict policy structured approval"
```

- [ ] **Step 3: Add malformed structured approval field tests**

Append these three blocks after the valid structured approval test:

```bash
echo
echo "== Strict policy structured approval requires approved_by =="
rm -rf "$policy_structured_no_approver_root"
mkdir -p "$policy_structured_no_approver_root/.agent/approvals" "$policy_structured_no_approver_root/src/auth"
git init -q "$policy_structured_no_approver_root"
(
  cd "$policy_structured_no_approver_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: ""' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_approver_log="$policy_structured_no_approver_root/policy-structured-no-approver.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_approver_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty approved_by"
    exit 1
  fi
  assert_contains "$no_approver_log" "ERROR: structured high-risk approval requires approval.approved_by."
)
pass "strict policy structured approval requires approved_by"

echo
echo "== Strict policy structured approval requires reason =="
rm -rf "$policy_structured_no_reason_root"
mkdir -p "$policy_structured_no_reason_root/.agent/approvals" "$policy_structured_no_reason_root/src/auth"
git init -q "$policy_structured_no_reason_root"
(
  cd "$policy_structured_no_reason_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: ""' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_reason_log="$policy_structured_no_reason_root/policy-structured-no-reason.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_reason_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty reason"
    exit 1
  fi
  assert_contains "$no_reason_log" "ERROR: structured high-risk approval requires approval.reason."
)
pass "strict policy structured approval requires reason"

echo
echo "== Strict policy structured approval requires approved_paths =="
rm -rf "$policy_structured_no_paths_root"
mkdir -p "$policy_structured_no_paths_root/.agent/approvals" "$policy_structured_no_paths_root/src/auth"
git init -q "$policy_structured_no_paths_root"
(
  cd "$policy_structured_no_paths_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: "User explicitly approved this high-risk change."' \
    '  approved_paths: []' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  no_paths_log="$policy_structured_no_paths_root/policy-structured-no-paths.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$no_paths_log" 2>&1; then
    echo "ERROR: expected structured approval failure for empty approved_paths"
    exit 1
  fi
  assert_contains "$no_paths_log" "ERROR: structured high-risk approval requires non-empty approval.approved_paths."
)
pass "strict policy structured approval requires approved_paths"
```

- [ ] **Step 4: Add path coverage failure test**

Append:

```bash
echo
echo "== Strict policy structured approval must cover changed file =="
rm -rf "$policy_structured_uncovered_root"
mkdir -p "$policy_structured_uncovered_root/.agent/approvals" "$policy_structured_uncovered_root/src/auth"
git init -q "$policy_structured_uncovered_root"
(
  cd "$policy_structured_uncovered_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: "human"' \
    '  reason: "User explicitly approved a different high-risk change."' \
    '  approved_paths:' \
    '    - "src/payments/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'line one' > src/auth/login.js
  uncovered_log="$policy_structured_uncovered_root/policy-structured-uncovered.log"
  if bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$uncovered_log" 2>&1; then
    echo "ERROR: expected structured approval failure for uncovered high-risk file"
    exit 1
  fi
  assert_contains "$uncovered_log" "ERROR: structured high-risk approval does not cover src/auth/login.js."
)
pass "strict policy structured approval must cover changed file"
```

- [ ] **Step 5: Add legacy warning tests**

Update the existing environment approval assertions:

```bash
assert_contains "$strict_approved_log" "WARN: legacy high-risk approval from environment is accepted but structured approval is recommended."
assert_contains "$strict_approved_log" "Strict policy gate passed with legacy approval."
```

Update the existing file approval assertions:

```bash
assert_contains "$approved_log" "WARN: legacy high-risk approval file is accepted but structured approval is recommended."
assert_contains "$approved_log" "Strict policy gate passed with legacy approval."
```

- [ ] **Step 6: Add structured precedence over legacy test**

Append:

```bash
echo
echo "== Strict policy structured approval blocks legacy fallback when invalid =="
rm -rf "$policy_structured_precedence_root"
mkdir -p "$policy_structured_precedence_root/.agent/approvals" "$policy_structured_precedence_root/src/auth"
git init -q "$policy_structured_precedence_root"
(
  cd "$policy_structured_precedence_root"
  printf '%s\n' \
    'risk_files:' \
    '  high:' \
    '    - "src/auth/**"' \
    > .agent/policy.yml
  printf '%s\n' \
    'approval:' \
    '  approved_by: ""' \
    '  reason: "Invalid structured approval should block legacy fallback."' \
    '  approved_paths:' \
    '    - "src/auth/**"' \
    > .agent/approvals/high-risk-approved.yml
  printf '%s\n' 'approved' > .agent/approvals/high-risk-approved
  printf '%s\n' 'line one' > src/auth/login.js
  precedence_log="$policy_structured_precedence_root/policy-structured-precedence.log"
  if AGENT_APPROVED_HIGH_RISK=1 bash "$repo_root/templates/scripts/check-policy.sh" --strict .agent/policy.yml >"$precedence_log" 2>&1; then
    echo "ERROR: expected invalid structured approval to block legacy fallback"
    exit 1
  fi
  assert_contains "$precedence_log" "ERROR: structured high-risk approval requires approval.approved_by."
)
pass "strict policy structured approval blocks legacy fallback when invalid"
```

- [ ] **Step 7: Run policy tests and verify failure**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `tests/harness/policy.sh` because `check-policy.sh` does not yet understand structured approvals or legacy warning messages.

---

### Task 2: Implement Structured Approval Validation

**Files:**
- Modify: `templates/scripts/check-policy.sh`
- Test: `tests/harness/policy.sh`

- [ ] **Step 1: Update help text**

In `templates/scripts/check-policy.sh`, replace the approval section in `usage()` with:

```text
Approval for strict mode:
  Preferred:
    .agent/approvals/high-risk-approved.yml
  Legacy compatibility:
    AGENT_APPROVED_HIGH_RISK=1
    .agent/approvals/high-risk-approved
```

- [ ] **Step 2: Refactor YAML reads to accept file paths**

Replace `read_policy_value` and `read_policy_list` with generic helpers, then keep policy-specific wrappers:

```bash
read_yaml_value() {
  local yaml_file="$1"
  local path="$2"
  local output

  if output="$("$python_bin" "$reader" "$yaml_file" "$path" --optional 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: could not read $path from $yaml_file" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_yaml_list() {
  local yaml_file="$1"
  local path="$2"
  local raw
  local output

  raw="$(read_yaml_value "$yaml_file" "$path")"
  case "$raw" in
    ""|null|"{}")
      return 0
      ;;
  esac

  if output="$(printf '%s\n' "$raw" | "$python_bin" -c '
import json
import sys

value = json.load(sys.stdin)
if not isinstance(value, list):
    raise SystemExit("expected list")
for item in value:
    if item is None:
        continue
    print(item)
' 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  echo "ERROR: $yaml_file $path must be a list, empty map, null, or missing" >&2
  printf '%s\n' "$output" >&2
  exit 1
}

read_policy_value() {
  read_yaml_value "$policy_file" "$1"
}

read_policy_list() {
  read_yaml_list "$policy_file" "$1"
}
```

Keep `read_policy_list_into` calling `read_policy_list` so existing policy behavior remains unchanged.

- [ ] **Step 3: Track matched high-risk files**

Before the pattern matching loop, create a temp file and ensure cleanup:

```bash
matched_files_file="$(mktemp "${TMPDIR:-/tmp}/agent-policy-matched.XXXXXX")"
cleanup() {
  rm -f "$matched_files_file"
}
trap cleanup EXIT
```

Inside the existing `if [[ "$file" == $pattern ]]; then` block, after printing the warning line, add:

```bash
      printf '%s\n' "$file" >>"$matched_files_file"
```

After the matching loops, normalize duplicates:

```bash
if [ -s "$matched_files_file" ]; then
  sort -u "$matched_files_file" >"$matched_files_file.sorted"
  mv "$matched_files_file.sorted" "$matched_files_file"
fi
```

- [ ] **Step 4: Add structured approval validation functions**

Add these functions after `read_policy_list_into`:

```bash
structured_approval_file=".agent/approvals/high-risk-approved.yml"

fail_structured_approval() {
  echo "$1"
  return 1
}

read_approval_scalar_required() {
  local path="$1"
  local label="$2"
  local value

  value="$(read_yaml_value "$structured_approval_file" "$path")"
  if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "{}" ]; then
    fail_structured_approval "ERROR: structured high-risk approval requires $label."
    return 1
  fi
  return 0
}

read_approval_paths() {
  local output
  if ! output="$(read_yaml_list "$structured_approval_file" "approval.approved_paths" 2>&1)"; then
    printf '%s\n' "$output"
    return 1
  fi
  if [ -z "$output" ]; then
    fail_structured_approval "ERROR: structured high-risk approval requires non-empty approval.approved_paths."
    return 1
  fi
  printf '%s\n' "$output"
}

validate_structured_approval() {
  local approval_paths
  local high_risk_file
  local approved_pattern
  local covered

  if ! "$python_bin" "$reader" "$structured_approval_file" >/dev/null 2>&1; then
    echo "ERROR: could not parse $structured_approval_file"
    "$python_bin" "$reader" "$structured_approval_file" || true
    return 1
  fi

  read_approval_scalar_required "approval.approved_by" "approval.approved_by" || return 1
  read_approval_scalar_required "approval.reason" "approval.reason" || return 1

  if ! approval_paths="$(read_approval_paths)"; then
    return 1
  fi

  while IFS= read -r approved_pattern; do
    if [ -z "$approved_pattern" ] || [ "$approved_pattern" = "null" ] || [ "$approved_pattern" = "{}" ]; then
      fail_structured_approval "ERROR: structured high-risk approval contains an empty approved path."
      return 1
    fi
  done <<EOF
$approval_paths
EOF

  while IFS= read -r high_risk_file; do
    [ -n "$high_risk_file" ] || continue
    covered=0
    while IFS= read -r approved_pattern; do
      [ -n "$approved_pattern" ] || continue
      if [[ "$high_risk_file" == $approved_pattern ]]; then
        covered=1
        break
      fi
    done <<EOF
$approval_paths
EOF
    if [ "$covered" -ne 1 ]; then
      fail_structured_approval "ERROR: structured high-risk approval does not cover $high_risk_file."
      return 1
    fi
  done <"$matched_files_file"

  return 0
}
```

- [ ] **Step 5: Replace strict approval decision flow**

After `echo "High-risk changes detected."`, replace the existing `detect_approval` output and strict-mode block with this flow:

```bash
structured_approval_detected=0

if [ -f "$structured_approval_file" ]; then
  structured_approval_detected=1
  if validate_structured_approval; then
    approval_detected=1
    approval_source="structured"
  else
    approval_detected=0
    approval_source=""
  fi
else
  detect_approval
fi

if [ "$approval_detected" -eq 1 ]; then
  case "$approval_source" in
    structured)
      echo "High-risk approval detected from .agent/approvals/high-risk-approved.yml."
      ;;
    environment)
      echo "WARN: legacy high-risk approval from environment is accepted but structured approval is recommended."
      echo "High-risk approval detected from environment."
      ;;
    file)
      echo "WARN: legacy high-risk approval file is accepted but structured approval is recommended."
      echo "High-risk approval detected from .agent/approvals/high-risk-approved."
      ;;
  esac
fi

if [ "$mode" = "strict" ]; then
  if [ "$approval_detected" -eq 1 ]; then
    case "$approval_source" in
      structured)
        echo "Strict policy gate passed with structured approval."
        ;;
      environment|file)
        echo "Strict policy gate passed with legacy approval."
        ;;
    esac
    exit 0
  fi

  echo "Strict policy gate failed."
  if [ "$structured_approval_detected" -eq 1 ]; then
    echo "Action: fix .agent/approvals/high-risk-approved.yml or remove it and use a legacy approval only for compatibility."
  else
    echo "Action: create .agent/approvals/high-risk-approved.yml after explicit human approval, or use AGENT_APPROVED_HIGH_RISK=1 / .agent/approvals/high-risk-approved for legacy compatibility."
  fi
  exit 1
fi
```

- [ ] **Step 6: Run policy tests**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS through all policy tests. If a failure says `expected list`, adjust `read_yaml_list` error handling so `approval.approved_paths: []` produces the explicit `ERROR: structured high-risk approval requires non-empty approval.approved_paths.` message.

- [ ] **Step 7: Commit**

```bash
git add templates/scripts/check-policy.sh tests/harness/policy.sh
git commit -m "feat: validate structured high-risk approvals"
```

---

### Task 3: Add Approval Template And Install Coverage

**Files:**
- Create: `templates/.agent/approvals/high-risk-approved.yml`
- Modify: `tests/harness/static-install.sh`
- Test: `tests/harness/static-install.sh`

- [ ] **Step 1: Add failing static install assertions**

In the repository required files loop in `tests/harness/static-install.sh`, add:

```bash
  templates/.agent/approvals/high-risk-approved.yml \
```

In the installed target checks loop, add:

```bash
  .agent/approvals/high-risk-approved.yml \
```

- [ ] **Step 2: Run validation to verify failure**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because the template approval file does not exist.

- [ ] **Step 3: Create the template approval file**

Create `templates/.agent/approvals/high-risk-approved.yml` with:

```yaml
approval:
  # Fill this only after explicit human approval for high-risk changes.
  # Agents must not create or modify this file unless the user explicitly
  # instructs them to record an approval.
  approved_by: ""
  approved_at: ""
  task_id: ""
  reason: ""
  approved_paths:
    # - "src/auth/**"
```

- [ ] **Step 4: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for source template and installed target existence checks.

- [ ] **Step 5: Commit**

```bash
git add templates/.agent/approvals/high-risk-approved.yml tests/harness/static-install.sh
git commit -m "feat: add high-risk approval template"
```

---

### Task 4: Document High-Risk Approval Policy

**Files:**
- Create: `templates/docs/agent/policy-approval.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `README.md`
- Modify: `tests/harness/static-install.sh`
- Test: `tests/harness/static-install.sh`

- [ ] **Step 1: Add failing documentation assertions**

In the repository required files loop in `tests/harness/static-install.sh`, add:

```bash
  templates/docs/agent/policy-approval.md \
```

In the installed target checks loop, add:

```bash
  docs/agent/policy-approval.md \
```

After entrypoint assertions, add:

```bash
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/policy-approval.md"
assert_contains "$repo_root/templates/CLAUDE.md" "docs/agent/policy-approval.md"
```

After installed target entrypoint assertions, add:

```bash
assert_contains "$target_root/AGENTS.md" "docs/agent/policy-approval.md"
assert_contains "$target_root/CLAUDE.md" "docs/agent/policy-approval.md"
```

- [ ] **Step 2: Run validation to verify failure**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/docs/agent/policy-approval.md` and entrypoint pointers are not present.

- [ ] **Step 3: Create concise policy approval documentation**

Create `templates/docs/agent/policy-approval.md` with:

```markdown
# Policy Approval

High-risk approval is needed when `scripts/check-policy.sh --strict` finds changed files that match high-risk patterns in `.agent/policy.yml`.

## Preferred Structured Approval

Use `.agent/approvals/high-risk-approved.yml` only after explicit human approval:

```yaml
approval:
  approved_by: "human"
  approved_at: "2026-05-12T00:00:00Z"
  task_id: "current-task-id-or-description"
  reason: "User explicitly approved this high-risk change."
  approved_paths:
    - "src/auth/**"
    - ".github/workflows/**"
```

Required fields:

- `approval.approved_by` must be non-empty.
- `approval.reason` must be non-empty.
- `approval.approved_paths` must be a non-empty list.

Every high-risk changed file must match at least one `approved_paths` pattern. Use the narrowest patterns that cover the approved change.

## Agent Rule

Agents must not create or modify approval files unless the user explicitly instructs them to record an approval.

## Legacy Compatibility

Strict mode still accepts `AGENT_APPROVED_HIGH_RISK=1` and `.agent/approvals/high-risk-approved` for compatibility. These legacy approvals emit warnings and should be replaced by structured approval when possible.
```

- [ ] **Step 4: Add short entrypoint pointers**

In `templates/AGENTS.md`, add one sentence near existing policy or startup guidance:

```markdown
For high-risk approval rules, see `docs/agent/policy-approval.md`.
```

In `templates/CLAUDE.md`, add the same sentence near existing policy or startup guidance.

- [ ] **Step 5: Update README only if it already mentions policy gates**

If `README.md` has a policy gate section, add one short sentence:

```markdown
Structured high-risk approval is preferred; installed projects document the approval contract in `docs/agent/policy-approval.md`.
```

If README does not discuss policy gates, do not modify it.

- [ ] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for documentation existence, doc links, and entrypoint pointer assertions.

- [ ] **Step 7: Commit**

```bash
git add templates/docs/agent/policy-approval.md templates/AGENTS.md templates/CLAUDE.md tests/harness/static-install.sh README.md
git commit -m "docs: document high-risk policy approvals"
```

Before committing, omit `README.md` from `git add` if it was not modified.

---

### Task 5: Final Verification And Review

**Files:**
- No new files unless validation reveals a focused fix is needed.

- [ ] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 2: Inspect changed files**

Run:

```bash
git status --short
git diff --stat
git diff -- templates/scripts/check-policy.sh tests/harness/policy.sh tests/harness/static-install.sh
git diff -- templates/.agent/approvals/high-risk-approved.yml templates/docs/agent/policy-approval.md templates/AGENTS.md templates/CLAUDE.md README.md
```

Expected changed files:

- `templates/.agent/approvals/high-risk-approved.yml`
- `templates/docs/agent/policy-approval.md`
- `templates/scripts/check-policy.sh`
- `tests/harness/policy.sh`
- `tests/harness/static-install.sh`
- `templates/AGENTS.md` if the pointer was not already present
- `templates/CLAUDE.md` if the pointer was not already present
- `README.md` only if it already mentioned policy gates

- [ ] **Step 3: Review security-sensitive behavior**

Confirm these exact behaviors from test output and script inspection:

- Invalid structured approval blocks legacy fallback.
- Valid structured approval covers every matched high-risk changed file.
- Legacy environment approval emits a warning and passes only when structured approval file is absent.
- Legacy approval file emits a warning and passes only when structured approval file is absent.
- Warn mode still reports high-risk matches without requiring approval.

- [ ] **Step 4: Prepare final report**

Report:

```text
Changed files:
- ...

Structured approval behavior:
- ...

Legacy compatibility behavior:
- ...

Validation:
- bash validate-harness.sh: PASS

Remaining risks:
- ...
```

Do not claim validation passed unless the command completed successfully.

---

## Self-Review

Spec coverage:

- Structured approval file: Task 3 creates `templates/.agent/approvals/high-risk-approved.yml`.
- Strict mode prefers structured approval: Task 2 implements structured-first decision flow and Task 1 tests precedence over legacy fallback.
- Required structured fields: Task 1 tests `approved_by`, `reason`, and `approved_paths`; Task 2 implements validation.
- Approved path coverage: Task 1 tests uncovered files; Task 2 checks every matched high-risk file against `approval.approved_paths`.
- Legacy compatibility: Task 1 updates env/file tests for warning behavior; Task 2 preserves legacy fallback when structured file is absent.
- Existing YAML subset reader: Task 2 uses `templates/scripts/lib/read-yaml.py` only.
- Docs: Task 4 adds `templates/docs/agent/policy-approval.md`, concise entrypoint pointers, and optional README note.
- Static install checks: Tasks 3 and 4 update `tests/harness/static-install.sh`.
- Validation: Task 5 requires `bash validate-harness.sh`.
- Non-goals: The plan does not modify context loading, hook adapters, subagent finish integration, Codex lifecycle prompts, acceptance/review gates, doc freshness gates, or removal of legacy approvals.

Placeholder scan:

- No `TBD`, `TODO`, "implement later", or unspecified test instructions remain.
- README changes are conditional because the original task explicitly says "only if necessary"; the plan gives exact text if the condition applies.

Type and name consistency:

- Structured approval path is consistently `.agent/approvals/high-risk-approved.yml`.
- Legacy approval path is consistently `.agent/approvals/high-risk-approved`.
- Required YAML paths are consistently `approval.approved_by`, `approval.reason`, and `approval.approved_paths`.
- Pass messages distinguish `Strict policy gate passed with structured approval.` from `Strict policy gate passed with legacy approval.`.
