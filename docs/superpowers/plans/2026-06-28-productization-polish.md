# Productization Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the agent-facing productization layer so finish, acceptance, architecture evidence, helper-script docs, and examples give Codex / Claude Code / generic AI coding agents deterministic completion signals.

**Architecture:** Keep this as a polish pass over existing Bash/Python/Markdown surfaces. The first and highest-priority commit fixes `check-acceptance.sh` so downstream agents can trust that each required acceptance run emits exactly one final `ACCEPTANCE_RESULT=pass|fail`; later commits clarify generator behavior, reuse the evidence refs validator for architecture evidence, add one concrete failed-run repair example, and classify helper CLIs in the stability contract.

**Tech Stack:** Bash, Python standard library, repo-local `templates/scripts/lib/read-yaml.py`, existing harness test scripts, Markdown docs, JSON fixture artifacts.

---

## Approved Source

Design source:

- `/Users/arthuryu/.codex/attachments/ed5b7bcc-ff4f-4cb5-b846-7f1d422619e3/pasted-text.txt`

Non-goals:

- Do not add external Python dependencies.
- Do not replace `templates/scripts/lib/read-yaml.py`.
- Do not add a runtime, MCP server, sandbox, or provider-native trace collector.
- Do not claim semantic correctness, runtime enforcement, sandboxing, or provider-native tracing.
- Do not change default strictness for existing users.
- Do not remove backward compatibility.
- Do not convert the project to a broad CLI framework.

## File Structure

Modify:

- `templates/scripts/check-acceptance.sh`: emit only one final `ACCEPTANCE_RESULT=pass|fail` after structure and refs checks finish.
- `tests/harness/acceptance-review.sh`: assert strict refs pass/fail and text-evidence pass runs never contain conflicting acceptance result markers.
- `templates/scripts/agent-task-profile.sh`: document rewrite semantics in help and warn before overwriting an existing output file.
- `tests/harness/task-profile.sh`: cover overwrite warning plus generated-task validation.
- `README.md`: document task-profile rewrite semantics and stability classification.
- `README.zh-TW.md`: mirror the English README changes.
- `docs/agent/gate-guide.md`: document `agent-task-profile.sh` rewrite semantics.
- `templates/docs/agent/gate-guide.md`: installed mirror of the gate-guide wording.
- `templates/scripts/check-evidence-refs.py`: add `--kind acceptance|architecture` support while preserving default acceptance behavior.
- `templates/scripts/check-architecture-evidence.sh`: validate architecture `evidence_refs` when architecture evidence is required and refs are present.
- `tests/harness/architecture-evidence.sh`: cover passing refs, missing marker, missing path, and no-ref compatibility.
- `tests/harness/productization-examples.sh`: require the failed-run repair example and helper-script stability docs.
- `docs/stability-contract.md`: classify new helper CLIs as intended-stable and add the compatibility note.
- `docs/public-packaging.md`: mention intended-stable helper CLIs in public packaging status.

Create:

- `examples/failed-run-repair/README.md`: concrete failure-to-repair walkthrough.
- `examples/failed-run-repair/.agent/task.yml`: task requiring acceptance evidence.
- `examples/failed-run-repair/.agent/harness.yml`: strict evidence refs configuration.
- `examples/failed-run-repair/.agent/acceptance.yml`: final acceptance with bound evidence refs.
- `examples/failed-run-repair/sample-run-failed/finish-summary.json`: failed finish evidence.
- `examples/failed-run-repair/sample-run-failed/acceptance-result.txt`: failed acceptance marker.
- `examples/failed-run-repair/sample-run-failed/verify-result.txt`: verification evidence.
- `examples/failed-run-repair/sample-run-passed/finish-summary.json`: passed finish evidence.
- `examples/failed-run-repair/sample-run-passed/acceptance-result.txt`: passed acceptance marker.
- `examples/failed-run-repair/sample-run-passed/verify-result.txt`: verification evidence.
- `examples/failed-run-repair/handoff.md`: handoff that references the final passed run.

