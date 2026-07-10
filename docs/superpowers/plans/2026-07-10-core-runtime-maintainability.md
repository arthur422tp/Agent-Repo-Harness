# Core Runtime Maintainability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the finish runtime into contract-tested Bash 3.2-compatible modules so gate inventory, execution, and summary rendering each have one internal owner while the installed public behavior remains compatible.

**Architecture:** Preserve `scripts/agent-finish.sh` and `scripts/agent-verify.sh` as public entrypoints. Introduce policy-free common helpers, then extract summary rendering, then replace duplicated strict and best-effort gate calls with one ordered registry and runner; validate every stage in source and temporary installed targets.

**Tech Stack:** Bash 3.2-compatible shell, Python standard library for JSON serialization and existing YAML reading, existing `tests/harness/*.sh` suites

## Global Constraints

- Preserve public CLI options, invocation paths, exit codes, strict versus best-effort semantics, canonical gate order, result markers, evidence filenames, required Markdown rows and groups, required JSON keys and evidence paths, and installed-target behavior.
- Keep `scripts/agent-finish.sh` as the canonical completion boundary.
- Do not use associative arrays, namerefs, `mapfile`, `jq`, `yq`, or a new runtime dependency.
- Keep internal modules under `templates/scripts/lib/`; downstream users invoke public scripts and must not source internal libraries as supported APIs.
- Do not add, remove, or reorder gates; change schemas or task flags; change verification-selection policy; add an installer manifest; add validation-suite selection; or revise README onboarding.
- Keep generated `.agent/` state untracked.
- Run `bash validate-harness.sh` after every task and commit each task independently.

## File Structure

- `templates/scripts/lib/harness-common.sh`: command discovery, Python discovery, run-local temporary files, and atomic replacement.
- `templates/scripts/lib/finish-summary.sh`: Markdown and JSON finish summary rendering.
- `templates/scripts/lib/gate-registry.sh`: ordered Bash 3.2 indexed-array gate inventory and validation.
- `templates/scripts/lib/finish-runner.sh`: sequential execution and status capture from the registry.
- `templates/scripts/agent-finish.sh`: public CLI and top-level lifecycle only.
- `templates/scripts/agent-verify.sh`: public verification CLI; shares only policy-free helpers.
- `tests/harness/finish-runtime-modules.sh`: module, registry, error, and architecture contract coverage.
- `tests/harness/lib.sh`: reusable finish summary and JSON contract assertions.
- `tests/harness/finish-examples.sh` and `tests/harness/resource-envelope.sh`: installed-shape finish integration.
- `tests/harness/static-install.sh`: temporary installer parity for internal libraries.
- `tests/harness/template-sync.sh`: committed installed-shape parity where applicable.
- `docs/stability-contract.md`: internal-library boundary.

---

### Task 1: Lock The Existing Finish Contract

**Files:**
- Create: `tests/harness/finish-runtime-modules.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `validate-harness.sh`
- Modify: `docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md`

**Interfaces:**
- Consumes: current `templates/scripts/agent-finish.sh`, `assert_finish_summary_contract(root, expected_result)`, and `assert_finish_json_contract(root, expected_result)`.
- Produces: `assert_finish_gate_order(root)` and a characterization suite that later tasks must keep green.

- [x] **Step 1: Add an exact gate-order assertion helper**

Append this helper to `tests/harness/lib.sh` after `assert_finish_json_contract`:

```bash
assert_finish_gate_order() {
  local root="$1"
  local summary_json

  summary_json="$(find "$root/.agent/runs" -type f -name "finish-summary.json" | sort | tail -n 1)"
  "$(find_python)" - "$summary_json" <<'PY'
import json
import sys
from pathlib import Path

expected = [
    "check-agent-md",
    "check-scope",
    "check-policy",
    "check-tdd-evidence",
    "check-acceptance",
    "check-review-evidence",
    "check-architecture-evidence",
    "check-failure-attribution",
    "check-interventions",
    "check-command-ledger",
    "check-sandbox-evidence",
    "check-subagent-evidence",
    "validate-episode",
    "agent-verify",
    "resource-envelope",
]
actual = [gate["name"] for gate in json.loads(Path(sys.argv[1]).read_text())["gates"]]
if actual != expected:
    raise SystemExit(f"expected gate order {expected}, got {actual}")
PY
}
```

- [x] **Step 2: Create the characterization suite**

Create `tests/harness/finish-runtime-modules.sh` with this baseline contract:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Finish runtime module contract =="

assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'Usage: agent-finish.sh [--strict|--best-effort]'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=pass'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'AGENT_FINISH_RESULT=fail'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'Usage: agent-verify.sh [--strict|--best-effort]'

if rg -n 'declare -A|local -n|mapfile' \
  "$repo_root/templates/scripts/agent-finish.sh" \
  "$repo_root/templates/scripts/agent-verify.sh"
then
  fail "finish runtime uses Bash features newer than the supported baseline"
fi

pass "finish runtime public contract is characterized"
```

