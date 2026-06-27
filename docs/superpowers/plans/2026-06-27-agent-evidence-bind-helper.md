# Agent Evidence Bind Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `scripts/agent-evidence-bind.sh` so agents can bind finish-run artifacts into `.agent/acceptance.yml` without manually editing evidence paths.

**Architecture:** Ship a small Bash entrypoint in `templates/scripts/agent-evidence-bind.sh` that delegates YAML parsing and deterministic YAML rewriting to a stdlib-only Python helper embedded in the script. The helper updates an existing acceptance criterion, appends or replaces an `evidence_refs` entry, preserves unknown criterion fields, and verifies the result through the evidence refs validator introduced by the strict acceptance plan.

**Tech Stack:** POSIX-ish Bash, Python standard library, existing `templates/scripts/lib/read-yaml.py`, existing `templates/scripts/check-evidence-refs.py`, harness shell tests, Markdown docs.

---

## Source Coverage

This plan implements Capability 3 from:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

It depends on:

- `docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md`

## File Structure

Create:

- `templates/scripts/agent-evidence-bind.sh`: installed helper script that binds evidence refs into `.agent/acceptance.yml`.
- `tests/harness/evidence-bind.sh`: focused test suite for successful binding, missing run failures, missing gate failures, idempotency, replace mode, and strict acceptance compatibility.

Modify:

- `tests/harness/lib.sh`: add temporary roots used by `evidence-bind.sh`.
- `tests/harness/static-install.sh`: require `templates/scripts/agent-evidence-bind.sh` in source and installed targets.
- `validate-harness.sh`: add `tests/harness/evidence-bind.sh` to the validation suite.
- `README.md`: mention the helper in the Evidence Vs Handoff or evidence refs section.
- `README.zh-TW.md`: mirror the helper guidance.
- `docs/agent/gate-guide.md`: show when agents should use the helper.
- `templates/docs/agent/gate-guide.md`: installed mirror.

## Task 1: Add Failing Test Coverage And Install Contract

**Files:**
- Create: `tests/harness/evidence-bind.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `validate-harness.sh`

- [x] **Step 1: Add temporary roots**

In `tests/harness/lib.sh`, add these variables near the other acceptance-related fixture roots:

```bash
evidence_bind_success_root="$tmp_root/evidence-bind-success"
evidence_bind_missing_run_root="$tmp_root/evidence-bind-missing-run"
evidence_bind_missing_gate_root="$tmp_root/evidence-bind-missing-gate"
evidence_bind_idempotent_root="$tmp_root/evidence-bind-idempotent"
evidence_bind_replace_root="$tmp_root/evidence-bind-replace"
evidence_bind_strict_root="$tmp_root/evidence-bind-strict"
```

- [x] **Step 2: Add source and installed-path assertions**

In `tests/harness/static-install.sh`, add `templates/scripts/agent-evidence-bind.sh` beside the other template script assertions:

```bash
assert_file_exists "$repo_root/templates/scripts/agent-evidence-bind.sh"
```

Add the installed target assertion beside the installed script checks:

```bash
assert_file_exists "$target_root/scripts/agent-evidence-bind.sh"
```

- [x] **Step 3: Add the validation suite entry**

In `validate-harness.sh`, add the new suite after `tests/harness/acceptance-review.sh`:

```bash
run_test "evidence bind helper" bash tests/harness/evidence-bind.sh
```

- [x] **Step 4: Create the failing evidence-bind test suite**

Create `tests/harness/evidence-bind.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Evidence bind success =="
rm -rf "$evidence_bind_success_root"
mkdir -p "$evidence_bind_success_root/.agent/runs/20260627-091500" \
  "$evidence_bind_success_root/.agent" \
  "$evidence_bind_success_root/scripts/lib" \
  "$evidence_bind_success_root/scripts"
(
  cd "$evidence_bind_success_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  cp "$repo_root/templates/scripts/check-evidence-refs.py" scripts/check-evidence-refs.py
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  cat > .agent/runs/20260627-091500/finish-summary.json <<'JSON'
{
  "overall_result": "pass",
  "gates": {
    "agent-verify": {
      "result": "pass",
      "exit_status": 0,
      "path": ".agent/runs/20260627-091500/verify-result.txt"
    }
  }
}
JSON
  printf '%s\n' 'HARNESS_VERIFY_RESULT=pass' > .agent/runs/20260627-091500/verify-result.txt
  bash scripts/agent-evidence-bind.sh \
    --run .agent/runs/20260627-091500 \
    --acceptance .agent/acceptance.yml \
    --criterion AC-1 \
    --gate agent-verify > bind.log 2>&1
  assert_contains bind.log "AGENT_EVIDENCE_BIND_RESULT=pass"
  assert_contains .agent/acceptance.yml "evidence_refs:"
  assert_contains .agent/acceptance.yml "type: finish_summary_json"
  assert_contains .agent/acceptance.yml "path: .agent/runs/20260627-091500/finish-summary.json"
  python_bin="$(find_python)"
  "$python_bin" scripts/check-evidence-refs.py .agent/acceptance.yml > refs.log 2>&1
  assert_contains refs.log "EVIDENCE_REFS_RESULT=pass"
)
pass "evidence bind success"