## Task 1: Fix Acceptance Final Result Markers

**Commit:** `fix: emit one acceptance result marker`

**Files:**
- Modify: `templates/scripts/check-acceptance.sh`
- Modify: `tests/harness/acceptance-review.sh`

- [x] **Step 1: Add failing marker-count assertions**

In `tests/harness/acceptance-review.sh`, add this helper near the other local assertion helpers:

```bash
assert_single_acceptance_result() {
  local file="$1"
  local expected="$2"
  local count
  count="$(grep -c '^ACCEPTANCE_RESULT=' "$file" || true)"
  if [ "$count" != "1" ]; then
    echo "ERROR: expected exactly one ACCEPTANCE_RESULT marker in $file, found $count"
    cat "$file"
    exit 1
  fi
  assert_contains "$file" "ACCEPTANCE_RESULT=$expected"
  if [ "$expected" = "pass" ]; then
    assert_not_contains "$file" "ACCEPTANCE_RESULT=fail"
  else
    assert_not_contains "$file" "ACCEPTANCE_RESULT=pass"
  fi
}
```

Add or update three cases:

```bash
assert_single_acceptance_result acceptance.log pass
assert_single_acceptance_result acceptance.log fail
assert_single_acceptance_result acceptance.log pass
```

Use them respectively for:

- strict refs passing acceptance
- strict refs failing on missing marker or missing path
- default text evidence passing acceptance

- [x] **Step 2: Run the focused test and verify it is red**

Run:

```bash
bash tests/harness/acceptance-review.sh
```

Expected: FAIL on the strict refs failing case because one log can contain both `ACCEPTANCE_RESULT=pass` and `ACCEPTANCE_RESULT=fail`.

- [x] **Step 3: Change structure validation to emit an internal marker**

In `templates/scripts/check-acceptance.sh`, replace the embedded Python success marker:

```python
print("ACCEPTANCE_RESULT=pass")
```

with:

```python
print("ACCEPTANCE_STRUCTURE_RESULT=pass")
```

Keep Python failure paths printing:

```python
print("ACCEPTANCE_RESULT=fail")
```

- [x] **Step 4: Emit the final pass only after refs validation completes**

At the end of `templates/scripts/check-acceptance.sh`, after the `check-evidence-refs.py` block succeeds, add:

```bash
echo "ACCEPTANCE_RESULT=pass"
```

The end of the file should finish as:

```bash
if [ "$refs_required" = "true" ] || [ "$refs_present" = "true" ]; then
  if [ ! -f "$evidence_refs_script" ]; then
    echo "FAIL: evidence refs validator not found: $evidence_refs_script"
    echo "ACCEPTANCE_RESULT=fail"
    print_repair_hint
    exit 1
  fi
  if ! "$python_bin" "$evidence_refs_script" "$acceptance_file"; then
    echo "ACCEPTANCE_RESULT=fail"
    print_repair_hint
    exit 1
  fi
fi

echo "ACCEPTANCE_RESULT=pass"
exit 0
```

- [x] **Step 5: Run focused and full validation**

Run:

```bash
bash tests/harness/acceptance-review.sh
bash validate-harness.sh
```

Expected: both commands pass. Each required acceptance run contains exactly one `ACCEPTANCE_RESULT=pass|fail`.

- [x] **Step 6: Commit**

Run:

```bash
git add templates/scripts/check-acceptance.sh tests/harness/acceptance-review.sh
git commit -m "fix: emit one acceptance result marker"
```

## Task 2: Document And Warn On Task Profile Rewrites

**Commit:** `docs: clarify task profile rewrite behavior`