Source the suite in `validate-harness.sh` immediately after `resource-envelope.sh`
so module tests may reuse a completed installed-shape run without rebuilding it.

- [x] **Step 3: Call the order assertion from existing finish integrations**

After each existing pair of `assert_finish_summary_contract` and
`assert_finish_json_contract` calls in `tests/harness/finish-examples.sh` and
`tests/harness/resource-envelope.sh`, add:

```bash
assert_finish_gate_order "$scenario_root"
```

Use the actual scenario variable at each call site, such as
`$finish_acceptance_review_root` or `$resource_disabled_root`.

- [x] **Step 4: Run characterization coverage**

Run: `bash validate-harness.sh`

Expected: exit 0. This task is a refactor characterization baseline, so its new
tests intentionally pass against the pre-refactor runtime.

- [x] **Step 5: Commit the baseline contract**

```bash
git add tests/harness/finish-runtime-modules.sh tests/harness/lib.sh \
  tests/harness/finish-examples.sh tests/harness/resource-envelope.sh \
  validate-harness.sh docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md
git commit -m "test: characterize finish runtime contract"
```

Verification: `bash validate-harness.sh` passed (exit 0).

---

### Task 2: Extract Policy-Free Common Helpers

**Files:**
- Create: `templates/scripts/lib/harness-common.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `templates/scripts/agent-verify.sh`
- Modify: `tests/harness/finish-runtime-modules.sh`
- Modify: `tests/harness/finish-examples.sh`
- Modify: `tests/harness/resource-envelope.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md`

**Interfaces:**
- Produces: `harness_have_cmd(name)`, `harness_find_python()`, `harness_make_temp_file(run_dir, stem)`, and `harness_atomic_replace(source, destination)`.
- Consumes: no gate policy and no caller-specific global state.

- [x] **Step 1: Write failing common-helper and install assertions**

Add to `tests/harness/finish-runtime-modules.sh`:

```bash
assert_exists "$repo_root/templates/scripts/lib/harness-common.sh"
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'source "$script_dir/lib/harness-common.sh"'
assert_contains "$repo_root/templates/scripts/agent-verify.sh" \
  'source "$script_dir/lib/harness-common.sh"'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'have_cmd() {'
assert_not_contains "$repo_root/templates/scripts/agent-verify.sh" 'find_python() {'
```

Add to installed-target assertions in `tests/harness/static-install.sh`:

```bash
assert_exists "$target_root/scripts/lib/harness-common.sh"
```

After the module exists, exercise atomic replacement in
`finish-runtime-modules.sh`:

```bash
(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  atomic_root="$tmp_root/harness-common-atomic"
  mkdir -p "$atomic_root"
  temporary="$(harness_make_temp_file "$atomic_root" summary)"
  printf '%s\n' complete >"$temporary"
  harness_atomic_replace "$temporary" "$atomic_root/final.txt"
  assert_contains "$atomic_root/final.txt" complete
  [ ! -e "$temporary" ] || fail "atomic replacement left its temporary file"

  temporary="$(harness_make_temp_file "$atomic_root" failure)"
  printf '%s\n' incomplete >"$temporary"
  if harness_atomic_replace "$temporary" "$atomic_root/missing/final.txt"; then
    fail "atomic replacement accepted a missing destination directory"
  fi
  [ ! -e "$atomic_root/missing/final.txt" ] || \
    fail "atomic replacement exposed partial final content"
)
```

- [x] **Step 2: Run the red phase**

Run: `bash validate-harness.sh`

Expected: FAIL because `templates/scripts/lib/harness-common.sh` does not exist.

- [x] **Step 3: Implement the common helper module**

Create `templates/scripts/lib/harness-common.sh`:

```bash
#!/usr/bin/env bash

