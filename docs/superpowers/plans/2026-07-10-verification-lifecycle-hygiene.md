# Verification Lifecycle And Runtime Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make repo-defined verification authoritative, let each task select a named verification stage, and prevent untracked harness runtime evidence from blocking subsequent scope checks.

**Architecture:** `.agent/harness.yml` owns named verification command sets and `.agent/task.yml` selects one through `task.verification_profile`. `agent-verify.sh` resolves exactly one configured command set and uses language heuristics only as a fallback. The installer adds precise runtime-evidence ignore entries, while `check-scope.sh` independently filters only untracked harness-owned runtime outputs and continues to enforce tracked changes.

**Tech Stack:** Bash 3.2-compatible shell scripts, dependency-light Python YAML reader, JSON Schema draft 2020-12, Markdown documentation, and Git-backed temporary repository fixtures.

## Global Constraints

- Preserve `verification.required` as the backwards-compatible default command set.
- `task.verification_profile` is optional and must match `[A-Za-z0-9][A-Za-z0-9_-]*`.
- A selected profile replaces `verification.required`; command lists are never merged.
- Repo-defined commands suppress Node, Go, Python, and Docker Compose heuristics; top-level `scripts/*.sh` syntax checking still runs.
- Heuristics remain available only when no repo-defined command set resolves.
- Do not change policy-gate semantics or add a completion gate.
- Ignore only untracked `.agent/runs/`, `.agent/audits/`, `.agent/command-runs/`, and `.agent/sandbox-runs/` runtime outputs.
- Never ignore all of `.agent/`; tracked runtime evidence remains subject to scope and policy rules.
- Do not automatically ignore `.python-version`, `__pycache__/`, `*.egg-info`, or `.agent/subagent-runs/`.
- Preserve Bash 3.2 compatibility: do not use associative arrays, `mapfile`, or Bash 4-only parameter expansion.
- Keep `README.md` and `README.zh-TW.md` behaviorally aligned.
- Keep `docs/agent/gate-guide.md` and `templates/docs/agent/gate-guide.md` byte-for-byte identical.
- Never install Python packages globally; this work requires no new dependency.
- Keep generated `.agent/` state untracked.
- Run `bash validate-harness.sh`, `bash templates/scripts/check-doc-links.sh .`, and `git diff --check` before finalizing.

## File Responsibility Map

- `schemas/harness.schema.json`: named verification profiles and reusable command objects.
- `schemas/task.schema.json`: `task.verification_profile` contract.
- `templates/.agent/harness.yml`: installed profile configuration example.
- `templates/.agent/task.yml`: installed profile-selection guidance.
- `templates/scripts/validate-config.sh`: profile command-list structural validation.
- `templates/scripts/validate-task.sh`: type, name, and profile-existence validation.
- `templates/scripts/agent-task-profile.sh`: `--verification-profile NAME` helper support.
- `templates/scripts/agent-verify.sh`: profile resolution and authoritative command execution.
- `templates/scripts/check-scope.sh`: tracked/untracked separation and runtime filtering.
- `install-agent-harness.sh`: idempotent target `.gitignore` management.
- `tests/fixtures/validate-harness/verification-profiles.yml`: reusable profile fixture.
- `tests/harness/task-validation.sh`, `task-profile.sh`, `repo-verification.sh`, `scope.sh`, `static-install.sh`: focused contract coverage.
- `tests/harness/verification-lifecycle.sh`: installed-target bootstrap finish regression.
- `tests/harness/lib.sh`, `validate-harness.sh`: test root and suite registration.
- `README.md`, `README.zh-TW.md`, `docs/USAGE_WITH_AGENTS.md`: public workflow behavior.
- `docs/agent/gate-guide.md`, `templates/docs/agent/gate-guide.md`: canonical task-stage guidance.
- `docs/stability-contract.md`, `CHANGELOG.md`: compatibility and behavior-change notice.
- `examples/rag-contract-system/adoption/report.md`: corrected adoption evidence.

---

### Task 1: Add The Verification Profile Contract And Helper Interface

**Files:**
- Create: `tests/fixtures/validate-harness/verification-profiles.yml`
- Modify: `schemas/harness.schema.json`
- Modify: `schemas/task.schema.json`
- Modify: `templates/.agent/harness.yml`
- Modify: `templates/.agent/task.yml`
- Modify: `templates/scripts/validate-config.sh`
- Modify: `templates/scripts/validate-task.sh`
- Modify: `templates/scripts/agent-task-profile.sh`
- Modify: `tests/harness/task-validation.sh`
- Modify: `tests/harness/task-profile.sh`
- Modify: `tests/harness/static-install.sh`

**Interfaces:**
- Consumes: existing `verification.required` entries with scalar `name` and `command` fields.
- Produces: `verification.profiles.<name>.required`, optional `task.verification_profile`, `agent-task-profile.sh --verification-profile NAME`, and `validate-task.sh [TASK_FILE] [HARNESS_FILE]`.

- [x] **Step 1: Add the verification-profile fixture**

Create `tests/fixtures/validate-harness/verification-profiles.yml`:

```yaml
name: Verification Profiles Fixture
version: 1
mode: lightweight
paths:
  agent_map: agent.md
  handoff: handoff.md
  task_state: .agent/task.yml
scripts:
  preflight: scripts/agent-preflight.sh
  finish: scripts/agent-finish.sh
  verify: scripts/agent-verify.sh
  check_policy: scripts/check-policy.sh
  check_scope: scripts/check-scope.sh
verification:
  final_gate_command: scripts/agent-finish.sh
  required:
    - name: full-suite
      command: printf 'DEFAULT_SUITE_RAN\n'
  profiles:
    bootstrap:
      required:
        - name: package-import
          command: printf 'BOOTSTRAP_PROFILE_RAN\n'
    feature:
      required:
        - name: unit-tests
          command: printf 'FEATURE_PROFILE_RAN\n'
```

- [x] **Step 2: Add failing task-validation cases**

Append these cases to `tests/harness/task-validation.sh`:

