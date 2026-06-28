# Architecture Sensor Patterns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document and ship conservative architecture sensor examples that make architecture evidence more command-backed without claiming semantic correctness.

**Architecture:** Add one maintained template sensor script plus example packages showing how repo owners can wire sensor commands into `.agent/harness.yml` and reference their output from `.agent/architecture.yml`. Keep sensors opt-in examples, not universal gates.

**Tech Stack:** Python standard library, Bash, Markdown docs, existing architecture evidence schema, existing validation and doc-link tests.

---

## Source Coverage

This plan implements Capability 5 from:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

It depends on:

- `docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md`

## File Structure

Create:

- `docs/agent/architecture-sensors.md`: explains sensor pattern, limits, and integration.
- `templates/docs/agent/architecture-sensors.md`: installed mirror.
- `templates/scripts/check-import-boundaries.py`: configurable stdlib import-boundary sensor.
- `examples/architecture-sensors/import-boundary/README.md`: runnable example.
- `examples/architecture-sensors/import-boundary/.agent/harness.yml`: verification command wiring.
- `examples/architecture-sensors/import-boundary/.agent/architecture.yml`: architecture evidence with `evidence_refs`.
- `examples/architecture-sensors/import-boundary/src/app/cli.py`: passing sample source.
- `examples/architecture-sensors/import-boundary/tests/fixtures/sample.py`: forbidden fixture package.
- `tests/harness/architecture-sensors.sh`: test suite for the sensor and docs.

Modify:

- `tests/harness/lib.sh`: add temporary roots for architecture sensor tests.
- `tests/harness/static-install.sh`: require the optional sensor script and docs to install.
- `tests/harness/doc-consistency.sh`: assert source/template architecture sensor docs match.
- `validate-harness.sh`: add the sensor test suite.
- `README.md`: link architecture sensors.
- `README.zh-TW.md`: mirror the link.

## Task 1: Add Failing Sensor Tests

**Files:**
- Create: `tests/harness/architecture-sensors.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `validate-harness.sh`

- [x] **Step 1: Add temporary roots**

In `tests/harness/lib.sh`, add:

```bash
architecture_sensor_pass_root="$tmp_root/architecture-sensor-pass"
architecture_sensor_fail_root="$tmp_root/architecture-sensor-fail"
```

- [x] **Step 2: Add static install assertions**

In `tests/harness/static-install.sh`, add:

```bash
assert_file_exists "$repo_root/templates/scripts/check-import-boundaries.py"
assert_file_exists "$target_root/scripts/check-import-boundaries.py"
assert_file_exists "$target_root/docs/agent/architecture-sensors.md"
```

- [x] **Step 3: Add doc consistency assertion**

In `tests/harness/doc-consistency.sh`, add `architecture-sensors.md` to the source/template doc mirror checks, or add:

```bash
cmp docs/agent/architecture-sensors.md templates/docs/agent/architecture-sensors.md
```

- [x] **Step 4: Add validation suite entry**

In `validate-harness.sh`, add:

```bash
run_test "architecture sensor patterns" bash tests/harness/architecture-sensors.sh
```

- [x] **Step 5: Create focused sensor tests**

Create `tests/harness/architecture-sensors.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Import boundary sensor pass =="
rm -rf "$architecture_sensor_pass_root"
mkdir -p "$architecture_sensor_pass_root/src/app" "$architecture_sensor_pass_root/tests/fixtures" "$architecture_sensor_pass_root/scripts"
(
  cd "$architecture_sensor_pass_root"
  cp "$repo_root/templates/scripts/check-import-boundaries.py" scripts/check-import-boundaries.py
  cat > src/app/cli.py <<'PY'
from app.service import run
PY
  cat > src/app/service.py <<'PY'
def run():
    return "ok"
PY
  cat > tests/fixtures/sample.py <<'PY'
VALUE = "fixture"
PY
  python_bin="$(find_python)"
  "$python_bin" scripts/check-import-boundaries.py \
    --source src/app \
    --forbidden-import tests.fixtures \
    > sensor.log 2>&1
  assert_contains sensor.log "IMPORT_BOUNDARY_RESULT=pass"
)
pass "import boundary sensor pass"