harness_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

harness_find_python() {
  if harness_have_cmd python3; then
    printf '%s\n' python3
    return 0
  fi
  if harness_have_cmd python; then
    printf '%s\n' python
    return 0
  fi
  return 1
}

harness_make_temp_file() {
  local run_dir="$1"
  local stem="$2"
  mktemp "$run_dir/.${stem}.XXXXXX"
}

harness_atomic_replace() {
  local source="$1"
  local destination="$2"
  mv "$source" "$destination"
}
```

- [x] **Step 4: Source the module from both public entrypoints**

In each entrypoint, calculate `script_dir` immediately after `set -euo pipefail`,
require the module, and source it:

```bash
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
common_lib="$script_dir/lib/harness-common.sh"
if [ ! -f "$common_lib" ]; then
  echo "ERROR: required internal library not found: $common_lib" >&2
  exit 1
fi
source "$common_lib"
```

Replace `have_cmd` with `harness_have_cmd` and `find_python` with
`harness_find_python`; remove the local definitions. Do not move verification
selection or resource policy.

- [x] **Step 5: Update manual installed-shape fixtures**

In every fixture that copies `agent-finish.sh` or `agent-verify.sh` into a local
`scripts/` directory, also copy:

```bash
cp "$repo_root/templates/scripts/lib/harness-common.sh" scripts/lib/harness-common.sh
```

At minimum update `tests/harness/finish-examples.sh` and
`tests/harness/resource-envelope.sh`. Use `rg -n 'cp .*agent-(finish|verify)\.sh' tests/harness`
to find additional local-copy fixtures and update all matches.

- [x] **Step 6: Run the green phase and commit**

Run: `bash validate-harness.sh`

Expected: exit 0 with unchanged finish and verification contracts.

```bash
git add templates/scripts/lib/harness-common.sh templates/scripts/agent-finish.sh \
  templates/scripts/agent-verify.sh tests/harness/finish-runtime-modules.sh \
  tests/harness/finish-examples.sh tests/harness/resource-envelope.sh \
  tests/harness/static-install.sh docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md
git commit -m "refactor: share finish runtime shell helpers"
```

Verification observed:
- Red: `bash validate-harness.sh` exited 1 because the new installed target did
  not contain `scripts/lib/harness-common.sh`.
- Green: `bash validate-harness.sh` exited 0, including the common-helper
  atomic replacement contract.
- Commit SHA: `f544778` (`refactor: share finish runtime shell helpers`).

---

### Task 3: Extract Finish Summary Rendering

**Files:**
- Create: `templates/scripts/lib/finish-summary.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/finish-runtime-modules.sh`
- Modify: `tests/harness/finish-examples.sh`
- Modify: `tests/harness/resource-envelope.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md`

**Interfaces:**
- Produces: `finish_write_markdown_summary(overall_result)`, `finish_write_json_summary(overall_result)`, and `finish_write_episode_summary(overall_result)`.
- Consumes: the current entrypoint globals for timestamps, paths, mode, scalar gate statuses, Python interpreter, elapsed time, and resource status.

- [x] **Step 1: Write failing extraction assertions**

Add:

```bash
assert_exists "$repo_root/templates/scripts/lib/finish-summary.sh"
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'source "$script_dir/lib/finish-summary.sh"'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_summary() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_json_summary() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'write_episode_summary() {'
assert_contains "$repo_root/templates/scripts/lib/finish-summary.sh" \
  'finish_write_markdown_summary() {'
assert_contains "$repo_root/templates/scripts/lib/finish-summary.sh" \
  'finish_write_json_summary() {'