```bash
echo
echo "== Task validation accepts known verification profile =="
verification_profile_task_root="$tmp_root/task-verification-profile"
rm -rf "$verification_profile_task_root"
mkdir -p "$verification_profile_task_root/.agent" "$verification_profile_task_root/scripts/lib"
(
  cd "$verification_profile_task_root"
  cp "$repo_root/templates/scripts/validate-task.sh" scripts/validate-task.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  printf '%s\n' \
    'task:' \
    '  status: "in_progress"' \
    '  goal: "Build package baseline"' \
    '  verification_profile: "bootstrap"' \
    '  allowed_paths: []' \
    '  forbidden_paths: []' \
    '  completion: {}' \
    > .agent/task.yml
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "OK: .agent/task.yml task.verification_profile selects bootstrap"
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "task validation accepts known verification profile"

echo
echo "== Task validation rejects unknown verification profile =="
(
  cd "$verification_profile_task_root"
  sed 's/verification_profile: "bootstrap"/verification_profile: "missing"/' \
    .agent/task.yml > .agent/task-unknown.yml
  if bash scripts/validate-task.sh .agent/task-unknown.yml .agent/harness.yml \
    > unknown.log 2>&1; then
    echo "ERROR: expected unknown verification profile failure"
    exit 1
  fi
  assert_contains unknown.log "task.verification_profile names unknown profile: missing"
  assert_contains unknown.log "TASK_VALIDATION_RESULT=fail"
)
pass "task validation rejects unknown verification profile"

echo
echo "== Task validation rejects malformed verification profile name =="
(
  cd "$verification_profile_task_root"
  sed 's/verification_profile: "bootstrap"/verification_profile: "bad.profile"/' \
    .agent/task.yml > .agent/task-malformed-profile.yml
  if bash scripts/validate-task.sh .agent/task-malformed-profile.yml .agent/harness.yml \
    > malformed-profile.log 2>&1; then
    echo "ERROR: expected malformed verification profile failure"
    exit 1
  fi
  assert_contains malformed-profile.log "must match [A-Za-z0-9][A-Za-z0-9_-]*"
)
pass "task validation rejects malformed verification profile name"

echo
echo "== Config validation rejects empty verification profile commands =="
verification_profile_bad_config_root="$tmp_root/verification-profile-bad-config"
rm -rf "$verification_profile_bad_config_root"
mkdir -p "$verification_profile_bad_config_root/.agent" \
  "$verification_profile_bad_config_root/scripts/lib"
(
  cd "$verification_profile_bad_config_root"
  cp "$repo_root/templates/scripts/validate-config.sh" scripts/validate-config.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'name: Bad Profiles' \
    'version: 1' \
    'mode: lightweight' \
    'paths:' \
    '  agent_map: agent.md' \
    '  handoff: handoff.md' \
    '  task_state: .agent/task.yml' \
    'scripts:' \
    '  preflight: scripts/agent-preflight.sh' \
    '  finish: scripts/agent-finish.sh' \
    '  verify: scripts/agent-verify.sh' \
    '  check_policy: scripts/check-policy.sh' \
    '  check_scope: scripts/check-scope.sh' \
    'verification:' \
    '  final_gate_command: scripts/agent-finish.sh' \
    '  profiles:' \
    '    bootstrap:' \
    '      required: []' \
    > .agent/harness.yml
  printf '%s\n' \
    'version: 1' \
    'default_mode: warn' \
    'risk_files: {}' \
    'rules: []' \
    > .agent/policy.yml
  if bash scripts/validate-config.sh > invalid-profile-config.log 2>&1; then
    echo "ERROR: expected empty verification profile failure"
    exit 1
  fi
  assert_contains invalid-profile-config.log "verification profiles are invalid"
  assert_contains invalid-profile-config.log "CONFIG_VALIDATION_RESULT=fail"
)
pass "config validation rejects empty verification profile commands"
```

- [x] **Step 3: Add the failing helper CLI case**

Insert this case into `tests/harness/task-profile.sh` after the Standard profile case:

```bash
echo
echo "== Task profile selects verification stage =="
task_profile_verification_root="$tmp_root/task-profile-verification"
setup_profile_root "$task_profile_verification_root"
(
  cd "$task_profile_verification_root"
  bash scripts/agent-task-profile.sh standard \
    --goal "Build package baseline." \
    --current-task "Create package import." \
    --verification-profile bootstrap \
    --allowed "src/**" > profile.log 2>&1
  assert_contains .agent/task.yml 'verification_profile: "bootstrap"'
  assert_contains profile.log "Verification profile: bootstrap"
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  bash scripts/validate-task.sh .agent/task.yml .agent/harness.yml > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "task profile selects verification stage"
```

- [x] **Step 4: Run focused tests to prove the contract is red**

Run:

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/task-validation.sh; source tests/harness/task-profile.sh'
```

Expected: FAIL because `task.verification_profile`, the second validator argument, and `--verification-profile` are not implemented.

- [x] **Step 5: Add schema definitions and profile properties**

In `schemas/harness.schema.json`, add this top-level `$defs` block and replace the inline command-item schema with `$ref`:

```json
"$defs": {
  "verificationCommand": {
    "type": "object",
    "required": ["name", "command"],
    "properties": {
      "name": { "type": "string", "minLength": 1 },
      "command": { "type": "string", "minLength": 1 }
    },
    "additionalProperties": false
  },
  "verificationProfile": {
    "type": "object",
    "required": ["required"],
    "properties": {
      "required": {
        "type": "array",
        "minItems": 1,
        "items": { "$ref": "#/$defs/verificationCommand" }
      }
    },
    "additionalProperties": false
  }
}
```

Use these `verification` properties:

```json
"required": {
  "type": "array",
  "items": { "$ref": "#/$defs/verificationCommand" }
},
"profiles": {
  "type": "object",
  "propertyNames": { "pattern": "^[A-Za-z0-9][A-Za-z0-9_-]*$" },
  "additionalProperties": { "$ref": "#/$defs/verificationProfile" }
}
```

In `schemas/task.schema.json`, add beside `current_task`:

```json
"verification_profile": {
  "type": "string",
  "pattern": "^[A-Za-z0-9][A-Za-z0-9_-]*$"
}
```

- [x] **Step 6: Add installed template guidance**

In `templates/.agent/task.yml`, add immediately after `current_task`:

```yaml
  # Optional: select verification.profiles.<name>.required from harness.yml.
  # verification_profile: bootstrap
```

In `templates/.agent/harness.yml`, replace the old heuristic comment with:

```yaml
  # Repo-defined commands are authoritative. When required or a selected
  # profile resolves commands, language heuristics are skipped.
  # required:
  #   - name: lint
  #     command: npm run lint
  # profiles:
  #   bootstrap:
  #     required:
  #       - name: package-import
  #         command: python3 -c 'import package_name'
```

- [x] **Step 7: Extend task validation**

Change `templates/scripts/validate-task.sh` to accept:

```text
Usage: validate-task.sh [TASK_FILE] [HARNESS_FILE]

Defaults:
  TASK_FILE     .agent/task.yml
  HARNESS_FILE  .agent/harness.yml