**Files:**
- Modify: `templates/scripts/agent-task-profile.sh`
- Modify: `tests/harness/task-profile.sh`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/agent/gate-guide.md`
- Modify: `templates/docs/agent/gate-guide.md`

- [x] **Step 1: Add failing overwrite-warning coverage**

In `tests/harness/task-profile.sh`, add:

```bash
echo
echo "== Existing task profile rewrite warns =="
setup_profile_root "$task_profile_rewrite_root"
(
  cd "$task_profile_rewrite_root"
  printf '%s\n' 'task:' '  custom_field: "preserve manually if needed"' > .agent/task.yml
  bash scripts/agent-task-profile.sh standard \
    --goal "Regenerate task." \
    --current-task "Use generated profile." \
    --allowed "templates/scripts/**" > rewrite.log 2>&1
  assert_contains rewrite.log "WARN: rewriting existing task file: .agent/task.yml"
  assert_contains rewrite.log "AGENT_TASK_PROFILE_RESULT=pass"
  bash scripts/validate-task.sh > validate.log 2>&1
  assert_contains validate.log "TASK_VALIDATION_RESULT=pass"
)
pass "existing task profile rewrite warns"
```

- [x] **Step 2: Run the focused test and verify it is red**

Run:

```bash
bash tests/harness/task-profile.sh
```

Expected: FAIL because the overwrite warning is not emitted yet.

- [x] **Step 3: Update help text**

In `templates/scripts/agent-task-profile.sh`, add this note to `usage()` after the options list:

```text
Note:
  This command rewrites the output task file. Use --dry-run before applying
  when preserving custom task fields matters.
```

- [x] **Step 4: Warn before overwriting an existing output file**

In `templates/scripts/agent-task-profile.sh`, before the non-dry-run write creates or overwrites `$output`, add:

```bash
if [ "$dry_run" != "true" ] && [ -f "$output" ]; then
  echo "WARN: rewriting existing task file: $output" >&2
fi
```

Keep existing generator behavior and `--dry-run` behavior unchanged.

- [x] **Step 5: Update docs in both languages and installed gate guide**

Add this exact English sentence to `README.md`, `docs/agent/gate-guide.md`, and `templates/docs/agent/gate-guide.md` near the first `agent-task-profile.sh` usage:

```text
`scripts/agent-task-profile.sh` rewrites the output task file. Use `--dry-run` before applying when preserving custom task fields matters.
```

Add the Traditional Chinese equivalent to `README.zh-TW.md` near the first `agent-task-profile.sh` usage:

```text
`scripts/agent-task-profile.sh` 會重寫輸出的 task 檔案；如果需要保留自訂欄位，套用前請先使用 `--dry-run` 檢查輸出。
```

- [x] **Step 6: Run focused and doc validation**

Run:

```bash
bash tests/harness/task-profile.sh
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: all commands pass.

- [x] **Step 7: Commit**

Run:

```bash
git add templates/scripts/agent-task-profile.sh tests/harness/task-profile.sh README.md README.zh-TW.md docs/agent/gate-guide.md templates/docs/agent/gate-guide.md
git commit -m "docs: clarify task profile rewrite behavior"
```

## Task 3: Validate Architecture Evidence Refs

**Commit:** `feat: validate architecture evidence refs`

**Files:**
- Modify: `templates/scripts/check-evidence-refs.py`
- Modify: `templates/scripts/check-architecture-evidence.sh`
- Modify: `tests/harness/architecture-evidence.sh`

- [x] **Step 1: Add failing architecture refs tests**

In `tests/harness/architecture-evidence.sh`, add cases after the valid architecture evidence case:

```bash
echo
echo "== Architecture evidence refs pass =="
architecture_refs_pass_root="$tmp_root/architecture-refs-pass"
rm -rf "$architecture_refs_pass_root"
mkdir -p "$architecture_refs_pass_root/.agent/runs/20260627-091500" "$architecture_refs_pass_root/scripts/lib"
(
  cd "$architecture_refs_pass_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'IMPORT_BOUNDARY_RESULT=pass' > .agent/runs/20260627-091500/import-boundary.txt
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  printf '%s\n' \
    'architecture:' \
    '  status: upheld' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "Import boundary sensor passed."' \
    '  invariants:' \
    '    - id: "ARCH-IMPORT-1"' \
    '      description: "Application code must not import test fixtures."' \
    '      status: upheld' \
    '      evidence: "See command output."' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: ".agent/runs/20260627-091500/import-boundary.txt"' \
    '          must_contain:' \
    '            - "IMPORT_BOUNDARY_RESULT=pass"' \
    > .agent/architecture.yml
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=pass"
  assert_contains architecture.log "EVIDENCE_REFS_RESULT=pass"
)
pass "architecture evidence refs pass"
```