```

Also assert `finish-summary.sh` exists in the temporary installed target.

- [x] **Step 2: Run the red phase**

Run: `bash validate-harness.sh`

Expected: FAIL because `finish-summary.sh` does not exist.

- [x] **Step 3: Move the existing renderers without changing their payloads**

Create `finish-summary.sh` with the three renamed functions. Move the complete
current bodies of `write_summary`, `write_json_summary`, and
`write_episode_summary` from `templates/scripts/agent-finish.sh` without
changing emitted fields, ordering, or Python data structures. For each final
destination, replace the direct write with this exact pattern:

```bash
temp_summary="$(harness_make_temp_file "$run_dir" finish-summary-md)"
render_current_markdown_payload >"$temp_summary"
harness_atomic_replace "$temp_summary" "$summary_file"
```

`render_current_markdown_payload` in this snippet means the complete existing
brace-group payload from `write_summary`; do not introduce a function with that
name. Apply the same temporary-destination pattern to the two Python writers by
pointing their existing destination environment variables at temporary files.

For Python JSON writers, set the environment destination to the temporary path,
then atomically replace it only after Python exits 0.

- [x] **Step 4: Source and call the new renderer API**

Require and source `finish-summary.sh` after `harness-common.sh`. Replace calls:

```bash
finish_write_markdown_summary "fail"
finish_write_json_summary "fail"
finish_write_episode_summary "fail"
```

and the corresponding `pass` calls. Keep gate execution hard-coded in this task.

- [x] **Step 5: Verify JSON write failures remain blocking**

Add a subshell test that sources both modules, points every evidence variable at
one valid run directory, and replaces the Python command with `false`:

```bash
(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/finish-summary.sh"
  run_dir="$tmp_root/finish-summary-failure"
  mkdir -p "$run_dir"
  timestamp=20260710-000000
  mode=strict
  mode_arg=--strict
  start_epoch=0
  elapsed_seconds=0
  resource_status=0
  agent_md_status=0
  scope_status=0
  policy_status=0
  tdd_evidence_status=0
  acceptance_status=0
  review_status=0
  architecture_status=0
  failure_attribution_status=0
  interventions_status=0
  command_ledger_status=0
  sandbox_evidence_status=0
  subagent_evidence_status=0
  episode_status=0
  verify_status=0
  summary_file="$run_dir/finish-summary.md"
  summary_json_file="$run_dir/finish-summary.json"
  changed_files_file="$run_dir/changed-files.txt"
  diff_stat_file="$run_dir/git-diff-stat.txt"
  resource_result_file="$run_dir/resource-envelope-result.txt"
  check_agent_md_result_file="$run_dir/check-agent-md-result.txt"
  scope_result_file="$run_dir/scope-result.txt"
  policy_result_file="$run_dir/policy-result.txt"
  tdd_evidence_result_file="$run_dir/tdd-evidence-result.txt"
  acceptance_result_file="$run_dir/acceptance-result.txt"
  review_result_file="$run_dir/review-result.txt"
  architecture_result_file="$run_dir/architecture-evidence-result.txt"
  failure_attribution_result_file="$run_dir/failure-attribution-result.txt"
  interventions_result_file="$run_dir/interventions-result.txt"
  command_ledger_result_file="$run_dir/command-ledger-result.txt"
  sandbox_evidence_result_file="$run_dir/sandbox-evidence-result.txt"
  subagent_evidence_result_file="$run_dir/subagent-evidence-result.txt"
  episode_result_file="$run_dir/episode-result.txt"
  verify_result_file="$run_dir/verify-result.txt"
  python_bin=false
  if finish_write_json_summary pass; then
    fail "JSON serializer failure was reported as success"
  fi
  [ ! -e "$summary_json_file" ] || fail "failed JSON write exposed final output"
)
```

- [x] **Step 6: Update fixture copies, run green, and commit**

Copy `finish-summary.sh` beside `harness-common.sh` in manual finish fixtures.

Run: `bash validate-harness.sh`

Expected: exit 0; Markdown rows, JSON keys, order, evidence paths, and episode
summary assertions remain green.

```bash
git add templates/scripts/lib/finish-summary.sh templates/scripts/agent-finish.sh \
  tests/harness/finish-runtime-modules.sh tests/harness/finish-examples.sh \
  tests/harness/resource-envelope.sh tests/harness/static-install.sh \
  docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md