```

```bash
task_file="${1:-.agent/task.yml}"
harness_file="${2:-.agent/harness.yml}"
```

Add and call this function at the end of `check_task_types()`:

```bash
check_optional_verification_profile() {
  local profile
  local required_entries

  profile="$("$python_bin" "$reader" "$task_file" task.verification_profile --optional 2>&1)" || return 0
  if [ -z "$profile" ]; then
    return 0
  fi
  case "$profile" in
    *[!A-Za-z0-9_-]*|-*|_*)
      fail "$task_file task.verification_profile must match [A-Za-z0-9][A-Za-z0-9_-]*"
      return 0
      ;;
  esac
  if [ ! -f "$harness_file" ]; then
    fail "cannot validate task.verification_profile without $harness_file"
    return 0
  fi
  required_entries="$("$python_bin" "$reader" "$harness_file" \
    "verification.profiles.$profile.required" --optional 2>&1)" || {
      fail "$harness_file could not read verification profile: $profile"
      return 0
    }
  if [ -z "$required_entries" ]; then
    fail "$task_file task.verification_profile names unknown profile: $profile"
    return 0
  fi
  case "$required_entries" in
    \[* ) echo "OK: $task_file task.verification_profile selects $profile" ;;
    *) fail "$harness_file verification.profiles.$profile.required must be an array" ;;
  esac
}
```

- [x] **Step 8: Validate profile maps in harness config**

Add `validate_verification_profiles()` to `templates/scripts/validate-config.sh` and call it after required harness keys:

```bash
validate_verification_profiles() {
  local profiles_json

  profiles_json="$("$python_bin" "$yaml_reader" "$harness_file" \
    verification.profiles --optional 2>&1)" || {
      echo "FAIL: $harness_file could not read verification.profiles"
      failures=$((failures + 1))
      return 0
    }
  if [ -z "$profiles_json" ]; then
    return 0
  fi
  if printf '%s\n' "$profiles_json" | "$python_bin" -c '
import json
import re
import sys
profiles = json.load(sys.stdin)
if not isinstance(profiles, dict):
    raise SystemExit("verification.profiles must be a map")
for name, profile in profiles.items():
    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", name) is None:
        raise SystemExit(f"invalid verification profile name: {name}")
    if not isinstance(profile, dict):
        raise SystemExit(f"verification profile {name} must be a map")
    required = profile.get("required")
    if not isinstance(required, list) or not required:
        raise SystemExit(f"verification profile {name}.required must be a non-empty list")
    for entry in required:
        if not isinstance(entry, dict):
            raise SystemExit(f"verification profile {name} entry must be a map")
        if not isinstance(entry.get("name"), str) or not entry["name"]:
            raise SystemExit(f"verification profile {name} entry name must be non-empty")
        if not isinstance(entry.get("command"), str) or not entry["command"]:
            raise SystemExit(f"verification profile {name} entry command must be non-empty")
'; then
    echo "OK: $harness_file verification profiles are valid"
  else
    echo "FAIL: $harness_file verification profiles are invalid"
    failures=$((failures + 1))
  fi
}
```

- [x] **Step 9: Add `--verification-profile` to the helper**

In `templates/scripts/agent-task-profile.sh`, add the option to usage, initialize `verification_profile=""`, and add:

```bash
    --verification-profile)
      require_option_value "$1" "${2:-}"
      verification_profile="$2"
      shift 2
      ;;
```

Validate and render it with:

```bash
if [ -n "$verification_profile" ]; then
  case "$verification_profile" in
    *[!A-Za-z0-9_-]*|-*|_*)
      echo "ERROR: --verification-profile must match [A-Za-z0-9][A-Za-z0-9_-]*"
      exit 2
      ;;
  esac
fi
```

```bash
  if [ -n "$verification_profile" ]; then
    printf '  verification_profile: %s\n' "$(quote_yaml "$verification_profile")"
  fi
```

Print `Verification profile: ${verification_profile:-default}` beside the existing profile summary.

- [x] **Step 10: Add installed-target assertions**

Add to `tests/harness/static-install.sh` beside existing task/config assertions:

```bash
assert_contains "$target_root/.agent/task.yml" "verification_profile: bootstrap"
assert_contains "$target_root/.agent/harness.yml" "profiles:"
assert_contains "$target_root/scripts/agent-task-profile.sh" "--verification-profile"
assert_contains "$target_root/schemas/task.schema.json" '"verification_profile"'
assert_contains "$target_root/schemas/harness.schema.json" '"verificationProfile"'
```

- [x] **Step 11: Run focused and full validation**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/task-validation.sh; source tests/harness/task-profile.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh'
bash validate-harness.sh
```

Expected: all commands exit 0 and the new profile contract cases print `PASS`.

- [x] **Step 12: Commit the contract**
Observed implementation commit: `c0b62ab` (`feat: add staged verification lifecycle support`).

```bash
git add schemas/harness.schema.json schemas/task.schema.json \
  templates/.agent/harness.yml templates/.agent/task.yml \
  templates/scripts/validate-config.sh templates/scripts/validate-task.sh \
  templates/scripts/agent-task-profile.sh \
  tests/fixtures/validate-harness/verification-profiles.yml \
  tests/harness/task-validation.sh tests/harness/task-profile.sh \
  tests/harness/static-install.sh
git commit -m "feat: add task verification profiles"
```

### Task 2: Make Configured Verification Authoritative

**Files:**
- Modify: `templates/scripts/agent-verify.sh`
- Modify: `tests/harness/repo-verification.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `tests/harness/template-sync.sh`

**Interfaces:**
- Consumes: optional `task.verification_profile`, `verification.required`, and `verification.profiles.<name>.required` from Task 1.
- Produces: one resolved command path and the marker `SKIP: language heuristics because repo-defined verification commands are authoritative`.

- [x] **Step 1: Add a failing profile-selection test**

Append to `tests/harness/repo-verification.sh`:

```bash
echo
echo "== Selected verification profile replaces default commands =="
verify_profile_root="$tmp_root/verify-profile"
rm -rf "$verify_profile_root"
mkdir -p "$verify_profile_root/.agent" "$verify_profile_root/scripts/lib"
git init -q "$verify_profile_root"
(
  cd "$verify_profile_root"
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' 'task:' '  verification_profile: "bootstrap"' > .agent/task.yml
  bash "$repo_root/templates/scripts/agent-verify.sh" > profile.log 2>&1
  assert_contains profile.log "Selected verification profile: bootstrap"
  assert_contains profile.log "BOOTSTRAP_PROFILE_RAN"
  assert_not_contains profile.log "DEFAULT_SUITE_RAN"
  assert_not_contains profile.log "FEATURE_PROFILE_RAN"
  assert_contains profile.log "HARNESS_VERIFY_RESULT=pass"
)
pass "selected verification profile replaces default commands"