echo
echo "== Import boundary sensor fail =="
rm -rf "$architecture_sensor_fail_root"
mkdir -p "$architecture_sensor_fail_root/src/app" "$architecture_sensor_fail_root/tests/fixtures" "$architecture_sensor_fail_root/scripts"
(
  cd "$architecture_sensor_fail_root"
  cp "$repo_root/templates/scripts/check-import-boundaries.py" scripts/check-import-boundaries.py
  cat > src/app/cli.py <<'PY'
from tests.fixtures.sample import VALUE
PY
  cat > tests/fixtures/sample.py <<'PY'
VALUE = "fixture"
PY
  python_bin="$(find_python)"
  if "$python_bin" scripts/check-import-boundaries.py --source src/app --forbidden-import tests.fixtures > sensor.log 2>&1; then
    echo "ERROR: expected import boundary failure"
    exit 1
  fi
  assert_contains sensor.log "FAIL: src/app/cli.py imports forbidden module tests.fixtures"
  assert_contains sensor.log "IMPORT_BOUNDARY_RESULT=fail"
)
pass "import boundary sensor fail"

echo
echo "== Architecture sensor example files =="
assert_file_exists "$repo_root/examples/architecture-sensors/import-boundary/README.md"
assert_file_exists "$repo_root/examples/architecture-sensors/import-boundary/.agent/harness.yml"
assert_file_exists "$repo_root/examples/architecture-sensors/import-boundary/.agent/architecture.yml"
assert_contains "$repo_root/examples/architecture-sensors/import-boundary/README.md" "IMPORT_BOUNDARY_RESULT=pass"
assert_contains "$repo_root/examples/architecture-sensors/import-boundary/.agent/architecture.yml" "evidence_refs:"
pass "architecture sensor example files"
```

- [x] **Step 6: Run the new suite to verify it is red**

Run:

```bash
bash tests/harness/architecture-sensors.sh
```

Expected: FAIL because `templates/scripts/check-import-boundaries.py` and examples do not exist yet.

## Task 2: Implement The Import Boundary Sensor

**Files:**
- Create: `templates/scripts/check-import-boundaries.py`

- [x] **Step 1: Add the sensor script**

Create `templates/scripts/check-import-boundaries.py`:

```python
#!/usr/bin/env python3
"""Check that Python files under a source path do not import forbidden modules."""

from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", action="append", required=True)
    parser.add_argument("--forbidden-import", action="append", required=True)
    return parser.parse_args()