git commit -m "refactor: extract finish summary rendering"
```

Verification observed:
- Red: `bash validate-harness.sh` exited 1 because the installed target did not
  contain `scripts/lib/finish-summary.sh`.
- Green: `bash validate-harness.sh` exited 0, preserving Markdown rows, JSON
  keys, evidence paths, and blocking behavior on JSON write failures.
- Commit SHA: `9e1fa68` (`refactor: extract finish summary rendering`).

---

### Task 4: Introduce The Ordered Gate Registry And Runner

**Files:**
- Create: `templates/scripts/lib/gate-registry.sh`
- Create: `templates/scripts/lib/finish-runner.sh`
- Modify: `templates/scripts/lib/finish-summary.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/finish-runtime-modules.sh`
- Modify: `tests/harness/finish-examples.sh`
- Modify: `tests/harness/resource-envelope.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md`

**Interfaces:**
- Produces indexed arrays `FINISH_GATE_IDS`, `FINISH_GATE_KINDS`, `FINISH_GATE_GROUPS`, `FINISH_GATE_SCRIPTS`, `FINISH_GATE_COMMON_ARGS`, `FINISH_GATE_STRICT_ARGS`, `FINISH_GATE_BEST_EFFORT_ARGS`, `FINISH_GATE_RESULT_NAMES`, `FINISH_GATE_TASK_FLAGS`, and mutable `FINISH_GATE_STATUSES`.
- Produces `finish_init_gate_registry()`, `finish_validate_gate_registry()`, `finish_run_registered_gates(mode, run_dir)`, `finish_gate_index(id)`, and `finish_set_gate_status(id, status)`.
- Consumes `harness_make_temp_file` and `harness_atomic_replace`.

- [ ] **Step 1: Write failing registry and architecture tests**

Add exact assertions:

```bash
assert_exists "$repo_root/templates/scripts/lib/gate-registry.sh"
assert_exists "$repo_root/templates/scripts/lib/finish-runner.sh"
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'run_gate() {'
assert_not_contains "$repo_root/templates/scripts/agent-finish.sh" 'run_gate "check-'
assert_contains "$repo_root/templates/scripts/agent-finish.sh" \
  'finish_run_registered_gates "$mode" "$run_dir"'
registration_count="$(rg -c '^  finish_register_gate ' \
  "$repo_root/templates/scripts/lib/gate-registry.sh")"
[ "$registration_count" -eq 15 ] || \
  fail "expected 15 registered finish gates, got $registration_count"
```

The 15 registrations are 14 command gates plus `resource-envelope`. Preserve
the current 15 JSON gate entries.

Add shell tests that source the registry, call `finish_init_gate_registry` and
`finish_validate_gate_registry`, then compare `FINISH_GATE_IDS[*]` to:

```text
check-agent-md check-scope check-policy check-tdd-evidence check-acceptance check-review-evidence check-architecture-evidence check-failure-attribution check-interventions check-command-ledger check-sandbox-evidence check-subagent-evidence validate-episode agent-verify resource-envelope
```

Add malformed-registry coverage using isolated subshells:

```bash
(
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  finish_init_gate_registry
  FINISH_GATE_IDS+=("check-agent-md")
  if finish_validate_gate_registry >duplicate-id.log 2>&1; then
    fail "duplicate gate ID unexpectedly validated"
  fi
  assert_contains duplicate-id.log "duplicate gate ID: check-agent-md"
)