echo
echo "== Missing selected verification profile fails =="
(
  cd "$verify_profile_root"
  printf '%s\n' 'task:' '  verification_profile: "missing"' > .agent/task.yml
  if bash "$repo_root/templates/scripts/agent-verify.sh" > missing-profile.log 2>&1; then
    echo "ERROR: expected missing selected profile failure"
    exit 1
  fi
  assert_contains missing-profile.log "selected verification profile has no commands: missing"
  assert_contains missing-profile.log "HARNESS_VERIFY_RESULT=fail"
)
pass "missing selected verification profile fails"
```

- [x] **Step 2: Add failing authoritative and fallback tests**

Append these cases to the same suite:

```bash
echo
echo "== Repo-defined commands suppress Python heuristics =="
verify_authoritative_root="$tmp_root/verify-authoritative"
rm -rf "$verify_authoritative_root"
mkdir -p "$verify_authoritative_root/.agent" \
  "$verify_authoritative_root/scripts/lib" "$verify_authoritative_root/bin"
git init -q "$verify_authoritative_root"
(
  cd "$verify_authoritative_root"
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' '[project]' 'name = "fixture"' 'version = "0.1.0"' > pyproject.toml
  printf '%s\n' '#!/usr/bin/env bash' 'echo PYTEST_HEURISTIC_RAN' 'exit 9' > bin/pytest
  printf '%s\n' '#!/usr/bin/env bash' 'echo RUFF_HEURISTIC_RAN' 'exit 9' > bin/ruff
  chmod +x bin/pytest bin/ruff
  PATH="$verify_authoritative_root/bin:$PATH" \
    bash "$repo_root/templates/scripts/agent-verify.sh" > authoritative.log 2>&1
  assert_contains authoritative.log "DEFAULT_SUITE_RAN"
  assert_contains authoritative.log "SKIP: language heuristics because repo-defined verification commands are authoritative"
  assert_not_contains authoritative.log "PYTEST_HEURISTIC_RAN"
  assert_not_contains authoritative.log "RUFF_HEURISTIC_RAN"
  assert_contains authoritative.log "HARNESS_VERIFY_RESULT=pass"
)
pass "repo-defined commands suppress Python heuristics"

echo
echo "== Missing repo-defined commands retain heuristic fallback =="
verify_fallback_root="$tmp_root/verify-fallback"
rm -rf "$verify_fallback_root"
mkdir -p "$verify_fallback_root/bin"
git init -q "$verify_fallback_root"
(
  cd "$verify_fallback_root"
  printf '%s\n' '[project]' 'name = "fixture"' 'version = "0.1.0"' > pyproject.toml
  printf '%s\n' '#!/usr/bin/env bash' 'echo PYTEST_HEURISTIC_RAN' 'exit 9' > bin/pytest
  printf '%s\n' '#!/usr/bin/env bash' 'echo RUFF_HEURISTIC_RAN' 'exit 9' > bin/ruff
  chmod +x bin/pytest bin/ruff
  if PATH="$verify_fallback_root/bin:$PATH" \
    bash "$repo_root/templates/scripts/agent-verify.sh" > fallback.log 2>&1; then
    echo "ERROR: expected fake heuristic failures"
    exit 1
  fi
  assert_contains fallback.log "PYTEST_HEURISTIC_RAN"
  assert_contains fallback.log "RUFF_HEURISTIC_RAN"
  assert_contains fallback.log "HARNESS_VERIFY_RESULT=fail"
)
pass "missing repo-defined commands retain heuristic fallback"
```

- [x] **Step 3: Run the verification suite to prove it is red**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/repo-verification.sh'
```

Expected: FAIL because the default list runs instead of the selected profile and heuristics still execute after configured commands.

- [x] **Step 4: Resolve the configured command path**

Replace `extract_required_verification_entries()` in `templates/scripts/agent-verify.sh` with:

```bash
resolve_verification_path() {
  local task_file=".agent/task.yml"
  local script_dir
  local reader
  local python_bin
  local profile=""

  script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  reader="$script_dir/lib/read-yaml.py"
  if ! python_bin="$(find_python)"; then
    echo "ERROR: python is required to read verification configuration" >&2
    return 1
  fi
  if [ -f "$task_file" ]; then
    profile="$("$python_bin" "$reader" "$task_file" \
      task.verification_profile --optional)" || return 1
  fi
  if [ -n "$profile" ]; then
    printf '%s\n' "verification.profiles.$profile.required"
    return 0
  fi
  printf '%s\n' "verification.required"
}

extract_required_verification_entries() {
  local config_file="$1"
  local verification_path="$2"
  local script_dir
  local reader
  local python_bin

  script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  reader="$script_dir/lib/read-yaml.py"
  if [ ! -f "$reader" ]; then
    echo "ERROR: YAML reader not found: $reader" >&2
    return 1
  fi
  if ! python_bin="$(find_python)"; then
    echo "ERROR: python is required to read .agent/harness.yml" >&2
    return 1
  fi
  "$python_bin" "$reader" "$config_file" "$verification_path" \
    --optional --list-fields-jsonl name command
}
```

At the start of `run_configured_verification_checks()`, declare `verification_path` and replace its extraction block with:

```bash
  if ! verification_path="$(resolve_verification_path)"; then
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: could not resolve verification command path"
    failures=$((failures + 1))
    return 0
  fi
  if ! entries="$(extract_required_verification_entries "$config_file" "$verification_path")"; then
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: could not read $verification_path from $config_file"
    failures=$((failures + 1))
    return 0
  fi
  if [ -z "$entries" ] && [ "$verification_path" != "verification.required" ]; then
    selected_profile="${verification_path#verification.profiles.}"
    selected_profile="${selected_profile%.required}"
    echo
    echo "FAIL: repo-defined verification config"
    echo "Reason: selected verification profile has no commands: $selected_profile"
    failures=$((failures + 1))
    return 0
  fi
```

Keep the existing `if [ -z "$entries" ]; then return 0; fi` immediately after this selected-profile failure branch. This preserves heuristic fallback only for an absent default list.

After confirming `entries` is non-empty, print the selected profile:

```bash
  case "$verification_path" in
    verification.profiles.*.required)
      selected_profile="${verification_path#verification.profiles.}"
      selected_profile="${selected_profile%.required}"
      echo "Selected verification profile: $selected_profile"
      ;;
  esac
```

Declare `local selected_profile` with the function's other locals.

- [x] **Step 5: Gate language heuristics on configured-command presence**