def imported_names(path: Path) -> list[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    names: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.append(node.module)
    return names


def is_forbidden(name: str, forbidden: str) -> bool:
    return name == forbidden or name.startswith(f"{forbidden}.")


def main() -> int:
    args = parse_args()
    failures = 0
    forbidden = args.forbidden_import
    for source in args.source:
        root = Path(source)
        if not root.exists():
            print(f"FAIL: source path not found: {source}")
            failures += 1
            continue
        for path in sorted(root.rglob("*.py")):
            try:
                names = imported_names(path)
            except SyntaxError as exc:
                print(f"FAIL: could not parse {path}: {exc}")
                failures += 1
                continue
            for name in names:
                for blocked in forbidden:
                    if is_forbidden(name, blocked):
                        print(f"FAIL: {path} imports forbidden module {blocked}")
                        failures += 1
    if failures:
        print("IMPORT_BOUNDARY_RESULT=fail")
        return 1
    print("IMPORT_BOUNDARY_RESULT=pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [x] **Step 2: Make it executable**

Run:

```bash
chmod +x templates/scripts/check-import-boundaries.py
```

- [x] **Step 3: Run focused sensor tests**

Run:

```bash
bash tests/harness/architecture-sensors.sh
```

Expected: FAIL only because docs and examples are not created yet.

## Task 3: Add Sensor Documentation And Example

**Files:**
- Create: `docs/agent/architecture-sensors.md`
- Create: `templates/docs/agent/architecture-sensors.md`
- Create: `examples/architecture-sensors/import-boundary/README.md`
- Create: `examples/architecture-sensors/import-boundary/.agent/harness.yml`
- Create: `examples/architecture-sensors/import-boundary/.agent/architecture.yml`
- Create: `examples/architecture-sensors/import-boundary/src/app/cli.py`
- Create: `examples/architecture-sensors/import-boundary/src/app/service.py`
- Create: `examples/architecture-sensors/import-boundary/tests/fixtures/sample.py`
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [x] **Step 1: Add architecture sensor docs**

Create `docs/agent/architecture-sensors.md`:

````markdown
# Architecture Sensors

Architecture sensors are repo-owned commands that check narrow architecture
invariants and emit stable result markers. They strengthen architecture
evidence by tying an invariant to command output, but they do not guarantee
semantic correctness.

Use sensors for invariants that can be checked deterministically, such as:

- a package must not import test fixtures
- generated files must not be committed
- a public API file must keep expected exported names

## Harness Integration

Add the sensor command to `.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "import boundary"
      command: "python3 scripts/check-import-boundaries.py --source src/app --forbidden-import tests.fixtures"
```

Then reference the output from `.agent/architecture.yml`:

```yaml
architecture:
  status: upheld
  reviewer: "agent"
  invariants:
    - id: ARCH-IMPORT-1
      description: "Application code must not import test fixtures."
      status: upheld
      evidence_refs:
        - type: command_output
          path: ".agent/runs/20260627-091500/import-boundary.txt"
          must_contain:
            - "IMPORT_BOUNDARY_RESULT=pass"
```

## Boundary

Sensors are opt-in local checks. They do not provide sandboxing, provider-native
tracing, runtime enforcement, or semantic correctness guarantees.
````

- [x] **Step 2: Copy installed mirror**

Run:

```bash
cp docs/agent/architecture-sensors.md templates/docs/agent/architecture-sensors.md
```

- [x] **Step 3: Add import-boundary example files**

Create `examples/architecture-sensors/import-boundary/README.md`:

````markdown
# Import Boundary Architecture Sensor

## Scenario

Application code under `src/app` must not import test fixtures from
`tests.fixtures`.

## Harness Command

```bash
python3 scripts/check-import-boundaries.py \
  --source src/app \
  --forbidden-import tests.fixtures
```

Expected marker:

```text
IMPORT_BOUNDARY_RESULT=pass
```

## Architecture Evidence

`.agent/architecture.yml` references the command output with `evidence_refs`.
This proves the sensor command emitted the expected marker for the captured run.
It does not prove semantic correctness beyond that invariant.
````

Create `examples/architecture-sensors/import-boundary/.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "import boundary"
      command: "python3 scripts/check-import-boundaries.py --source src/app --forbidden-import tests.fixtures"
```

Create `examples/architecture-sensors/import-boundary/.agent/architecture.yml`:

```yaml
architecture:
  status: upheld
  reviewer: "agent"
  invariants:
    - id: ARCH-IMPORT-1
      description: "Application code must not import test fixtures."
      status: upheld
      evidence_refs:
        - type: command_output
          path: ".agent/runs/20260627-091500/import-boundary.txt"
          must_contain:
            - "IMPORT_BOUNDARY_RESULT=pass"
```

Create `examples/architecture-sensors/import-boundary/src/app/cli.py`:

```python
from app.service import run


if __name__ == "__main__":
    print(run())
```

Create `examples/architecture-sensors/import-boundary/src/app/service.py`:

```python
def run() -> str:
    return "ok"
```

Create `examples/architecture-sensors/import-boundary/tests/fixtures/sample.py`:

```python
VALUE = "fixture"
```

- [x] **Step 4: Link from README files**

Add this sentence to `README.md`:

```markdown
For command-backed architecture evidence patterns, see
[Architecture Sensors](docs/agent/architecture-sensors.md).
```

Add the Traditional Chinese equivalent to `README.zh-TW.md`.

- [x] **Step 5: Run focused tests and docs checks**

Run:

```bash
bash tests/harness/architecture-sensors.sh
bash tests/harness/doc-consistency.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: all commands pass.

## Task 4: Full Verification And Commit

**Files:**
- Modify: all files from Tasks 1-3.
- Modify: `docs/superpowers/plans/2026-06-27-architecture-sensor-patterns.md`

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
git add docs/agent/architecture-sensors.md templates/docs/agent/architecture-sensors.md templates/scripts/check-import-boundaries.py examples/architecture-sensors tests/harness/architecture-sensors.sh tests/harness/lib.sh tests/harness/static-install.sh tests/harness/doc-consistency.sh validate-harness.sh README.md README.zh-TW.md docs/superpowers/plans/2026-06-27-architecture-sensor-patterns.md
git commit -m "docs: add architecture sensor patterns"
```