(
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  finish_init_gate_registry
  FINISH_GATE_RESULT_NAMES=("${FINISH_GATE_RESULT_NAMES[@]:0:14}")
  if finish_validate_gate_registry >length-mismatch.log 2>&1; then
    fail "mismatched registry arrays unexpectedly validated"
  fi
  assert_contains length-mismatch.log "registry array length mismatch"
)
```

- [ ] **Step 2: Run the red phase**

Run: `bash validate-harness.sh`

Expected: FAIL because the registry and runner files do not exist.

- [ ] **Step 3: Implement the registry API**

Use Bash 3.2 indexed arrays and this registration signature:

```bash
finish_register_gate() {
  FINISH_GATE_IDS+=("$1")
  FINISH_GATE_KINDS+=("$2")
  FINISH_GATE_GROUPS+=("$3")
  FINISH_GATE_SCRIPTS+=("$4")
  FINISH_GATE_COMMON_ARGS+=("$5")
  FINISH_GATE_STRICT_ARGS+=("$6")
  FINISH_GATE_BEST_EFFORT_ARGS+=("$7")
  FINISH_GATE_RESULT_NAMES+=("$8")
  FINISH_GATE_TASK_FLAGS+=("$9")
  FINISH_GATE_STATUSES+=("")
}
```

`finish_init_gate_registry` must reset all ten arrays to `()` before registering
these exact records in order:

| ID | Kind | Group | Script | Common arg | Strict arg | Best-effort arg | Result | Task flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| check-agent-md | command | Core Guardrails | scripts/check-agent-md.sh | agent.md | empty | empty | check-agent-md-result.txt | empty |
| check-scope | command | Core Guardrails | scripts/check-scope.sh | empty | --strict | --warn | scope-result.txt | task.completion.requires_scope_check |
| check-policy | command | Core Guardrails | scripts/check-policy.sh | empty | --strict | --warn | policy-result.txt | task.completion.requires_policy_check |
| check-tdd-evidence | command | Optional Evidence | scripts/check-tdd-evidence.sh | empty | empty | empty | tdd-evidence-result.txt | task.completion.requires_tdd_evidence |
| check-acceptance | command | Optional Evidence | scripts/check-acceptance.sh | empty | empty | empty | acceptance-result.txt | task.completion.requires_acceptance_check |
| check-review-evidence | command | Optional Evidence | scripts/check-review-evidence.sh | empty | empty | empty | review-result.txt | task.completion.requires_review_evidence |
| check-architecture-evidence | command | Optional Evidence | scripts/check-architecture-evidence.sh | empty | empty | empty | architecture-evidence-result.txt | task.completion.requires_architecture_evidence |
| check-failure-attribution | command | Optional Evidence | scripts/check-failure-attribution.sh | empty | empty | empty | failure-attribution-result.txt | task.completion.requires_failure_attribution |
| check-interventions | command | Optional Evidence | scripts/check-interventions.sh | empty | empty | empty | interventions-result.txt | task.completion.requires_intervention_record |
| check-command-ledger | command | Optional Evidence | scripts/check-command-ledger.sh | empty | empty | empty | command-ledger-result.txt | task.completion.requires_command_ledger |
| check-sandbox-evidence | command | Optional Evidence | scripts/check-sandbox-evidence.sh | empty | empty | empty | sandbox-evidence-result.txt | task.completion.requires_sandbox_verification |
| check-subagent-evidence | command | Optional Evidence | scripts/check-subagent-evidence.sh | empty | empty | empty | subagent-evidence-result.txt | task.completion.requires_subagent_evidence |
| validate-episode | command | Verification And Limits | scripts/validate-episode.sh | empty | empty | empty | episode-result.txt | empty |
| agent-verify | command | Verification And Limits | scripts/agent-verify.sh | empty | --strict | --best-effort | verify-result.txt | task.completion.requires_verification |
| resource-envelope | computed | Verification And Limits | empty | empty | empty | empty | resource-envelope-result.txt | empty |

Implement validation for equal lengths, unique IDs, unique result names,
allowed kinds and groups, non-empty command scripts for command gates, and an
empty script for computed gates.

- [ ] **Step 4: Implement the runner API**

For each command gate, build a Bash indexed command array:

```bash
command=(bash "${FINISH_GATE_SCRIPTS[$index]}")
[ -n "${FINISH_GATE_COMMON_ARGS[$index]}" ] && \
  command+=("${FINISH_GATE_COMMON_ARGS[$index]}")
if [ "$mode" = strict ] && [ -n "${FINISH_GATE_STRICT_ARGS[$index]}" ]; then
  command+=("${FINISH_GATE_STRICT_ARGS[$index]}")