Add two matching failure cases:

- same fixture but artifact content is `IMPORT_BOUNDARY_RESULT=fail`; expect `ARCHITECTURE_EVIDENCE_RESULT=fail` and `EVIDENCE_REFS_RESULT=fail`
- same fixture but the referenced path is missing; expect `ARCHITECTURE_EVIDENCE_RESULT=fail`

Keep the existing no-ref valid case unchanged so backward compatibility remains covered.

- [x] **Step 2: Run the focused test and verify it is red**

Run:

```bash
bash tests/harness/architecture-evidence.sh
```

Expected: FAIL because architecture refs are not validated yet and `check-evidence-refs.py` has no `--kind architecture` mode.

- [x] **Step 3: Add `--kind` support to the evidence refs validator**

In `templates/scripts/check-evidence-refs.py`, change the parser to:

```python
parser = argparse.ArgumentParser(description="Validate Agent-Repo-Harness evidence_refs.")
parser.add_argument("evidence_file", nargs="?", default=".agent/acceptance.yml")
parser.add_argument(
    "--kind",
    choices=("acceptance", "architecture"),
    default="acceptance",
    help="YAML shape to scan for evidence_refs.",
)
```

Rename local variables from `acceptance_path` to `evidence_path` where needed, and print:

```python
print(f"File: {evidence_path}")
print(f"Kind: {args.kind}")
```

- [x] **Step 4: Split ref iteration by kind**

Replace `iter_refs(data)` with:

```python
def iter_acceptance_refs(data: Any):
    acceptance = data.get("acceptance") if isinstance(data, dict) else None
    criteria = acceptance.get("criteria") if isinstance(acceptance, dict) else None
    if not isinstance(criteria, list):
        return
    for criterion_index, criterion in enumerate(criteria, 1):
        if not isinstance(criterion, dict):
            continue
        refs = criterion.get("evidence_refs")
        if not isinstance(refs, list):
            continue
        for ref_index, ref in enumerate(refs, 1):
            yield f"acceptance.criteria[{criterion_index}].evidence_refs[{ref_index}]", ref


def iter_architecture_refs(data: Any):
    architecture = data.get("architecture") if isinstance(data, dict) else None
    if not isinstance(architecture, dict):
        return
    refs = architecture.get("evidence_refs")
    if isinstance(refs, list):
        for ref_index, ref in enumerate(refs, 1):
            yield f"architecture.evidence_refs[{ref_index}]", ref
    invariants = architecture.get("invariants")
    if not isinstance(invariants, list):
        return
    for invariant_index, invariant in enumerate(invariants, 1):
        if not isinstance(invariant, dict):
            continue
        refs = invariant.get("evidence_refs")
        if not isinstance(refs, list):
            continue
        for ref_index, ref in enumerate(refs, 1):
            yield f"architecture.invariants[{invariant_index}].evidence_refs[{ref_index}]", ref
```

In `main()`, select:

```python
ref_iter = iter_architecture_refs(data) if args.kind == "architecture" else iter_acceptance_refs(data)
for label, ref in ref_iter:
    ...
```

Default behavior remains acceptance-compatible because `--kind` defaults to `acceptance`.

- [x] **Step 5: Detect architecture refs in the architecture gate**

In `templates/scripts/check-architecture-evidence.sh`, after structure validation succeeds and before final exit, compute whether refs exist:

```bash
refs_present="$("$python_bin" - "$reader" "$architecture_file" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True
reader_path = Path(sys.argv[1])
architecture_path = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
data = module.load_yaml_subset(architecture_path)
architecture = data.get("architecture") if isinstance(data, dict) else None
present = False
if isinstance(architecture, dict):
    if isinstance(architecture.get("evidence_refs"), list):
        present = True
    invariants = architecture.get("invariants")
    if isinstance(invariants, list):
        for invariant in invariants:
            if isinstance(invariant, dict) and isinstance(invariant.get("evidence_refs"), list):
                present = True
                break
print("true" if present else "false")
PY
)"
```

If refs are present, run:

```bash
evidence_refs_script="$script_dir/check-evidence-refs.py"
if [ "$refs_present" = "true" ]; then
  if [ ! -f "$evidence_refs_script" ]; then
    echo "FAIL: evidence refs validator not found: $evidence_refs_script"
    echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
    print_repair_hint
    exit 1
  fi
  if ! "$python_bin" "$evidence_refs_script" "$architecture_file" --kind architecture; then
    echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
    print_repair_hint
    exit 1
  fi
fi
```

- [x] **Step 6: Run focused and full validation**

Run:

```bash
bash tests/harness/architecture-evidence.sh
bash tests/harness/acceptance-review.sh
bash validate-harness.sh
```

Expected: all commands pass. Acceptance refs still work with the default validator invocation.

- [x] **Step 7: Commit**

Run:

```bash
git add templates/scripts/check-evidence-refs.py templates/scripts/check-architecture-evidence.sh tests/harness/architecture-evidence.sh
git commit -m "feat: validate architecture evidence refs"
```

## Task 4: Add Failed-Run Repair Example

**Commit:** `docs: add failed run repair example`

**Files:**
- Create: `examples/failed-run-repair/README.md`
- Create: `examples/failed-run-repair/.agent/task.yml`
- Create: `examples/failed-run-repair/.agent/harness.yml`
- Create: `examples/failed-run-repair/.agent/acceptance.yml`
- Create: `examples/failed-run-repair/sample-run-failed/finish-summary.json`
- Create: `examples/failed-run-repair/sample-run-failed/acceptance-result.txt`
- Create: `examples/failed-run-repair/sample-run-failed/verify-result.txt`
- Create: `examples/failed-run-repair/sample-run-passed/finish-summary.json`
- Create: `examples/failed-run-repair/sample-run-passed/acceptance-result.txt`
- Create: `examples/failed-run-repair/sample-run-passed/verify-result.txt`
- Create: `examples/failed-run-repair/handoff.md`
- Modify: `tests/harness/productization-examples.sh`

- [x] **Step 1: Add failing productization example assertions**

In `tests/harness/productization-examples.sh`, add `examples/failed-run-repair` to `required_examples`.

After the existing high-risk policy example assertions, add:

```bash
echo
echo "== Failed run repair example =="
assert_exists "$repo_root/examples/failed-run-repair/.agent/acceptance.yml"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/finish-summary.json"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/acceptance-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-failed/verify-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/finish-summary.json"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/acceptance-result.txt"
assert_exists "$repo_root/examples/failed-run-repair/sample-run-passed/verify-result.txt"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "Expected Failure"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "Repair Step"
assert_contains "$repo_root/examples/failed-run-repair/README.md" "Rerun"
assert_contains "$repo_root/examples/failed-run-repair/sample-run-failed/acceptance-result.txt" "ACCEPTANCE_RESULT=fail"
assert_contains "$repo_root/examples/failed-run-repair/sample-run-passed/acceptance-result.txt" "ACCEPTANCE_RESULT=pass"
```

- [x] **Step 2: Run the focused test and verify it is red**

Run:

```bash
bash tests/harness/productization-examples.sh
```

Expected: FAIL because `examples/failed-run-repair/` does not exist yet.

- [x] **Step 3: Create the example task and harness config**

Create `examples/failed-run-repair/.agent/task.yml`:

```yaml
task:
  status: "complete"
  goal: "Repair strict acceptance evidence after a failed finish run."
  current_task: "Bind command-backed acceptance evidence and rerun finish."
  source_plan: "examples/failed-run-repair/README.md"
  scope:
    allowed_paths:
      - "examples/failed-run-repair/**"
    forbidden_paths: []
  completion:
    requires_tdd_evidence: false
    requires_acceptance_check: true
    requires_review_evidence: false
    requires_architecture_evidence: false
    requires_failure_attribution: false
    requires_intervention_record: false
    requires_command_ledger: false
    requires_sandbox_verification: false
    requires_subagent_evidence: false
```

Create `examples/failed-run-repair/.agent/harness.yml`:

```yaml
verification:
  commands:
    - "bash scripts/agent-verify.sh"
evidence:
  strict_refs: true
  allow_text_only_evidence: false
handoff:
  require_summary: true
```

- [x] **Step 4: Create final acceptance evidence with bound refs**

Create `examples/failed-run-repair/.agent/acceptance.yml`:

```yaml
acceptance:
  criteria:
    - id: "strict-acceptance-repaired"
      description: "Strict acceptance evidence is backed by a passing command artifact."
      met: true
      evidence_refs:
        - type: command_output
          path: "examples/failed-run-repair/sample-run-passed/acceptance-result.txt"
          must_contain:
            - "ACCEPTANCE_RESULT=pass"
        - type: finish_summary_json
          path: "examples/failed-run-repair/sample-run-passed/finish-summary.json"
          overall_result: pass
```

- [x] **Step 5: Create failed and passed sample artifacts**

Create `examples/failed-run-repair/sample-run-failed/acceptance-result.txt`:

```text
== Acceptance Gate ==
Acceptance check is required.
Strict evidence refs are enabled.
FAIL: criterion strict-acceptance-repaired requires evidence_refs because evidence.strict_refs is true
ACCEPTANCE_RESULT=fail
```

Create `examples/failed-run-repair/sample-run-failed/verify-result.txt`:

```text
== Verify Gate ==
VERIFY_RESULT=pass
```

Create `examples/failed-run-repair/sample-run-failed/finish-summary.json`:

```json
{
  "overall_result": "fail",
  "gates": [
    { "name": "verify", "exit_status": 0, "result": "pass" },
    { "name": "acceptance", "exit_status": 1, "result": "fail" }
  ]
}
```

Create `examples/failed-run-repair/sample-run-passed/acceptance-result.txt`:

```text
== Acceptance Gate ==
Acceptance check is required.
Strict evidence refs are enabled.
ACCEPTANCE_STRUCTURE_RESULT=pass
EVIDENCE_REFS_RESULT=pass
ACCEPTANCE_RESULT=pass
```

Create `examples/failed-run-repair/sample-run-passed/verify-result.txt`:

```text
== Verify Gate ==
VERIFY_RESULT=pass
```

Create `examples/failed-run-repair/sample-run-passed/finish-summary.json`:

```json
{
  "overall_result": "pass",
  "gates": [
    { "name": "verify", "exit_status": 0, "result": "pass" },
    { "name": "acceptance", "exit_status": 0, "result": "pass" }
  ]
}
```

- [x] **Step 6: Write the repair walkthrough**

Create `examples/failed-run-repair/README.md` with exactly these headings:

````markdown
# Failed Run Repair

## Scenario

A strict acceptance run failed because the criterion had text but no structured artifact reference. The agent may not claim completion from the failed finish summary.

## Initial Task

Repair strict acceptance evidence for a completed docs-only change.

## Profile Selected

Standard profile with `requires_acceptance_check: true` and `evidence.strict_refs: true`.

## Commands Run

```bash
bash scripts/agent-finish.sh
bash scripts/check-acceptance.sh
bash scripts/agent-evidence-bind.sh --acceptance .agent/acceptance.yml --criterion strict-acceptance-repaired --type command_output --path examples/failed-run-repair/sample-run-passed/acceptance-result.txt --must-contain ACCEPTANCE_RESULT=pass
bash scripts/check-acceptance.sh
bash scripts/agent-finish.sh
```

