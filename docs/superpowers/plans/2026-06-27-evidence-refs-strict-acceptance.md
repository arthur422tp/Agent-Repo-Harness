# Evidence Refs Strict Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen acceptance evidence from text-only self-attestation to verifiable repo-local artifact references through `evidence_refs`, a stdlib validator, and opt-in strict acceptance mode.

**Architecture:** Keep the change inside the existing harness shape: `check-acceptance.sh` remains the acceptance gate, and it calls a new `check-evidence-refs.py` validator when structured references are present or strict mode is enabled. The validator uses the existing YAML subset reader plus Python standard library only, validates repo-relative artifact paths, and checks file content or `finish-summary.json` fields without adding a new top-level finish gate.

**Tech Stack:** POSIX-ish Bash, Python standard library, existing `templates/scripts/lib/read-yaml.py`, JSON Schema, existing `tests/harness/*.sh` validation suites, Markdown docs.

---

## Approved Source

Design source:

- `/Users/arthuryu/.codex/attachments/e542809c-8831-4d83-bf31-b186e1a2629b/pasted-text.txt`

MVP scope:

- Add `evidence_refs` schema and validation.
- Add opt-in strict acceptance evidence mode through `.agent/harness.yml`.
- Preserve backward-compatible text evidence by default.
- Keep `check-evidence-refs.py` as an acceptance helper, not a new finish gate.

Non-goals:

- Do not add external Python dependencies.
- Do not replace `scripts/lib/read-yaml.py` with PyYAML.
- Do not require `evidence_refs` by default for existing users.
- Do not change the public meaning of `agent-finish.sh`.
- Do not implement CI provider integrations, sandboxing, runtime interception, or semantic correctness guarantees.

## File Structure

Create:

- `schemas/evidence-ref.schema.json`: JSON schema for one evidence reference object.
- `templates/scripts/check-evidence-refs.py`: stdlib-only validator for `acceptance.criteria[*].evidence_refs`.

Modify:

- `schemas/acceptance.schema.json`: allow `evidence_refs` as an acceptance evidence source while preserving current text evidence compatibility.
- `schemas/harness.schema.json`: add optional `evidence.strict_refs` and `evidence.allow_text_only_evidence` config.
- `templates/.agent/harness.yml`: document default evidence config.
- `templates/scripts/check-acceptance.sh`: read harness evidence config and call `check-evidence-refs.py` when needed.
- `tests/harness/lib.sh`: add temporary fixture roots for strict evidence reference cases.
- `tests/harness/acceptance-review.sh`: cover default compatibility, strict failures, strict passes, invalid paths, JSON gate checks, and text content checks.
- `tests/harness/static-install.sh`: require the new schema and validator to ship into installed targets.
- `README.md`: document evidence references without overstating guarantees.
- `README.zh-TW.md`: mirror the same evidence reference guidance in Traditional Chinese.
- `docs/agent/gate-guide.md`: recommend `evidence_refs` for Standard and strict refs for High-Risk.
- `templates/docs/agent/gate-guide.md`: installed mirror of the gate guide.
- `docs/config-format.md`: state that `evidence_refs` uses the existing YAML subset only.

Do not modify:

- `templates/scripts/agent-finish.sh`, unless a test reveals it already assumes a hard-coded script inventory that must mention copied scripts. The MVP must not add a new `check-evidence-refs` finish gate row.

## Task 1: Schema And Config Contract

**Files:**
- Create: `schemas/evidence-ref.schema.json`
- Modify: `schemas/acceptance.schema.json`
- Modify: `schemas/harness.schema.json`
- Modify: `templates/.agent/harness.yml`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing install coverage for the new schema and validator**

In `tests/harness/static-install.sh`, add `schemas/evidence-ref.schema.json` to the source required-path list near the other schema entries:

```bash
schemas/evidence-ref.schema.json \
```

Add `templates/scripts/check-evidence-refs.py` to the template script required-path list near `templates/scripts/check-acceptance.sh`:

```bash
templates/scripts/check-evidence-refs.py \
```

Add installed target assertions near the current installed schema and script checks:

```bash
assert_file_exists "$target_root/schemas/evidence-ref.schema.json"
assert_file_exists "$target_root/scripts/check-evidence-refs.py"
```

- [x] **Step 2: Run validation to verify the contract is red**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `schemas/evidence-ref.schema.json` and `templates/scripts/check-evidence-refs.py` do not exist yet.

- [x] **Step 3: Add the evidence ref schema**