fi
if [ "$mode" = best-effort ] && [ -n "${FINISH_GATE_BEST_EFFORT_ARGS[$index]}" ]; then
  command+=("${FINISH_GATE_BEST_EFFORT_ARGS[$index]}")
fi
```

Capture output into a run-local temporary file, finalize the existing result
filename atomically, set `FINISH_GATE_STATUSES[$index]`, increment `failures`
on nonzero status, and skip computed gates. After `check_resource_envelope`,
call `finish_set_gate_status resource-envelope "$resource_status"`.

Add this fake-gate coverage to `finish-runtime-modules.sh`:

```bash
runner_root="$tmp_root/finish-runner-modules"
mkdir -p "$runner_root/run"
printf '%s\n' '#!/usr/bin/env bash' 'echo pass-output' 'exit 0' \
  >"$runner_root/pass.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo fail-output' 'exit 7' \
  >"$runner_root/fail.sh"
chmod +x "$runner_root/pass.sh" "$runner_root/fail.sh"

(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  source "$repo_root/templates/scripts/lib/finish-runner.sh"
  FINISH_GATE_IDS=()
  FINISH_GATE_KINDS=()
  FINISH_GATE_GROUPS=()
  FINISH_GATE_SCRIPTS=()
  FINISH_GATE_COMMON_ARGS=()
  FINISH_GATE_STRICT_ARGS=()
  FINISH_GATE_BEST_EFFORT_ARGS=()
  FINISH_GATE_RESULT_NAMES=()
  FINISH_GATE_TASK_FLAGS=()
  FINISH_GATE_STATUSES=()
  finish_register_gate pass command 'Core Guardrails' \
    "$runner_root/pass.sh" '' '' '' pass-result.txt ''
  finish_register_gate fail command 'Core Guardrails' \
    "$runner_root/fail.sh" '' '' '' fail-result.txt ''
  failures=0
  finish_run_registered_gates strict "$runner_root/run" || true
  [ "${FINISH_GATE_STATUSES[0]}" -eq 0 ] || fail "pass gate status changed"
  [ "${FINISH_GATE_STATUSES[1]}" -eq 7 ] || fail "fail gate status changed"
  [ "$failures" -eq 1 ] || fail "expected one runner failure"
  assert_contains "$runner_root/run/pass-result.txt" "pass-output"
  assert_contains "$runner_root/run/fail-result.txt" "fail-output"
)
```

Add evidence-write failure coverage in a separate subshell:

```bash
(
  source "$repo_root/templates/scripts/lib/harness-common.sh"
  source "$repo_root/templates/scripts/lib/gate-registry.sh"
  source "$repo_root/templates/scripts/lib/finish-runner.sh"
  FINISH_GATE_IDS=()
  FINISH_GATE_KINDS=()
  FINISH_GATE_GROUPS=()
  FINISH_GATE_SCRIPTS=()
  FINISH_GATE_COMMON_ARGS=()
  FINISH_GATE_STRICT_ARGS=()
  FINISH_GATE_BEST_EFFORT_ARGS=()
  FINISH_GATE_RESULT_NAMES=()
  FINISH_GATE_TASK_FLAGS=()
  FINISH_GATE_STATUSES=()
  finish_register_gate write-failure command 'Core Guardrails' \
    "$runner_root/pass.sh" '' '' '' missing/result.txt ''
  failures=0
  if finish_run_registered_gates strict "$runner_root/run"; then
    fail "runner accepted an evidence write failure"
  fi
  [ "$failures" -eq 1 ] || fail "evidence write failure was not counted"
  [ "${FINISH_GATE_STATUSES[0]}" -ne 0 ] || \
    fail "evidence write failure was recorded as pass"
)
```

- [ ] **Step 5: Adapt summary rendering to registry arrays**

Render Markdown groups by iterating registry order and selecting matching group.
Build the JSON `gates` array from registry IDs, integer statuses, and
`$run_dir/${FINISH_GATE_RESULT_NAMES[$index]}`. Keep `resource_envelope_status`
as the existing top-level field as well as its gate entry.

- [ ] **Step 6: Replace hard-coded gate execution in the entrypoint**

Source registry and runner, then use:

```bash
finish_init_gate_registry
finish_validate_gate_registry
finish_run_registered_gates "$mode" "$run_dir"
```

Remove scalar gate result-file and status variables after summary rendering no
longer consumes them. Preserve Git evidence, resource evaluation, overall
failure handling, messaging, and exit behavior.

- [ ] **Step 7: Update fixture copies, run green, and commit**

Copy both new modules into every manual finish fixture and assert they appear in
temporary installed targets.

Run: `bash validate-harness.sh`

Expected: exit 0 with unchanged gate order, summary contract, strict failures,
best-effort behavior, and resource-envelope behavior.

```bash
git add templates/scripts/lib/gate-registry.sh \
  templates/scripts/lib/finish-runner.sh templates/scripts/lib/finish-summary.sh \
  templates/scripts/agent-finish.sh tests/harness/finish-runtime-modules.sh \
  tests/harness/finish-examples.sh tests/harness/resource-envelope.sh \
  tests/harness/static-install.sh \
  docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md