echo
echo "== Evidence bind missing run fails =="
rm -rf "$evidence_bind_missing_run_root"
mkdir -p "$evidence_bind_missing_run_root/.agent" "$evidence_bind_missing_run_root/scripts"
(
  cd "$evidence_bind_missing_run_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  if bash scripts/agent-evidence-bind.sh --run .agent/runs/missing --criterion AC-1 > missing-run.log 2>&1; then
    echo "ERROR: expected missing run failure"
    exit 1
  fi
  assert_contains missing-run.log "FAIL: run directory not found"
  assert_contains missing-run.log "AGENT_EVIDENCE_BIND_RESULT=fail"
)
pass "evidence bind missing run fails"

echo
echo "== Evidence bind missing gate fails =="
rm -rf "$evidence_bind_missing_gate_root"
mkdir -p "$evidence_bind_missing_gate_root/.agent/runs/20260627-091501" \
  "$evidence_bind_missing_gate_root/.agent" \
  "$evidence_bind_missing_gate_root/scripts"
(
  cd "$evidence_bind_missing_gate_root"
  cp "$repo_root/templates/scripts/agent-evidence-bind.sh" scripts/agent-evidence-bind.sh
  chmod +x scripts/*.sh
  cat > .agent/acceptance.yml <<'YAML'
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Pending artifact binding."
YAML
  cat > .agent/runs/20260627-091501/finish-summary.json <<'JSON'
{"overall_result":"pass","gates":{"check-scope":{"result":"pass","exit_status":0}}}
JSON
  if bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091501 --criterion AC-1 --gate agent-verify > missing-gate.log 2>&1; then
    echo "ERROR: expected missing gate failure"
    exit 1
  fi
  assert_contains missing-gate.log "FAIL: gate not found: agent-verify"
  assert_contains missing-gate.log "AGENT_EVIDENCE_BIND_RESULT=fail"
)
pass "evidence bind missing gate fails"

echo
echo "== Evidence bind idempotent append =="
rm -rf "$evidence_bind_idempotent_root"
cp -R "$evidence_bind_success_root" "$evidence_bind_idempotent_root"
(
  cd "$evidence_bind_idempotent_root"
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > first.log 2>&1
  bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify > second.log 2>&1
  ref_count="$(grep -c 'type: finish_summary_json' .agent/acceptance.yml)"
  if [ "$ref_count" -ne 1 ]; then
    echo "ERROR: expected one finish_summary_json ref, found $ref_count"
    exit 1
  fi
)
pass "evidence bind idempotent append"
```

- [x] **Step 5: Run the new suite to verify it is red**

Run:

```bash
bash tests/harness/evidence-bind.sh
```

Expected: FAIL because `templates/scripts/agent-evidence-bind.sh` does not exist yet.

## Task 2: Implement `agent-evidence-bind.sh`

**Files:**
- Create: `templates/scripts/agent-evidence-bind.sh`

- [x] **Step 1: Add the helper script**

Create `templates/scripts/agent-evidence-bind.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-evidence-bind.sh [options]

Options:
  --run PATH
  --acceptance PATH
  --criterion ID
  --gate GATE_NAME
  --type TYPE
  --path PATH
  --overall-result pass|fail|warn
  --expected-exit-status N
  --must-contain TEXT
  --must-not-contain TEXT
  --replace
  --append
  --dry-run
  -h, --help

Defaults:
  --acceptance .agent/acceptance.yml
  --type finish_summary_json
  --overall-result pass
  --expected-exit-status from finish-summary.json gate when --run and --gate are provided, otherwise 0
  --append
EOF
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  echo "ERROR: python is required for evidence binding" >&2
  exit 1
}

run_path=""
acceptance_file=".agent/acceptance.yml"
criterion_id=""
gate_name=""
ref_type="finish_summary_json"
ref_path=""
overall_result="pass"
expected_exit_status=""
mode="append"
dry_run="false"
must_contain_args=()
must_not_contain_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run) run_path="${2:-}"; shift 2 ;;
    --acceptance) acceptance_file="${2:-}"; shift 2 ;;
    --criterion) criterion_id="${2:-}"; shift 2 ;;
    --gate) gate_name="${2:-}"; shift 2 ;;
    --type) ref_type="${2:-}"; shift 2 ;;
    --path) ref_path="${2:-}"; shift 2 ;;
    --overall-result) overall_result="${2:-}"; shift 2 ;;
    --expected-exit-status) expected_exit_status="${2:-}"; shift 2 ;;
    --must-contain) must_contain_args+=("${2:-}"); shift 2 ;;
    --must-not-contain) must_not_contain_args+=("${2:-}"); shift 2 ;;
    --replace) mode="replace"; shift ;;
    --append) mode="append"; shift ;;
    --dry-run) dry_run="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unsupported option: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$criterion_id" ]; then
  echo "FAIL: --criterion is required"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ ! -f "$acceptance_file" ]; then
  echo "FAIL: acceptance file not found: $acceptance_file"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ -n "$run_path" ]; then
  if [ ! -d "$run_path" ]; then
    echo "FAIL: run directory not found: $run_path"
    echo "AGENT_EVIDENCE_BIND_RESULT=fail"
    exit 1
  fi
  if [ -z "$ref_path" ]; then
    ref_path="$run_path/finish-summary.json"
  fi
fi
if [ -z "$ref_path" ]; then
  echo "FAIL: --path or --run is required"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ ! -f "$ref_path" ]; then
  echo "FAIL: evidence path not found: $ref_path"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi

python_bin="$(find_python)"
tmp_file="${acceptance_file}.tmp.$$"

set +e
"$python_bin" - "$acceptance_file" "$tmp_file" "$criterion_id" "$gate_name" "$ref_type" "$ref_path" "$overall_result" "$expected_exit_status" "$mode" "$dry_run" "${must_contain_args[@]}" -- "${must_not_contain_args[@]}" <<'PY'
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

acceptance_path = Path(sys.argv[1])
tmp_path = Path(sys.argv[2])
criterion_id = sys.argv[3]
gate_name = sys.argv[4]
ref_type = sys.argv[5]
ref_path = sys.argv[6]
overall_result = sys.argv[7]
expected_exit_status_arg = sys.argv[8]
mode = sys.argv[9]
dry_run = sys.argv[10] == "true"
rest = sys.argv[11:]
separator = rest.index("--")
must_contain = rest[:separator]
must_not_contain = rest[separator + 1:]

def fail(message):
    print(f"FAIL: {message}")
    print("AGENT_EVIDENCE_BIND_RESULT=fail")
    sys.exit(1)

def parse_scalar(value):
    value = value.strip()
    if value == "true":
        return True
    if value == "false":
        return False
    if value == "null":
        return None
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value

def load_minimal_acceptance(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    criteria = []
    current = None
    current_refs = None
    in_criteria = False
    in_refs = False
    current_ref = None
    for raw in lines:
        stripped = raw.strip()
        if stripped == "criteria:":
            in_criteria = True
            continue
        if not in_criteria:
            continue
        if raw.startswith("    - "):
            current = {}
            criteria.append(current)
            in_refs = False
            key, _, value = stripped[2:].partition(":")
            current[key.strip()] = parse_scalar(value)
            continue
        if current is None:
            continue
        if raw.startswith("      evidence_refs:"):
            current_refs = []
            current["evidence_refs"] = current_refs
            in_refs = True
            continue
        if in_refs and raw.startswith("        - "):
            current_ref = {}
            current_refs.append(current_ref)
            key, _, value = stripped[2:].partition(":")
            current_ref[key.strip()] = parse_scalar(value)
            continue
        if in_refs and raw.startswith("          ") and current_ref is not None:
            key, _, value = stripped.partition(":")
            current_ref[key.strip()] = parse_scalar(value)
            continue
        if raw.startswith("      "):
            key, _, value = stripped.partition(":")
            current[key.strip()] = parse_scalar(value)
            in_refs = False
    return criteria

criteria = load_minimal_acceptance(acceptance_path)
criterion = next((item for item in criteria if item.get("id") == criterion_id), None)
if criterion is None:
    fail(f"criterion not found: {criterion_id}")

expected_exit_status = 0 if expected_exit_status_arg == "" else int(expected_exit_status_arg)
if gate_name and ref_type == "finish_summary_json":
    try:
        summary = json.loads(Path(ref_path).read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"could not parse finish summary: {exc}")
    gates = summary.get("gates", {})
    gate = gates.get(gate_name)
    if not isinstance(gate, dict):
        fail(f"gate not found: {gate_name}")
    expected_exit_status = int(gate.get("exit_status", expected_exit_status))

new_ref = {
    "type": ref_type,
    "path": ref_path,
}
if gate_name:
    new_ref["gate"] = gate_name
new_ref["overall_result"] = overall_result
new_ref["expected_exit_status"] = expected_exit_status
if must_contain:
    new_ref["must_contain"] = must_contain
if must_not_contain:
    new_ref["must_not_contain"] = must_not_contain

existing_refs = criterion.get("evidence_refs")
if not isinstance(existing_refs, list):
    existing_refs = []
if mode == "replace":
    refs = [new_ref]
else:
    refs = list(existing_refs)
    if new_ref not in refs:
        refs.append(new_ref)
criterion["evidence_refs"] = refs

def quote(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if value is None:
        return "null"
    text = str(value)
    if text == "" or text.startswith("{") or text.startswith("[") or ": " in text:
        return json.dumps(text)
    return text

out = ["acceptance:", "  criteria:"]
for item in criteria:
    ordered_keys = ["id", "description", "met", "evidence", "verification"]
    first_key = "id" if "id" in item else next((key for key in item if key != "evidence_refs"), None)
    if first_key is None:
        continue
    out.append(f"    - {first_key}: {quote(item[first_key])}")
    for key in ordered_keys:
        if key == first_key or key not in item:
            continue
        out.append(f"      {key}: {quote(item[key])}")
    for key in item:
        if key in ordered_keys or key == "evidence_refs":
            continue
        out.append(f"      {key}: {quote(item[key])}")
    refs = item.get("evidence_refs")
    if refs:
        out.append("      evidence_refs:")
        for ref in refs:
            out.append(f"        - type: {quote(ref['type'])}")
            for key in ["path", "gate", "overall_result", "expected_exit_status"]:
                if key in ref:
                    out.append(f"          {key}: {quote(ref[key])}")
            for key in ["must_contain", "must_not_contain"]:
                values = ref.get(key)
                if values:
                    out.append(f"          {key}:")
                    for value in values:
                        out.append(f"            - {quote(value)}")

rendered = "\n".join(out) + "\n"
if dry_run:
    print(rendered, end="")
else:
    tmp_path.write_text(rendered, encoding="utf-8")
print("AGENT_EVIDENCE_BIND_RESULT=pass")
PY
status=$?
set -e

if [ "$status" -ne 0 ]; then
  rm -f "$tmp_file"
  exit "$status"
fi

if [ "$dry_run" = "false" ]; then
  mv "$tmp_file" "$acceptance_file"
else
  rm -f "$tmp_file"
fi
```

- [x] **Step 2: Make the helper executable**

Run:

```bash
chmod +x templates/scripts/agent-evidence-bind.sh
```

- [x] **Step 3: Run focused tests**

Run:

```bash
bash tests/harness/evidence-bind.sh
```

Expected: PASS.

## Task 3: Document The Helper

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/agent/gate-guide.md`
- Modify: `templates/docs/agent/gate-guide.md`

- [x] **Step 1: Add README guidance**

In `README.md`, add this paragraph near evidence refs guidance:

```markdown
When strict acceptance evidence is enabled, agents should use
`scripts/agent-evidence-bind.sh` to bind `.agent/runs/<timestamp>/`
artifacts into `.agent/acceptance.yml` instead of hand-editing run paths.
The helper updates an existing acceptance criterion and does not invent new
criteria.
```

- [x] **Step 2: Add Traditional Chinese README guidance**

In `README.zh-TW.md`, add the equivalent guidance:

```markdown
啟用嚴格 acceptance evidence 時，agent 應使用
`scripts/agent-evidence-bind.sh` 將 `.agent/runs/<timestamp>/` 成果綁定到
`.agent/acceptance.yml`，不要手動填寫 run path。此 helper 只更新既有
acceptance criterion，不會自動發明新的 criterion。
```

- [x] **Step 3: Add Gate Guide usage**

In both gate guide files, add this command example in the acceptance evidence section:

```bash
bash scripts/agent-evidence-bind.sh \
  --run .agent/runs/20260627-091500 \
  --acceptance .agent/acceptance.yml \
  --criterion AC-1 \
  --gate agent-verify
```

- [x] **Step 4: Run doc link checks**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
```

Expected: PASS.

## Task 4: Full Verification And Commit

**Files:**
- Modify: all files from Tasks 1-3.
- Modify: `docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md`

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
git add templates/scripts/agent-evidence-bind.sh tests/harness/evidence-bind.sh tests/harness/lib.sh tests/harness/static-install.sh validate-harness.sh README.md README.zh-TW.md docs/agent/gate-guide.md templates/docs/agent/gate-guide.md docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md
git commit -m "feat: add agent evidence bind helper"
```