## Expected Failure

The first finish run fails because strict acceptance requires `evidence_refs`.

## Failure Evidence

`sample-run-failed/acceptance-result.txt` contains `ACCEPTANCE_RESULT=fail`.

## Repair Step

The agent inspects the failed acceptance result, binds command-backed evidence with `scripts/agent-evidence-bind.sh`, and records the final artifact path in `.agent/acceptance.yml`.

## Rerun

The agent reruns `scripts/check-acceptance.sh` and then `scripts/agent-finish.sh`.

## Final Finish Result

`sample-run-passed/finish-summary.json` records `overall_result: pass`, and `sample-run-passed/acceptance-result.txt` contains `ACCEPTANCE_RESULT=pass`.

## What The Agent May Claim

The agent may claim the strict acceptance evidence was repaired after the passed rerun.

## What The Agent Must Not Claim

The agent must not claim the original failed finish run completed the task, and must not claim semantic correctness beyond the recorded harness checks.
````

- [x] **Step 7: Write the example handoff**

Create `examples/failed-run-repair/handoff.md`:

```markdown
# Handoff

Final passed run: `examples/failed-run-repair/sample-run-passed/finish-summary.json`

The strict acceptance failure was repaired by binding command-backed evidence and rerunning acceptance plus finish. The earlier failed run remains in `examples/failed-run-repair/sample-run-failed/` as audit evidence.
```

- [x] **Step 8: Run focused and full validation**

Run:

```bash
bash tests/harness/productization-examples.sh
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: all commands pass.

- [x] **Step 9: Commit**

Run:

```bash
git add examples/failed-run-repair tests/harness/productization-examples.sh
git commit -m "docs: add failed run repair example"
```

## Task 5: Classify Helper Scripts In Stability Contract

**Commit:** `docs: classify agent helper stability`

**Files:**
- Modify: `docs/stability-contract.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/public-packaging.md`
- Modify: `tests/harness/productization-examples.sh`

- [ ] **Step 1: Add failing stability assertions**

In `tests/harness/productization-examples.sh`, extend the stability contract assertions:

```bash
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-evidence-bind.sh"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/check-evidence-refs.py"
assert_contains "$repo_root/docs/stability-contract.md" "Agent-facing helper scripts are intended-stable in v0.x."
```

- [ ] **Step 2: Run the focused test and verify it is red**

Run:

```bash
bash tests/harness/productization-examples.sh
```

Expected: FAIL until `docs/stability-contract.md` names the helper scripts and compatibility note.

- [ ] **Step 3: Update stability contract**

In `docs/stability-contract.md`, under `## Intended-Stable Interfaces`, add:

```markdown
- `scripts/agent-task-profile.sh` CLI
- `scripts/agent-evidence-bind.sh` CLI
- `scripts/check-evidence-refs.py` CLI
```

Add this compatibility paragraph near the deprecation policy:

```markdown
Agent-facing helper scripts are intended-stable in v0.x. Patch versions should not intentionally break their basic invocation forms. Minor versions may add options. Breaking changes require deprecation warnings before removal when feasible.
```

- [ ] **Step 4: Update public docs**

In `docs/public-packaging.md`, add a release-readiness bullet:

```markdown
- [x] Agent-facing helper CLIs (`scripts/agent-task-profile.sh`, `scripts/agent-evidence-bind.sh`, and `scripts/check-evidence-refs.py`) are classified as intended-stable v0.x interfaces.
```

In `README.md`, add:

```markdown
Agent-facing helper CLIs such as `scripts/agent-task-profile.sh`, `scripts/agent-evidence-bind.sh`, and `scripts/check-evidence-refs.py` are intended-stable v0.x interfaces; see [docs/stability-contract.md](docs/stability-contract.md).
```

In `README.zh-TW.md`, add:

```markdown
面向 agent 的 helper CLI，例如 `scripts/agent-task-profile.sh`、`scripts/agent-evidence-bind.sh` 與 `scripts/check-evidence-refs.py`，屬於 v0.x intended-stable 介面；請見 [docs/stability-contract.md](docs/stability-contract.md)。
```