Keep `scripts/*.sh` syntax checking outside the conditional. Wrap the unchanged Node, Go, Python, and Docker Compose detection blocks in:

```bash
if [ "$repo_defined_checks_found" -eq 1 ]; then
  echo
  echo "SKIP: language heuristics because repo-defined verification commands are authoritative"
else
  if [ -f package.json ]; then
    echo "Detected Node project"
    if have_cmd npm; then
      run_check "npm run lint --if-present" npm run lint --if-present
      run_check "npm run build --if-present" npm run build --if-present
      run_check "npm test --if-present" npm test --if-present
    else
      handle_missing_tool "npm project checks"
    fi
  fi

  if [ -f go.mod ]; then
    echo "Detected Go project"
    if have_cmd go; then
      run_check "gofmt -l ." run_gofmt_check
      run_check "go test ./..." go test ./...
    else
      handle_missing_tool "go project checks"
    fi
  fi

  if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
    echo "Detected Python project"
    if have_cmd python3; then
      run_check "python3 -m compileall ." python3 -m compileall .
    elif have_cmd python; then
      run_check "python -m compileall ." python -m compileall .
    else
      handle_missing_tool "python compile check"
    fi
    if have_cmd pytest; then
      run_check "pytest" pytest
    else
      handle_missing_tool "pytest"
    fi
    if have_cmd ruff; then
      run_check "ruff check ." ruff check .
    else
      handle_missing_tool "ruff"
    fi
  fi

  if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
    echo "Detected Docker Compose config"
    if have_cmd docker; then
      run_check "docker compose config" docker compose config
    else
      handle_missing_tool "docker compose config"
    fi
  fi
fi
```

Do not change missing-tool behavior or configured-command failure semantics.

- [x] **Step 6: Add installed/template assertions**

Add these assertions where the installed verify script and template parity are checked:

```bash
assert_contains "$target_root/scripts/agent-verify.sh" "resolve_verification_path"
assert_contains "$target_root/scripts/agent-verify.sh" "repo-defined verification commands are authoritative"
assert_contains "$repo_root/templates/scripts/agent-verify.sh" "verification.profiles."
```

- [x] **Step 7: Run focused and full validation**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/repo-verification.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh; source tests/harness/template-sync.sh'
bash validate-harness.sh
```

Expected: PASS; configured cases show the skip marker and the no-config case executes fake heuristics.

- [x] **Step 8: Commit authoritative verification behavior**
Observed implementation commit: `c0b62ab` (`feat: add staged verification lifecycle support`).

```bash
git add templates/scripts/agent-verify.sh tests/harness/repo-verification.sh \
  tests/harness/static-install.sh tests/harness/template-sync.sh
git commit -m "fix: make configured verification authoritative"
```

### Task 3: Add Runtime Artifact Hygiene To Installer And Scope Gate

**Files:**
- Modify: `install-agent-harness.sh`
- Modify: `templates/scripts/check-scope.sh`
- Modify: `tests/harness/scope.sh`
- Modify: `tests/harness/static-install.sh`

**Interfaces:**
- Consumes: Git tracked and untracked file lists.
- Produces: four idempotent `.gitignore` entries and the heading `Ignored untracked harness runtime files:`.

- [x] **Step 1: Add failing scope-filter cases**

Append to `tests/harness/scope.sh`:

```bash
echo
echo "== Scope ignores untracked harness runtime outputs =="
scope_runtime_root="$tmp_root/scope-runtime"
rm -rf "$scope_runtime_root"
mkdir -p "$scope_runtime_root/.agent" "$scope_runtime_root/src"
git init -q "$scope_runtime_root"
(
  cd "$scope_runtime_root"
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf '%s\n' 'task:' '  allowed_paths:' '    - "src/**"' > .agent/task.yml
  git add .agent/task.yml
  git commit -q -m "Add task config"
  printf '%s\n' 'work' > src/work.txt
  mkdir -p .agent/runs/one .agent/audits/two \
    .agent/command-runs/three .agent/sandbox-runs/four
  printf '%s\n' 'evidence' > .agent/runs/one/finish-summary.json
  printf '%s\n' 'evidence' > .agent/audits/two/audit-summary.md
  printf '%s\n' 'evidence' > .agent/command-runs/three/command-summary.json
  printf '%s\n' 'evidence' > .agent/sandbox-runs/four/sandbox-summary.json
  bash "$repo_root/templates/scripts/check-scope.sh" > scope.log 2>&1
  assert_contains scope.log "Ignored untracked harness runtime files:"
  assert_contains scope.log ".agent/runs/one/finish-summary.json"
  assert_contains scope.log ".agent/audits/two/audit-summary.md"
  assert_contains scope.log ".agent/command-runs/three/command-summary.json"
  assert_contains scope.log ".agent/sandbox-runs/four/sandbox-summary.json"
  assert_contains scope.log "Changed file count: 1"
  assert_contains scope.log "Scope check passed."
)
pass "scope ignores untracked harness runtime outputs"

echo
echo "== Scope still enforces tracked runtime evidence =="
(
  cd "$scope_runtime_root"
  git add .agent/runs/one/finish-summary.json
  git commit -q -m "Track runtime evidence"
  printf '%s\n' 'changed evidence' > .agent/runs/one/finish-summary.json
  if bash "$repo_root/templates/scripts/check-scope.sh" > tracked-runtime.log 2>&1; then
    echo "ERROR: expected tracked runtime evidence scope failure"
    exit 1
  fi
  assert_contains tracked-runtime.log ".agent/runs/one/finish-summary.json is outside allowed_paths"
  assert_contains tracked-runtime.log "Scope check failed."
)
pass "scope still enforces tracked runtime evidence"
```

- [x] **Step 2: Add failing installer preservation assertions**

Before installation in `tests/harness/static-install.sh`, seed:

```bash
printf '%s\n' 'dist/' > "$target_root/.gitignore"
```

After the first install, assert:

```bash
assert_contains "$target_root/.gitignore" "dist/"
assert_contains "$target_root/.gitignore" ".agent/runs/"
assert_contains "$target_root/.gitignore" ".agent/audits/"
assert_contains "$target_root/.gitignore" ".agent/command-runs/"
assert_contains "$target_root/.gitignore" ".agent/sandbox-runs/"
```

Run the installer a second time and count exact lines:

```bash
bash "$repo_root/install-agent-harness.sh" "$target_root" > reinstall.log 2>&1
for entry in \
  ".agent/runs/" \
  ".agent/audits/" \
  ".agent/command-runs/" \
  ".agent/sandbox-runs/"
do
  count="$(grep -Fxc -- "$entry" "$target_root/.gitignore" || true)"
  if [ "$count" -ne 1 ]; then
    echo "ERROR: expected one .gitignore entry for $entry, got $count"
    exit 1
  fi