git commit -m "refactor: centralize finish gate execution"
```

---

### Task 5: Complete Installed Parity And Stability Boundaries

**Files:**
- Modify: `tests/harness/static-install.sh`
- Modify: `tests/harness/template-sync.sh`
- Modify: `docs/stability-contract.md`
- Modify: `examples/universal-minimal-repo/scripts/` only if live parity checks prove it mirrors the full finish runtime
- Modify: `docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md`

**Interfaces:**
- Consumes: all four internal modules and public entrypoints from Tasks 2-4.
- Produces: explicit internal-library stability classification and installed-target proof.

- [ ] **Step 1: Write failing stability and parity assertions**

Add:

```bash
assert_contains "$repo_root/docs/stability-contract.md" \
  'scripts/lib/` files are internal implementation details'
assert_contains "$repo_root/docs/stability-contract.md" \
  'Downstream repositories should invoke public scripts rather than source internal libraries.'
```

In static install coverage, assert all four libraries exist under
`$target_root/scripts/lib/`. If the universal-minimal example contains the full
template `agent-finish.sh`, add byte-for-byte assertions for the public script
and its four internal libraries. If its finish script is intentionally minimal,
add an explicit assertion documenting that it is not a full installed-runtime
mirror and do not copy the production modules into that example.

- [ ] **Step 2: Run the red phase**

Run: `bash validate-harness.sh`

Expected: FAIL because the stability contract does not yet classify internal libraries.

- [ ] **Step 3: Document the stability boundary**

Add an `Internal Implementation Details` subsection to
`docs/stability-contract.md` containing exactly:

```markdown
## Internal Implementation Details

Files under `scripts/lib/` are internal implementation details. Downstream
repositories should invoke public scripts rather than source internal libraries.
Internal library functions may change within a minor release when the stable and
intended-stable public contracts remain compatible.
```

- [ ] **Step 4: Run source and installed-target verification**

Run:

```bash
git diff --check
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Then install into a temporary Git repository and run both modes:

```bash
target="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-core-runtime.XXXXXX")"
git -C "$target" init -q
bash install-agent-harness.sh --force "$target"
git -C "$target" add .
git -C "$target" -c user.name=Harness -c user.email=harness@example.invalid \
  commit -qm "Initialize harness"
(cd "$target" && bash scripts/agent-finish.sh --best-effort)
(cd "$target" && bash scripts/agent-finish.sh --strict)
```

Expected: document links and full validation exit 0. Both installed commands
produce a run directory and summary; strict may report task-configured gate
failure only if the installed default explicitly requires missing evidence. If
that occurs, inspect the default contract rather than weakening strict mode.

- [ ] **Step 5: Mark the plan complete and commit**

Record observed command results and commit SHAs under each completed task, then
mark checkboxes complete only after fresh verification.

```bash
git add docs/stability-contract.md tests/harness/static-install.sh \
  tests/harness/template-sync.sh examples/universal-minimal-repo \
  docs/superpowers/plans/2026-07-10-core-runtime-maintainability.md
git commit -m "chore: finalize core runtime maintainability rollout"
```

Do not stage `.agent/` and do not push without explicit authorization.