- [ ] **Step 5: Run focused and doc validation**

Run:

```bash
bash tests/harness/productization-examples.sh
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: all commands pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add docs/stability-contract.md README.md README.zh-TW.md docs/public-packaging.md tests/harness/productization-examples.sh
git commit -m "docs: classify agent helper stability"
```

## Task 6: Final Validation Wiring And Closeout

**Commit:** `test: verify productization polish wiring`

**Files:**
- Modify: `validate-harness.sh` only if a new test file was created.
- Modify: `docs/superpowers/plans/2026-06-28-productization-polish.md`
- Modify: `handoff.md` if this plan is being executed to completion in this checkout.

- [ ] **Step 1: Confirm validation wiring includes existing suites**

Run:

```bash
grep -E 'tests/harness/(acceptance-review|evidence-bind|task-profile|architecture-evidence|architecture-sensors|productization-examples)\.sh' validate-harness.sh
```

Expected: every listed suite appears in `validate-harness.sh`.

- [ ] **Step 2: Add wiring only if a new test file was introduced**

If implementation added a new harness test file instead of extending existing suites, add it to `validate-harness.sh` next to related `tests/harness/*.sh` entries.

If no new test file was added, leave `validate-harness.sh` unchanged.

- [ ] **Step 3: Run targeted final checks**

Run:

```bash
bash tests/harness/acceptance-review.sh
bash tests/harness/evidence-bind.sh
bash tests/harness/task-profile.sh
bash tests/harness/architecture-evidence.sh
bash tests/harness/productization-examples.sh
```

Expected: all targeted checks pass.

- [ ] **Step 4: Run full final validation**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: both commands pass.

- [ ] **Step 5: Confirm completion criteria**

Run:

```bash
git grep -n 'ACCEPTANCE_RESULT=pass' templates/scripts/check-acceptance.sh tests/harness/acceptance-review.sh
git grep -n 'agent-task-profile.sh.*rewrites\|rewrites the output task file' README.md docs/agent/gate-guide.md templates/docs/agent/gate-guide.md
git grep -n 'agent-task-profile.sh\|agent-evidence-bind.sh\|check-evidence-refs.py' docs/stability-contract.md
test -s examples/failed-run-repair/sample-run-passed/finish-summary.json
```

Expected: commands exit `0` and point to the implemented acceptance marker, rewrite docs, stability entries, and failed-run repair example.

- [ ] **Step 6: Update this plan status after successful implementation**

If executing the plan, update completed task checkboxes from `- [ ]` to `- [x]` only after the corresponding commit exists and the required validation passed.

- [ ] **Step 7: Commit closeout metadata if changed**

Run only if `validate-harness.sh`, this plan file, or `handoff.md` changed during closeout:

```bash
git add validate-harness.sh docs/superpowers/plans/2026-06-28-productization-polish.md handoff.md
git commit -m "test: verify productization polish wiring"
```

## Completion Criteria

This plan is complete only when:

1. `templates/scripts/check-acceptance.sh` emits exactly one final `ACCEPTANCE_RESULT=pass|fail` per required run.
2. Strict evidence refs failures no longer produce both pass and fail acceptance markers.
3. `templates/scripts/agent-task-profile.sh` documents that it rewrites the output task file.
4. Existing task profile behavior remains backward-compatible, including `--dry-run`.
5. Architecture evidence validates `evidence_refs` when present.
6. Architecture evidence without refs remains valid by default.
7. `examples/failed-run-repair/` exists and is validated.
8. `docs/stability-contract.md` classifies the new agent-facing helper scripts.
9. `README.md`, `README.zh-TW.md`, gate-guide docs, and public packaging docs remain consistent.
10. `bash validate-harness.sh` passes.
11. No external dependencies are introduced.
12. The project still avoids claiming sandboxing, runtime enforcement, provider-native tracing, or semantic correctness guarantees.