done
```

- [x] **Step 3: Run focused tests to prove they are red**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/scope.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh'
```

Expected: FAIL because runtime outputs are counted and the installer does not manage `.gitignore`.

- [x] **Step 4: Separate tracked and untracked scope inputs**

Replace `list_changed_files()` in `templates/scripts/check-scope.sh` with:

```bash
is_harness_runtime_path() {
  case "$1" in
    .agent/runs/*|.agent/audits/*|.agent/command-runs/*|.agent/sandbox-runs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

tracked_changed_files="$(git diff --name-only HEAD 2>/dev/null || true)"
untracked_changed_files="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
included_untracked_files=""
ignored_runtime_files=""

while IFS= read -r file; do
  [ -n "$file" ] || continue
  if is_harness_runtime_path "$file"; then
    ignored_runtime_files="${ignored_runtime_files}${ignored_runtime_files:+
}$file"
  else
    included_untracked_files="${included_untracked_files}${included_untracked_files:+
}$file"
  fi
done <<EOF
$untracked_changed_files
EOF

changed_files="$({
  printf '%s\n' "$tracked_changed_files"
  printf '%s\n' "$included_untracked_files"
} | awk 'NF' | sort -u)"
```

After the scope header and mode, add:

```bash
if [ -n "$ignored_runtime_files" ]; then
  echo "Ignored untracked harness runtime files:"
  printf '%s\n' "$ignored_runtime_files" | sed 's/^/- /'
fi
```

Keep `count_untracked_lines()` on filtered `changed_files`, so ignored runtime files do not affect `max_diff_lines`.

- [x] **Step 5: Add idempotent installer ignore management**

Add after `copy_path()` in `install-agent-harness.sh`:

```bash
ensure_runtime_ignores() {
  local ignore_file="$target/.gitignore"
  local entry
  local missing=""

  for entry in \
    ".agent/runs/" \
    ".agent/audits/" \
    ".agent/command-runs/" \
    ".agent/sandbox-runs/"
  do
    if [ ! -f "$ignore_file" ] || ! grep -Fqx -- "$entry" "$ignore_file"; then
      missing="${missing}${missing:+
}$entry"
    fi
  done
  if [ -z "$missing" ]; then
    echo "UNCHANGED: $ignore_file already ignores harness runtime evidence"
    return 0
  fi
  if [ "$dry_run" -eq 1 ]; then
    printf '%s\n' "$missing" | sed "s|^|DRY-RUN append to $ignore_file: |"
    return 0
  fi
  if [ -f "$ignore_file" ] && [ -s "$ignore_file" ]; then
    printf '\n' >> "$ignore_file"
  fi
  printf '%s\n' "# Agent-Repo-Harness runtime evidence" >> "$ignore_file"
  printf '%s\n' "$missing" >> "$ignore_file"
  echo "UPDATED: $ignore_file"
}
```

Call `ensure_runtime_ignores` after template/schema copying and before chmod handling.

- [x] **Step 6: Run focused and full validation**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/scope.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh'
bash validate-harness.sh
```

Expected: PASS; untracked runtime evidence is listed but not counted, tracked evidence still fails, and ignore entries occur once.

- [x] **Step 7: Commit runtime hygiene**
Observed implementation commit: `c0b62ab` (`feat: add staged verification lifecycle support`).

```bash
git add install-agent-harness.sh templates/scripts/check-scope.sh \
  tests/harness/scope.sh tests/harness/static-install.sh
git commit -m "fix: isolate harness runtime evidence from scope"
```

### Task 4: Prove The Bootstrap-To-Finish Lifecycle In An Installed Target

**Files:**
- Create: `tests/harness/verification-lifecycle.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `validate-harness.sh`

**Interfaces:**
- Consumes: installed profile contract, authoritative verification, runtime ignore management, and finish gate.
- Produces: an end-to-end regression proving a task can finish before tests, a future CLI module, and full-repo lint exist.

- [x] **Step 1: Add a dedicated temporary root**

In `tests/harness/lib.sh`, add:

```bash
verification_lifecycle_root="$tmp_root/verification-lifecycle"
```

- [x] **Step 2: Create the lifecycle suite**

Create `tests/harness/verification-lifecycle.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  lifecycle_repo_root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
  export PYTHONDONTWRITEBYTECODE=1
  # shellcheck source=tests/harness/lib.sh
  source "$lifecycle_repo_root/tests/harness/lib.sh"
fi

echo
echo "== Bootstrap verification profile finish lifecycle =="
rm -rf "$verification_lifecycle_root"
mkdir -p "$verification_lifecycle_root"
git init -q "$verification_lifecycle_root"
(
  cd "$verification_lifecycle_root"
  git config user.email "test@example.com"
  git config user.name "Test User"
  printf '%s\n' "# Verification Lifecycle Fixture" > README.md
  git add README.md
  git commit -q -m "Initialize fixture"

  install_log="$tmp_root/verification-lifecycle-install.log"
  first_finish_log="$tmp_root/verification-lifecycle-first-finish.log"
  second_finish_log="$tmp_root/verification-lifecycle-second-finish.log"
  bash "$repo_root/install-agent-harness.sh" --force \
    "$verification_lifecycle_root" > "$install_log" 2>&1
  printf '%s\n' \
    '# Agent Map' \
    '' \
    '## Purpose' \
    'Exercise staged verification.' \
    '' \
    '## Layout' \
    '- src/: package source' \
    '- scripts/: harness scripts' \
    > agent.md
  cp "$repo_root/tests/fixtures/validate-harness/verification-profiles.yml" .agent/harness.yml
  printf '%s\n' \
    'task:' \
    '  status: "in_progress"' \
    '  goal: "Create the package baseline"' \
    '  current_task: "Task 1: package baseline"' \
    '  verification_profile: "bootstrap"' \
    '  allowed_paths:' \
    '    - "src/**"' \
    '  forbidden_paths: []' \
    '  completion:' \
    '    requires_scope_check: true' \
    '    requires_policy_check: true' \
    '    requires_verification: true' \
    '    expects_handoff_update: true' \
    '    requires_tdd_evidence: false' \
    '    requires_acceptance_check: false' \
    '    requires_review_evidence: false' \
    '    requires_architecture_evidence: false' \
    '    requires_failure_attribution: false' \
    '    requires_intervention_record: false' \
    '    requires_sandbox_verification: false' \
    '    requires_command_ledger: false' \
    '    requires_subagent_evidence: false' \
    > .agent/task.yml
  git add AGENTS.md CLAUDE.md agent.md handoff.md .agent docs scripts schemas .gitignore
  git commit -q -m "Install staged verification harness"

  mkdir -p src/ops_rulekit
  printf '%s\n' '__version__ = "0.1.0"' > src/ops_rulekit/__init__.py

  bash scripts/agent-finish.sh --best-effort > "$first_finish_log" 2>&1
  assert_contains "$first_finish_log" "Selected verification profile: bootstrap"
  assert_contains "$first_finish_log" "BOOTSTRAP_PROFILE_RAN"
  assert_not_contains "$first_finish_log" "DEFAULT_SUITE_RAN"
  assert_not_contains "$first_finish_log" "pytest"
  assert_not_contains "$first_finish_log" "ruff check ."
  assert_contains "$first_finish_log" "AGENT_FINISH_RESULT=pass"

  bash scripts/agent-finish.sh --best-effort > "$second_finish_log" 2>&1
  assert_contains "$second_finish_log" "AGENT_FINISH_RESULT=pass"
  assert_contains "$second_finish_log" "Scope check passed."

  run_count="$(find .agent/runs -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"
  if [ "$run_count" -lt 2 ]; then
    echo "ERROR: expected two finish evidence directories, got $run_count"
    exit 1
  fi
)
pass "bootstrap verification profile finish lifecycle"
```