Create `schemas/evidence-ref.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agent-repo-harness.local/schemas/evidence-ref.schema.json",
  "title": "Agent-Repo-Harness evidence reference",
  "type": "object",
  "required": ["type", "path"],
  "properties": {
    "type": {
      "enum": [
        "command_output",
        "gate_result",
        "finish_summary_json",
        "changed_files",
        "diff_stat"
      ]
    },
    "path": { "type": "string", "pattern": "\\S" },
    "command": { "type": "string" },
    "gate": { "type": "string" },
    "expected_exit_status": {
      "type": "integer",
      "minimum": 0
    },
    "overall_result": {
      "enum": ["pass", "fail", "warn"]
    },
    "must_contain": {
      "type": "array",
      "items": { "type": "string" }
    },
    "must_not_contain": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "additionalProperties": false
}
```

- [x] **Step 4: Extend acceptance schema for `evidence_refs`**

In `schemas/acceptance.schema.json`, add this property inside each criterion's `properties` map:

```json
"evidence_refs": {
  "type": "array",
  "minItems": 1,
  "items": {
    "$ref": "evidence-ref.schema.json"
  }
}
```

Then extend the existing `anyOf` with a third branch:

```json
{
  "required": ["evidence_refs"],
  "properties": {
    "evidence_refs": {
      "type": "array",
      "minItems": 1
    }
  }
}
```

Keep `additionalProperties: true` for compatibility.

- [x] **Step 5: Extend harness schema for evidence config**

In `schemas/harness.schema.json`, add a top-level `evidence` property:

```json
"evidence": {
  "type": "object",
  "properties": {
    "strict_refs": { "type": "boolean", "default": false },
    "allow_text_only_evidence": { "type": "boolean", "default": true }
  },
  "additionalProperties": true
}
```

Keep top-level `"additionalProperties": true`.

- [x] **Step 6: Add default evidence config to the template harness config**

In `templates/.agent/harness.yml`, add this block after `verification:` and before `handoff:`:

```yaml
evidence:
  # strict_refs: true requires structured evidence_refs for required
  # acceptance evidence.
  strict_refs: false
  # allow_text_only_evidence: false rejects evidence/verification text as the
  # acceptance proof when strict refs are required. Text fields can still
  # explain the evidence for humans.
  allow_text_only_evidence: true
```

- [x] **Step 7: Run validation for schema/config contract**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL only because the validator and strict behavior are not implemented yet. No JSON syntax errors should appear.

- [ ] **Step 8: Commit the schema/config contract**

Status: Pending explicit commit authorization; schema/config contract implementation is complete and verified through the expected staged validation failure plus installed-target parity after adding the installer copy rule.

```bash
git add schemas/evidence-ref.schema.json schemas/acceptance.schema.json schemas/harness.schema.json templates/.agent/harness.yml tests/harness/static-install.sh
git commit -m "feat: add evidence ref schema contract"
```

## Task 2: Evidence Ref Validator

**Files:**
- Create: `templates/scripts/check-evidence-refs.py`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/acceptance-review.sh`

- [x] **Step 1: Add temporary fixture roots**

In `tests/harness/lib.sh`, near the existing acceptance roots, add:

```bash
acceptance_strict_text_only_root="$tmp_root/acceptance-strict-text-only"
acceptance_strict_finish_root="$tmp_root/acceptance-strict-finish"
acceptance_invalid_ref_path_root="$tmp_root/acceptance-invalid-ref-path"
acceptance_traversal_ref_root="$tmp_root/acceptance-traversal-ref"
acceptance_wrong_gate_root="$tmp_root/acceptance-wrong-gate"
acceptance_command_output_ref_root="$tmp_root/acceptance-command-output-ref"
acceptance_command_output_missing_root="$tmp_root/acceptance-command-output-missing"
```

- [x] **Step 2: Add direct validator tests for path and content behavior**

Append these cases before the review evidence section in `tests/harness/acceptance-review.sh`:

```bash
echo
echo "== Evidence refs command output valid =="
rm -rf "$acceptance_command_output_ref_root"
mkdir -p "$acceptance_command_output_ref_root/.agent/runs/20260627-091500" \
  "$acceptance_command_output_ref_root/scripts/lib"
(
  cd "$acceptance_command_output_ref_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'HARNESS_VERIFY_RESULT=pass' \
    'HARNESS_FAILURES=0' \
    > .agent/runs/20260627-091500/verify-result.txt
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: ".agent/runs/20260627-091500/verify-result.txt"' \
    '          must_contain:' \
    '            - "HARNESS_VERIFY_RESULT=pass"' \
    '          must_not_contain:' \
    '            - "FAIL:"' \
    > .agent/acceptance.yml
  evidence_refs_log="$acceptance_command_output_ref_root/evidence-refs.log"
  python3 "$repo_root/templates/scripts/check-evidence-refs.py" .agent/acceptance.yml >"$evidence_refs_log" 2>&1
  assert_contains "$evidence_refs_log" "== Evidence Refs Gate =="
  assert_contains "$evidence_refs_log" "OK: evidence ref acceptance.criteria[1].evidence_refs[1] path exists"
  assert_contains "$evidence_refs_log" "OK: command_output contains HARNESS_VERIFY_RESULT=pass"
  assert_contains "$evidence_refs_log" "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence refs command output valid"

echo
echo "== Evidence refs command output missing content failure =="
rm -rf "$acceptance_command_output_missing_root"
mkdir -p "$acceptance_command_output_missing_root/.agent/runs/20260627-091500" \
  "$acceptance_command_output_missing_root/scripts/lib"
(
  cd "$acceptance_command_output_missing_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'HARNESS_VERIFY_RESULT=fail' \
    > .agent/runs/20260627-091500/verify-result.txt
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: ".agent/runs/20260627-091500/verify-result.txt"' \
    '          must_contain:' \
    '            - "HARNESS_VERIFY_RESULT=pass"' \
    > .agent/acceptance.yml
  evidence_refs_log="$acceptance_command_output_missing_root/evidence-refs.log"
  if python3 "$repo_root/templates/scripts/check-evidence-refs.py" .agent/acceptance.yml >"$evidence_refs_log" 2>&1; then
    echo "ERROR: expected evidence refs failure for missing content"
    exit 1
  fi
  assert_contains "$evidence_refs_log" "missing required content"
  assert_contains "$evidence_refs_log" "EVIDENCE_REFS_RESULT=fail"
)
pass "evidence refs command output missing content failure"
```

- [x] **Step 3: Run validator tests to verify they fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/check-evidence-refs.py` does not exist.

- [x] **Step 4: Implement the validator**

Create `templates/scripts/check-evidence-refs.py`:

```python
#!/usr/bin/env python3
"""Validate Agent-Repo-Harness acceptance evidence references."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

SUPPORTED_TYPES = {
    "command_output",
    "gate_result",
    "finish_summary_json",
    "changed_files",
    "diff_stat",
}


def load_yaml_reader(script_path: Path):
    reader_path = script_path.parent / "lib" / "read-yaml.py"
    if not reader_path.is_file():
        raise RuntimeError(f"YAML reader not found: {reader_path}")
    spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def fail(failures: list[str], message: str) -> None:
    print(f"FAIL: {message}")
    failures.append(message)


def ensure_string_list(value: Any, label: str, failures: list[str]) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        fail(failures, f"{label} must be a list of strings")
        return []
    return value


def resolve_ref_path(repo_root: Path, raw_path: Any, label: str, failures: list[str]) -> Path | None:
    if not isinstance(raw_path, str) or raw_path.strip() == "":
        fail(failures, f"evidence ref {label} path must be non-empty")
        return None

    candidate = Path(raw_path)
    if candidate.is_absolute():
        fail(failures, f"evidence ref {label} path must be repo-relative: {raw_path}")
        return None
    if any(part == ".." for part in candidate.parts):
        fail(failures, f"evidence ref {label} path must not contain path traversal: {raw_path}")
        return None
    if candidate.parts and candidate.parts[0] == ".git":
        fail(failures, f"evidence ref {label} path must not point under .git: {raw_path}")
        return None

    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError:
        fail(failures, f"evidence ref {label} path escapes repo root: {raw_path}")
        return None

    if not resolved.exists():
        fail(failures, f"evidence ref {label} path does not exist: {raw_path}")
        return None
    if resolved.is_dir():
        fail(failures, f"evidence ref {label} path must be a file: {raw_path}")
        return None

    print(f"OK: evidence ref {label} path exists")
    return resolved


def validate_text_content(ref: dict[str, Any], path: Path, ref_type: str, failures: list[str]) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    for needle in ensure_string_list(ref.get("must_contain"), "must_contain", failures):
        if needle not in text:
            fail(failures, f"{ref_type} missing required content: {needle}")
        else:
            print(f"OK: {ref_type} contains {needle}")
    for needle in ensure_string_list(ref.get("must_not_contain"), "must_not_contain", failures):
        if needle in text:
            fail(failures, f"{ref_type} contains forbidden content: {needle}")
        else:
            print(f"OK: {ref_type} does not contain {needle}")


def validate_finish_summary(ref: dict[str, Any], path: Path, failures: list[str]) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except json.JSONDecodeError as exc:
        fail(failures, f"finish_summary_json is malformed JSON: {exc}")
        return

    expected_result = ref.get("overall_result")
    if expected_result is not None:
        actual_result = data.get("overall_result") if isinstance(data, dict) else None
        if actual_result != expected_result:
            fail(failures, f"finish_summary_json overall_result expected {expected_result} got {actual_result}")
        else:
            print(f"OK: finish_summary_json overall_result is {expected_result}")

    gate = ref.get("gate")
    expected_exit_status = ref.get("expected_exit_status")
    if gate is None and expected_exit_status is None:
        return
    if not isinstance(gate, str) or gate.strip() == "":
        fail(failures, "finish_summary_json gate must be non-empty when expected_exit_status is set")
        return
    if not isinstance(expected_exit_status, int):
        fail(failures, f"finish_summary_json expected_exit_status for gate {gate} must be an integer")
        return

    gates = data.get("gates") if isinstance(data, dict) else None
    if not isinstance(gates, list):
        fail(failures, "finish_summary_json gates must be a list")
        return

    for entry in gates:
        if isinstance(entry, dict) and entry.get("name") == gate:
            actual_status = entry.get("exit_status")
            if actual_status != expected_exit_status:
                fail(failures, f"finish_summary_json gate {gate} exit_status expected {expected_exit_status} got {actual_status}")
            else:
                print(f"OK: gate {gate} exit_status is {expected_exit_status}")
            return

    fail(failures, f"finish_summary_json gate {gate} is missing")


def iter_refs(data: Any):
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate acceptance evidence_refs.")
    parser.add_argument("acceptance_file", nargs="?", default=".agent/acceptance.yml")
    args = parser.parse_args()

    sys.dont_write_bytecode = True
    script_path = Path(__file__).resolve()
    acceptance_path = Path(args.acceptance_file)
    repo_root = Path.cwd().resolve()
    failures: list[str] = []

    print("== Evidence Refs Gate ==")
    print(f"File: {acceptance_path}")

    try:
        reader = load_yaml_reader(script_path)
        data = reader.load_yaml_subset(acceptance_path)
    except Exception as exc:
        print(f"FAIL: could not parse {acceptance_path}: {exc}")
        print("EVIDENCE_REFS_RESULT=fail")
        return 1

    found = False
    for label, ref in iter_refs(data):
        found = True
        if not isinstance(ref, dict):
            fail(failures, f"evidence ref {label} must be a map")
            continue
        ref_type = ref.get("type")
        if ref_type not in SUPPORTED_TYPES:
            fail(failures, f"evidence ref {label} type is unsupported: {ref_type}")
            continue
        path = resolve_ref_path(repo_root, ref.get("path"), label, failures)
        if path is None:
            continue
        if ref_type == "finish_summary_json":
            validate_finish_summary(ref, path, failures)
        validate_text_content(ref, path, ref_type, failures)

    if not found:
        fail(failures, "no evidence_refs entries found")

    if failures:
        print("EVIDENCE_REFS_RESULT=fail")
        return 1

    print("EVIDENCE_REFS_RESULT=pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [x] **Step 5: Make the validator executable**

Run:

```bash
chmod +x templates/scripts/check-evidence-refs.py
```

- [x] **Step 6: Run focused validator tests**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because acceptance strict mode has not been integrated yet, but the direct `check-evidence-refs.py` tests should pass.

- [ ] **Step 7: Commit validator implementation**

Status: Pending explicit commit authorization; direct evidence-ref validator tests pass. Full `bash validate-harness.sh` is currently blocked before acceptance-review by unrelated doc-link failures in `docs/superpowers/specs/2026-06-27-agent-facing-productization.md` for future `scripts/agent-task-profile.sh` and `scripts/agent-evidence-bind.sh` references.

```bash
git add templates/scripts/check-evidence-refs.py tests/harness/lib.sh tests/harness/acceptance-review.sh
git commit -m "feat: validate acceptance evidence refs"
```

## Task 3: Strict Acceptance Gate Integration

**Files:**
- Modify: `templates/scripts/check-acceptance.sh`
- Modify: `tests/harness/acceptance-review.sh`

- [x] **Step 1: Add backward compatibility and strict-mode acceptance tests**

Append these cases after the existing "Acceptance gate required complete" case in `tests/harness/acceptance-review.sh`:

```bash
echo
echo "== Acceptance gate default text evidence remains valid =="
rm -rf "$acceptance_pass_root-default-text"
mkdir -p "$acceptance_pass_root-default-text/.agent" "$acceptance_pass_root-default-text/scripts/lib"
(
  cd "$acceptance_pass_root-default-text"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Manual evidence is still accepted by default."' \
    '      met: true' \
    '      evidence: "Ran the verification gate."' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_pass_root-default-text/acceptance-default-text.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Acceptance check is required."
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance default text evidence remains valid"

echo
echo "== Acceptance gate strict refs reject text-only evidence =="
rm -rf "$acceptance_strict_text_only_root"
mkdir -p "$acceptance_strict_text_only_root/.agent" "$acceptance_strict_text_only_root/scripts/lib"
(
  cd "$acceptance_strict_text_only_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Text-only evidence is not enough."' \
    '      met: true' \
    '      evidence: "Manual check."' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_strict_text_only_root/acceptance-strict-text.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for text-only evidence"
    exit 1
  fi
  assert_contains "$acceptance_log" "Strict evidence refs are enabled."
  assert_contains "$acceptance_log" "requires evidence_refs because evidence.strict_refs is true"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs reject text-only evidence"
```

- [x] **Step 2: Add strict finish-summary success and failure tests**

Append:

```bash
echo
echo "== Acceptance gate strict refs pass with finish summary =="
rm -rf "$acceptance_strict_finish_root"
mkdir -p "$acceptance_strict_finish_root/.agent/runs/20260627-091500" \
  "$acceptance_strict_finish_root/scripts/lib"
(
  cd "$acceptance_strict_finish_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": [
    {
      "name": "agent-verify",
      "exit_status": 0,
      "evidence": ".agent/runs/20260627-091500/verify-result.txt"
    }
  ]
}
JSON
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/20260627-091500/finish-summary.json"' \
    '          overall_result: "pass"' \
    '          gate: "agent-verify"' \
    '          expected_exit_status: 0' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_strict_finish_root/acceptance-strict-finish.log"
  bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1
  assert_contains "$acceptance_log" "Strict evidence refs are enabled."
  assert_contains "$acceptance_log" "OK: finish_summary_json overall_result is pass"
  assert_contains "$acceptance_log" "OK: gate agent-verify exit_status is 0"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=pass"
)
pass "acceptance strict refs pass with finish summary"

echo
echo "== Acceptance gate strict refs wrong gate status failure =="
rm -rf "$acceptance_wrong_gate_root"
mkdir -p "$acceptance_wrong_gate_root/.agent/runs/20260627-091500" \
  "$acceptance_wrong_gate_root/scripts/lib"
(
  cd "$acceptance_wrong_gate_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": [
    {
      "name": "agent-verify",
      "exit_status": 1
    }
  ]
}
JSON
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Verification passed."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/20260627-091500/finish-summary.json"' \
    '          overall_result: "pass"' \
    '          gate: "agent-verify"' \
    '          expected_exit_status: 0' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_wrong_gate_root/acceptance-wrong-gate.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for wrong gate status"
    exit 1
  fi
  assert_contains "$acceptance_log" "gate agent-verify exit_status expected 0 got 1"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs wrong gate status failure"
```

- [x] **Step 3: Add invalid path tests**

Append:

```bash
echo
echo "== Acceptance gate strict refs missing path failure =="
rm -rf "$acceptance_invalid_ref_path_root"
mkdir -p "$acceptance_invalid_ref_path_root/.agent" "$acceptance_invalid_ref_path_root/scripts/lib"
(
  cd "$acceptance_invalid_ref_path_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Missing artifact fails."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: finish_summary_json' \
    '          path: ".agent/runs/missing/finish-summary.json"' \
    '          overall_result: "pass"' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_invalid_ref_path_root/acceptance-missing-path.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for missing evidence ref path"
    exit 1
  fi
  assert_contains "$acceptance_log" "path does not exist"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs missing path failure"

echo
echo "== Acceptance gate strict refs path traversal failure =="
rm -rf "$acceptance_traversal_ref_root"
mkdir -p "$acceptance_traversal_ref_root/.agent" "$acceptance_traversal_ref_root/scripts/lib"
(
  cd "$acceptance_traversal_ref_root"
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_acceptance_check: true' \
    > .agent/task.yml
  printf '%s\n' \
    'evidence:' \
    '  strict_refs: true' \
    '  allow_text_only_evidence: false' \
    > .agent/harness.yml
  printf '%s\n' \
    'acceptance:' \
    '  criteria:' \
    '    - id: "AC-1"' \
    '      description: "Traversal fails."' \
    '      met: true' \
    '      evidence_refs:' \
    '        - type: command_output' \
    '          path: "../secret.txt"' \
    > .agent/acceptance.yml
  acceptance_log="$acceptance_traversal_ref_root/acceptance-traversal.log"
  if bash "$repo_root/templates/scripts/check-acceptance.sh" >"$acceptance_log" 2>&1; then
    echo "ERROR: expected strict acceptance failure for path traversal"
    exit 1
  fi
  assert_contains "$acceptance_log" "path must not contain path traversal"
  assert_contains "$acceptance_log" "ACCEPTANCE_RESULT=fail"
)
pass "acceptance strict refs path traversal failure"
```

- [x] **Step 4: Run acceptance integration tests to verify they fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `check-acceptance.sh` does not yet read `.agent/harness.yml` or enforce strict refs.

- [x] **Step 5: Update `check-acceptance.sh` argument handling and config reads**

Change usage to:

```bash
Usage: check-acceptance.sh [TASK_FILE] [ACCEPTANCE_FILE] [HARNESS_FILE]

Defaults:
  TASK_FILE         .agent/task.yml
  ACCEPTANCE_FILE   .agent/acceptance.yml
  HARNESS_FILE      .agent/harness.yml
```

Add:

```bash
harness_file=".agent/harness.yml"
```

When positional args are supplied, set:

```bash
task_file="$1"
acceptance_file="${2:-$acceptance_file}"
harness_file="${3:-$harness_file}"
```

After `requires_acceptance` is confirmed true, read optional evidence config:

```bash
strict_refs="false"
allow_text_only_evidence="true"
if [ -f "$harness_file" ]; then
  strict_refs="$(read_optional_value "$harness_file" "evidence.strict_refs")"
  allow_text_only_evidence="$(read_optional_value "$harness_file" "evidence.allow_text_only_evidence")"
fi
if [ "$strict_refs" != "true" ]; then
  strict_refs="false"
fi
if [ "$allow_text_only_evidence" != "false" ]; then
  allow_text_only_evidence="true"
fi
if [ "$strict_refs" = "true" ]; then
  echo "Strict evidence refs are enabled."
fi
```

- [x] **Step 6: Update inline acceptance validation for strict refs**

Pass `strict_refs` and `allow_text_only_evidence` to the inline Python:

```bash
"$python_bin" - "$reader" "$acceptance_file" "$strict_refs" "$allow_text_only_evidence" <<'PY'
```

Inside the inline Python, read:

```python
strict_refs = sys.argv[3] == "true"
allow_text_only_evidence = sys.argv[4] != "false"
```

Add:

```python
def has_refs(value):
    return isinstance(value, list) and len(value) > 0
```

Replace the current evidence check with:

```python
has_text_evidence = (
    nonempty(criterion.get("evidence"))
    or nonempty(criterion.get("verification"))
)
has_evidence_refs = has_refs(criterion.get("evidence_refs"))

if strict_refs:
    if not has_evidence_refs:
        fail(f"{label} requires evidence_refs because evidence.strict_refs is true")
elif not has_text_evidence and not has_evidence_refs:
    fail(f"{label} evidence, verification, or evidence_refs must be non-empty")

if strict_refs and not allow_text_only_evidence and not has_evidence_refs:
    fail(f"{label} text-only evidence is disabled by evidence.allow_text_only_evidence")
```

Update the `OK` condition so strict criteria are considered complete only when `has_evidence_refs` is true. Non-strict criteria are complete when either text evidence or refs exist.

- [x] **Step 7: Call evidence refs validator from acceptance gate**

After the inline Python succeeds, run the evidence refs validator when strict mode is enabled. Also run it in default mode when refs exist by asking a small inline Python check:

```bash
refs_required="$strict_refs"
refs_present="$("$python_bin" - "$reader" "$acceptance_file" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True
reader_path = Path(sys.argv[1])
acceptance_path = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
data = module.load_yaml_subset(acceptance_path)
acceptance = data.get("acceptance") if isinstance(data, dict) else None
criteria = acceptance.get("criteria") if isinstance(acceptance, dict) else None
present = False
if isinstance(criteria, list):
    for criterion in criteria:
        if isinstance(criterion, dict) and isinstance(criterion.get("evidence_refs"), list):
            present = True
            break
print("true" if present else "false")
PY
)"

evidence_refs_script="$script_dir/check-evidence-refs.py"
if [ "$refs_required" = "true" ] || [ "$refs_present" = "true" ]; then
  if [ ! -f "$evidence_refs_script" ]; then
    echo "FAIL: evidence refs validator not found: $evidence_refs_script"
    echo "ACCEPTANCE_RESULT=fail"
    exit 1
  fi
  if ! "$python_bin" "$evidence_refs_script" "$acceptance_file"; then
    echo "ACCEPTANCE_RESULT=fail"
    exit 1
  fi
fi
```

Remove the unused `refs_present="$(read_optional_value ...)"` line if it was added during editing.

- [x] **Step 8: Run acceptance integration validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for all acceptance strict/default cases. If unrelated docs or template checks fail, fix only the files touched by this plan.

Status: Focused `tests/harness/acceptance-review.sh` validation passes for strict/default acceptance cases. Full `bash validate-harness.sh` and `bash templates/scripts/check-doc-links.sh .` are still blocked by unrelated missing script references in `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`.

- [ ] **Step 9: Commit strict acceptance integration**

Status: Pending explicit commit authorization.

```bash
git add templates/scripts/check-acceptance.sh tests/harness/acceptance-review.sh
git commit -m "feat: enforce strict acceptance evidence refs"
```

## Task 4: Documentation And Installed Template Guidance

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/agent/gate-guide.md`
- Modify: `templates/docs/agent/gate-guide.md`
- Modify: `docs/config-format.md`

- [ ] **Step 1: Add README evidence reference guidance**

In `README.md`, under the evidence or verification section, add:

````markdown
### Evidence References

For stricter completion evidence, projects may enable `evidence.strict_refs`
in `.agent/harness.yml`. When enabled, required acceptance criteria must
reference repo-local artifacts through `evidence_refs`, such as
`.agent/runs/<timestamp>/finish-summary.json` or gate output files.

The harness validates that referenced files exist and, when configured, contain
expected result markers or finish-summary gate statuses. `evidence_refs`
improves traceability; it does not prove semantic correctness beyond the
configured checks.

```yaml
# .agent/harness.yml
evidence:
  strict_refs: true
  allow_text_only_evidence: false
```

```yaml
# .agent/acceptance.yml
acceptance:
  criteria:
    - id: AC-1
      description: "The finish gate passed."
      met: true
      evidence_refs:
        - type: finish_summary_json
          path: ".agent/runs/20260627-091500/finish-summary.json"
          overall_result: "pass"
```
````

- [ ] **Step 2: Add Traditional Chinese README guidance**

In `README.zh-TW.md`, add the matching section:

```markdown
### Evidence References

如果任務需要更嚴格的完成證據，專案可以在 `.agent/harness.yml`
啟用 `evidence.strict_refs`。啟用後，必要的 acceptance criteria
必須透過 `evidence_refs` 指向 repo-local artifact，例如
`.agent/runs/<timestamp>/finish-summary.json` 或 gate output files。

Harness 會驗證引用的檔案存在，並在設定時檢查預期的結果 marker 或
finish-summary gate 狀態。`evidence_refs` 強化可追溯性；它不保證超出
設定檢查之外的語意正確性。
```

Include the same YAML examples from the English README.

- [ ] **Step 3: Update gate guide recommendations**

In `docs/agent/gate-guide.md`, update the Acceptance row failure/evidence text to mention `evidence_refs`:

```markdown
| Acceptance | `requires_acceptance_check` | false | explicit user-visible criteria must be proven | `.agent/acceptance.yml`; optional `evidence_refs`; `check-acceptance.sh` | criteria are unmet, lack evidence, or strict refs are invalid |
```

Add a short subsection after the matrix:

```markdown
## Evidence References

Text evidence is acceptable in low-risk/default mode. For Standard profile
tasks, prefer `evidence_refs` when the evidence already exists as a local
artifact such as `.agent/runs/<timestamp>/finish-summary.json` or a gate output
file. For High-Risk profile tasks, set `evidence.strict_refs: true` and
`evidence.allow_text_only_evidence: false` when acceptance proof should be tied
to verifiable repo-local artifacts.

`evidence_refs` strengthens traceability by checking file existence, optional
content markers, and selected finish-summary fields. It does not prove semantic
correctness beyond the configured checks.
```

Copy the updated file to `templates/docs/agent/gate-guide.md`:

```bash
cp docs/agent/gate-guide.md templates/docs/agent/gate-guide.md
```

- [ ] **Step 4: Update config format docs**

In `docs/config-format.md`, add:

```markdown
## Evidence References YAML Subset

`acceptance.criteria[*].evidence_refs` uses the existing harness YAML subset:
maps, lists, strings, integers, and booleans. It does not require a new parser
or external YAML dependency.

Supported MVP reference types are `command_output`, `gate_result`,
`finish_summary_json`, `changed_files`, and `diff_stat`. Paths must be
repo-relative files and must not point outside the repository or under `.git/`.
```

- [ ] **Step 5: Run doc link and harness validation**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: both PASS.

- [ ] **Step 6: Commit docs and template guidance**

```bash
git add README.md README.zh-TW.md docs/agent/gate-guide.md templates/docs/agent/gate-guide.md docs/config-format.md
git commit -m "docs: document strict evidence refs"
```

## Task 5: Final Verification And Handoff

**Files:**
- Modify: `handoff.md`
- Modify: this plan file

- [ ] **Step 1: Run final validation commands**

Run:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
bash templates/scripts/check-acceptance.sh --help
python3 templates/scripts/check-evidence-refs.py --help
```

Expected:

- `bash validate-harness.sh` exits 0.
- `bash templates/scripts/check-doc-links.sh .` exits 0.
- `check-acceptance.sh --help` prints usage including `[HARNESS_FILE]`.
- `check-evidence-refs.py --help` prints argparse help and exits 0.

- [ ] **Step 2: Confirm no accidental finish gate expansion**

Run:

```bash
rg -n "check-evidence-refs|evidence-refs-result|Evidence Refs Gate" templates/scripts/agent-finish.sh templates/scripts/check-acceptance.sh templates/scripts/check-evidence-refs.py
```

Expected:

- `templates/scripts/agent-finish.sh` has no matches.
- `templates/scripts/check-acceptance.sh` calls `check-evidence-refs.py`.
- `templates/scripts/check-evidence-refs.py` prints `== Evidence Refs Gate ==`.

- [ ] **Step 3: Update handoff**

Add an entry to `handoff.md` with:

```markdown
## Evidence Refs Strict Acceptance

- Added opt-in `evidence.strict_refs` and `evidence.allow_text_only_evidence`
  config for acceptance evidence.
- Added `templates/scripts/check-evidence-refs.py` to validate repo-local
  `evidence_refs` artifacts.
- Kept backward-compatible text evidence by default and did not add a new
  `agent-finish.sh` gate.
- Validation: `bash validate-harness.sh`; `bash templates/scripts/check-doc-links.sh .`;
  `bash templates/scripts/check-acceptance.sh --help`;
  `python3 templates/scripts/check-evidence-refs.py --help`.
```

- [ ] **Step 4: Mark this plan complete**

After the validation commands pass, update this plan's checkboxes from `[ ]` to `[x]` only for completed steps.

- [ ] **Step 5: Commit final handoff and plan status**

```bash
git add handoff.md docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md
git commit -m "docs: record evidence refs completion"
```

## Completion Criteria

The implementation is complete only when all of these are true:

- `schemas/evidence-ref.schema.json` exists and is shipped by the installer.
- `templates/scripts/check-evidence-refs.py` exists in installed template scripts.
- `check-acceptance.sh` supports strict evidence refs.
- Default acceptance evidence remains backward-compatible.
- Strict mode rejects text-only acceptance evidence when `allow_text_only_evidence: false`.
- Strict mode accepts valid `finish_summary_json` evidence refs.
- Invalid paths, path traversal, malformed JSON, missing gates, wrong gate statuses, and missing content markers fail.
- `README.md`, `README.zh-TW.md`, `docs/agent/gate-guide.md`, and `docs/config-format.md` document evidence refs without claiming semantic correctness.
- `bash validate-harness.sh` passes.
- `bash templates/scripts/check-doc-links.sh .` passes.
- No new external dependencies are introduced.
- `templates/scripts/agent-finish.sh` does not gain a new top-level evidence refs gate.

## Self-Review

Spec coverage:

- `evidence_refs` format and supported types are covered by Task 1 and Task 2.
- Repo-relative artifact validation is covered by Task 2 and Task 3.
- Strict acceptance mode is covered by Task 3.
- Backward-compatible default behavior is covered by Task 3.
- Documentation and guarantee boundaries are covered by Task 4.
- Final validation and no finish-gate expansion are covered by Task 5.

Placeholder scan:

- No task uses placeholder markers or open-ended "add appropriate" instructions.
- Code-changing steps include concrete snippets or complete file content.

Type consistency:

- Config keys are consistently `evidence.strict_refs` and `evidence.allow_text_only_evidence`.
- Acceptance refs are consistently `acceptance.criteria[*].evidence_refs`.
- Result markers remain `ACCEPTANCE_RESULT=pass|fail` and `EVIDENCE_REFS_RESULT=pass|fail`.