- [x] **Step 3: Register the suite**

Source it in `validate-harness.sh` immediately after `tests/harness/repo-verification.sh`:

```bash
source "$repo_root/tests/harness/verification-lifecycle.sh"
```

- [x] **Step 4: Run integration verification**

```bash
bash tests/harness/verification-lifecycle.sh
bash validate-harness.sh
```

Expected: PASS with `BOOTSTRAP_PROFILE_RAN`, no default/pytest/ruff execution, and two finish run directories.

- [x] **Step 5: Commit lifecycle coverage**
Observed implementation commit: `c0b62ab` (`feat: add staged verification lifecycle support`).

```bash
git add tests/harness/verification-lifecycle.sh tests/harness/lib.sh validate-harness.sh
git commit -m "test: cover staged verification finish lifecycle"
```

### Task 5: Align Public Guidance, Compatibility Notes, And Adoption Evidence

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/agent/gate-guide.md`
- Modify: `templates/docs/agent/gate-guide.md`
- Modify: `docs/stability-contract.md`
- Modify: `CHANGELOG.md`
- Modify: `examples/rag-contract-system/adoption/report.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/template-sync.sh`

**Interfaces:**
- Consumes: final behavior and markers from Tasks 1-4.
- Produces: bilingual profile guidance, compatibility notice, canonical guide routing, and corrected adoption evidence.

- [x] **Step 1: Add failing documentation assertions**

Add near existing verification assertions in `tests/harness/doc-consistency.sh`:

```bash
assert_contains "$repo_root/README.md" "task.verification_profile"
assert_contains "$repo_root/README.md" "repo-defined commands are authoritative"
assert_contains "$repo_root/README.md" "heuristic fallback"
assert_contains "$repo_root/README.zh-TW.md" "task.verification_profile"
assert_contains "$repo_root/README.zh-TW.md" "repo-defined commands 是具權威性的驗證來源"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "verification.profiles"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Verification Profiles"
assert_contains "$repo_root/docs/agent/gate-guide.md" "--verification-profile"
assert_contains "$repo_root/docs/stability-contract.md" "task.verification_profile"
assert_contains "$repo_root/CHANGELOG.md" "configured verification commands now suppress language heuristics"
assert_not_contains "$repo_root/examples/rag-contract-system/adoption/report.md" \
  "heuristic discovery runs in addition to configured commands"
cmp "$repo_root/docs/agent/gate-guide.md" "$repo_root/templates/docs/agent/gate-guide.md"
```

- [x] **Step 2: Run doc consistency to prove it is red**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh; source tests/harness/doc-consistency.sh'
```

Expected: FAIL on the new profile and authoritative-verification wording.

- [x] **Step 3: Update English verification guidance**

Add under `README.md` Verification Strategy:

````markdown
Repo-defined commands are authoritative. When `verification.required` or a
selected named profile contains commands, `scripts/agent-verify.sh` runs that
command set and skips Node, Go, Python, and Docker Compose heuristics. Projects
without repo-defined commands keep heuristic fallback behavior.

Use `task.verification_profile` when a task must verify only artifacts that
exist at its current delivery stage:

```yaml
# .agent/harness.yml
verification:
  profiles:
    bootstrap:
      required:
        - name: package-import
          command: uv run python -c "import package_name"

# .agent/task.yml
task:
  verification_profile: bootstrap
```

The selected profile replaces `verification.required`; it does not merge with
the default commands. Use a final or release profile only after its tests,
CLI, build, and lint targets exist.
````

Add this Traditional Chinese text to `README.zh-TW.md` under its verification strategy section:

````markdown
repo-defined commands 是具權威性的驗證來源。當
`verification.required` 或選定的 named profile 包含 commands 時，
`scripts/agent-verify.sh` 只執行該 command set，並略過 Node、Go、Python
與 Docker Compose heuristics。沒有 repo-defined commands 的專案仍會使用
heuristic fallback。

當 task 只能驗證目前交付階段已存在的 artifacts 時，使用
`task.verification_profile`：

```yaml
# .agent/harness.yml
verification:
  profiles:
    bootstrap:
      required:
        - name: package-import
          command: uv run python -c "import package_name"

# .agent/task.yml
task:
  verification_profile: bootstrap
```

選定的 profile 會取代 `verification.required`，不會與預設 commands 合併。
只有在 tests、CLI、build 與 lint targets 已存在後，才選擇 final 或 release
profile。
````

- [x] **Step 4: Update canonical guide and usage docs**

Add before the decision matrix in `docs/agent/gate-guide.md`:

````markdown
## Verification Profiles

The repository owns commands in `.agent/harness.yml`. A task may select one
named command set without copying commands into `.agent/task.yml`:

```bash
bash scripts/agent-task-profile.sh standard \
  --goal "Build package baseline" \
  --verification-profile bootstrap \
  --allowed "src/**"
```

When `task.verification_profile` is absent, the harness uses
`verification.required`. When present, it replaces the default list with
`verification.profiles.<name>.required`. Profile commands must reference only
artifacts that exist during that task. Repo-defined commands are authoritative;
language heuristics are fallback behavior only.
````

Copy the complete guide byte-for-byte to `templates/docs/agent/gate-guide.md`.

Add this paragraph to `docs/USAGE_WITH_AGENTS.md` under Operational Boundaries:

```markdown
Use `verification.profiles` to centralize commands for bootstrap, feature, or
release stages, then select one with `task.verification_profile`. The selected
profile replaces `verification.required`. Repo-defined commands are
authoritative; language heuristics run only when no configured command set
exists.

`.agent/runs/`, `.agent/audits/`, `.agent/command-runs/`, and
`.agent/sandbox-runs/` are generated local evidence. Do not add them to task
`allowed_paths` merely to satisfy scope. Tracked files in those directories
remain scope-controlled.
```

- [x] **Step 5: Update compatibility and adoption records**

Add `task.verification_profile` and `.agent/harness.yml verification.profiles` to Intended-Stable Interfaces in `docs/stability-contract.md`.

Add at the top of `CHANGELOG.md`:

```markdown
## Unreleased

### Changed

- Add optional named verification profiles selected through
  `task.verification_profile`.
- Repo-defined configured verification commands now suppress language
  heuristics; repositories that need those checks must list them explicitly in
  `verification.required` or the selected profile.
- Ignore untracked harness runtime evidence in scope checks while continuing to
  enforce tracked evidence changes.
```

In `examples/rag-contract-system/adoption/report.md`, replace the Standard friction cell with `Configured commands are authoritative; PYTHONPATH=src is required by the fixture commands.` Replace `Duplicate heuristic test discovery` with `None observed`. In the High-Risk friction cell, replace `configured and heuristic Python checks` with `configured Python checks`. Replace the Initial Findings paragraph about host-tool sensitivity with:

```markdown
- Configured verification commands are authoritative. The fixture keeps
  `PYTHONPATH=src` because its explicit commands import the uninstalled
  src-layout package; host `pytest` and `ruff` availability no longer adds
  implicit checks.
```

- [x] **Step 6: Run documentation and full validation**

```bash
cmp docs/agent/gate-guide.md templates/docs/agent/gate-guide.md
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh; source tests/harness/doc-consistency.sh; source tests/harness/template-sync.sh'
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
git diff --check
```

Expected: all commands exit 0; doc links print `DOC_LINKS_RESULT=pass`.

- [x] **Step 7: Commit documentation updates**
Observed implementation commit: `c0b62ab` (`feat: add staged verification lifecycle support`).

```bash
git add README.md README.zh-TW.md docs/USAGE_WITH_AGENTS.md \
  docs/agent/gate-guide.md templates/docs/agent/gate-guide.md \
  docs/stability-contract.md CHANGELOG.md \
  examples/rag-contract-system/adoption/report.md \
  tests/harness/doc-consistency.sh tests/harness/template-sync.sh
git commit -m "docs: explain staged verification lifecycle"
```

### Task 6: Final Verification, Plan Status, And Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-10-verification-lifecycle-hygiene.md`
- Modify: `handoff.md`

**Interfaces:**
- Consumes: commits and test evidence from Tasks 1-5.
- Produces: checked plan state, exact verification evidence, and a truthful next-action handoff.

- [x] **Step 1: Inspect the complete change set**

```bash
git status --short
git log --oneline -5
git diff --check
```

Expected: only intentional plan/handoff changes remain; `.agent/` remains untracked; no whitespace errors.

- [x] **Step 2: Run targeted lifecycle verification**

```bash
bash -c 'source tests/harness/lib.sh; source tests/harness/task-validation.sh; source tests/harness/task-profile.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/repo-verification.sh; source tests/harness/scope.sh'
bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh'
bash tests/harness/verification-lifecycle.sh
```

Expected: every suite exits 0 and prints PASS for profile selection, heuristic suppression, runtime filtering, installer idempotence, and two-finish behavior.

- [x] **Step 3: Run repository-wide proof commands**

```bash
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
git diff --check
```

Expected: `DOC_LINKS_RESULT=pass`, all harness suites pass, and no whitespace errors are reported.

- [x] **Step 4: Update plan state only after implementation proof exists**
Implementation evidence:

- Commit: `c0b62ab` (`feat: add staged verification lifecycle support`)
- `bash -c 'source tests/harness/lib.sh; source tests/harness/task-validation.sh; source tests/harness/task-profile.sh'`: PASS
- `bash -c 'source tests/harness/lib.sh; source tests/harness/repo-verification.sh; source tests/harness/scope.sh'`: PASS
- `bash -c 'source tests/harness/lib.sh; source tests/harness/static-install.sh'`: PASS
- `bash tests/harness/verification-lifecycle.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: `DOC_LINKS_RESULT=pass`
- `bash validate-harness.sh`: PASS
- `git diff --check`: PASS

Change Task 1-5 checkboxes from `[ ]` to `[x]` only for steps backed by actual commits and command output. Record exact commit SHAs and final command results; do not substitute generic evidence text.

- [x] **Step 5: Update handoff with actual evidence**

Replace stale current-state text in `handoff.md` with this structure, changing any status that does not match the real run:

```markdown
## Current State

Verification profiles, authoritative configured commands, and runtime artifact
hygiene are implemented and validated.

## Verification

- `bash tests/harness/verification-lifecycle.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: `DOC_LINKS_RESULT=pass`
- `bash validate-harness.sh`: PASS
- `git diff --check`: PASS

## Compatibility

- Existing `verification.required` remains the default command set.
- Configured projects no longer receive implicit language heuristics.
- Projects without configured commands retain heuristic fallback behavior.

## Next Action

Dogfood bootstrap and release profiles in a second non-Python repository before
expanding profile semantics.
```

- [ ] **Step 6: Commit final status and handoff**

```bash
git add docs/superpowers/specs/2026-07-10-verification-lifecycle-hygiene-design.md \
  docs/superpowers/plans/2026-07-10-verification-lifecycle-hygiene.md \
  handoff.md
git commit -m "chore: finalize verification lifecycle rollout"
```

- [ ] **Step 7: Re-run final validation after the status commit**

```bash
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
git status --short
```

Expected: doc links and full validation pass; only intentionally untracked `.agent/` runtime state remains.

## Completion Criteria

- A task can select a known verification profile through the helper or task file.
- Unknown or malformed profile names fail before finish.
- A selected profile replaces, rather than merges with, `verification.required`.
- Configured verification never runs language heuristics implicitly.
- Repositories without configured commands retain heuristic fallback.
- Bootstrap finish passes without tests, a future CLI module, or full-repo lint targets.
- Untracked harness runtime outputs do not count against scope or diff limits.
- Tracked runtime evidence remains scope-controlled.
- Installer `.gitignore` updates preserve existing content and are idempotent.
- English, Traditional Chinese, installed guide, compatibility docs, and adoption evidence describe implemented behavior.
- Full repository validation and doc-link checks pass after the final status commit.
