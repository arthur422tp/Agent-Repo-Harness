# Verification Config Multiline Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent repo-defined verification commands from being silently truncated when `.agent/harness.yml` uses YAML literal or folded multiline command values.

**Architecture:** Keep `scripts/lib/read-yaml.py` as the single parser, but stop using raw tab-separated rows for structured data that may contain newlines. Add a JSON-lines output mode for list fields and have `agent-verify.sh` decode each entry before running it. Preserve the existing human-readable `--list-fields` behavior for current callers unless the new JSON-lines mode is requested.

**Tech Stack:** POSIX-ish Bash, Python standard library, existing `validate-harness.sh` smoke fixtures.

---

## Root Cause

`templates/scripts/lib/read-yaml.py --list-fields name command` prints list item fields as tab-separated text. Literal YAML values can contain embedded newlines. `templates/scripts/agent-verify.sh` reads that output with `while IFS=$'\t' read -r label command_string`, so a multiline command is split into multiple shell input rows. Only the first physical line is associated with the label and executed; later lines are ignored. This creates a false positive where configured verification is skipped but `agent-verify.sh` reports success.

## Files

- Modify: `templates/scripts/lib/read-yaml.py`
- Modify: `templates/scripts/agent-verify.sh`
- Modify: `validate-harness.sh`
- Create: `tests/fixtures/validate-harness/verification-required-multiline.yml`

## Task 1: Add Failing Regression Coverage

- [ ] **Step 1: Create the multiline verification fixture**

Create `tests/fixtures/validate-harness/verification-required-multiline.yml`:

```yaml
verification:
  required:
    - name: multiline-check
      command: |
        printf '%s\n' first >> verification-output.txt
        printf '%s\n' second >> verification-output.txt
```

- [ ] **Step 2: Add the fixture to required repository files**

In `validate-harness.sh`, add this path to the `required_path` list:

```bash
tests/fixtures/validate-harness/verification-required-multiline.yml
```

- [ ] **Step 3: Add a failing smoke scenario**

In `validate-harness.sh`, after `== Repo-defined verification commands ==`, add:

```bash
echo
echo "== Repo-defined multiline verification command =="
verify_multiline_root="$tmp_root/verify-multiline-config"
mkdir -p "$verify_multiline_root/.agent"
git init -q "$verify_multiline_root"
(
  cd "$verify_multiline_root"
  copy_fixture verification-required-multiline.yml .agent/harness.yml
  mkdir -p scripts/lib
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  verify_log="$verify_multiline_root/agent-verify-multiline.log"
  bash "$repo_root/templates/scripts/agent-verify.sh" >"$verify_log" 2>&1
  assert_contains "$verify_log" "RUN: multiline-check"
  assert_contains "$verify_log" "PASS: multiline-check"
  assert_contains "$verify_log" "HARNESS_VERIFY_RESULT=pass"
  assert_contains "$verify_multiline_root/verification-output.txt" "first"
  assert_contains "$verify_multiline_root/verification-output.txt" "second"
)
pass "repo-defined multiline verification command"
```

- [ ] **Step 4: Run the regression and verify it fails**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `Repo-defined multiline verification command` because `verification-output.txt` contains `first` but not `second`.

## Task 2: Add a Safe Structured Output Mode

- [ ] **Step 1: Add `--list-fields-jsonl` to `read-yaml.py`**

In `templates/scripts/lib/read-yaml.py`, add an argparse option:

```python
parser.add_argument(
    "--list-fields-jsonl",
    nargs="+",
    metavar="FIELD",
    help="print selected fields from each list item as one JSON object per row",
)
```

- [ ] **Step 2: Implement JSON-lines list output**

Before the existing `if args.list_fields:` block, add:

```python
    if args.list_fields_jsonl:
        if not isinstance(value, list):
            print(f"ERROR: path is not a list: {args.path}", file=sys.stderr)
            return 1
        for item in value:
            if not isinstance(item, dict):
                print("ERROR: list item is not a map", file=sys.stderr)
                return 1
            output = {}
            for field in args.list_fields_jsonl:
                if field not in item:
                    print(f"ERROR: list item missing field: {field}", file=sys.stderr)
                    return 1
                field_value = item[field]
                if field_value is not None and not isinstance(
                    field_value, (str, int, float, bool)
                ):
                    print(
                        f"ERROR: list item field is not scalar: {field}",
                        file=sys.stderr,
                    )
                    return 1
                output[field] = field_value
            print(json.dumps(output, sort_keys=True))
        return 0
```

- [ ] **Step 3: Add a direct reader assertion in `validate-harness.sh`**

In the `== YAML reader behavior ==` section, after the existing tab-separated assertions, add:

```bash
  jsonl_log="$yaml_reader_root/read-yaml-jsonl.log"
  "$(find_python)" "$repo_root/templates/scripts/lib/read-yaml.py" \
    harness.yml verification.required --list-fields-jsonl name command \
    >"$jsonl_log" 2>&1
  assert_contains "$jsonl_log" '"name": "quoted check"'
  assert_contains "$jsonl_log" '"command": "bash -n scripts/check-policy.sh"'
```

- [ ] **Step 4: Run the targeted reader test**

Run:

```bash
bash validate-harness.sh
```

Expected: still FAIL at the multiline verification scenario until `agent-verify.sh` is updated, but no failure in the direct JSON-lines reader assertion.

## Task 3: Consume JSON Lines in Agent Verify

- [ ] **Step 1: Switch extraction to JSON lines**

In `templates/scripts/agent-verify.sh`, change:

```bash
"$python_bin" "$reader" "$config_file" verification.required \
  --optional --list-fields name command
```

to:

```bash
"$python_bin" "$reader" "$config_file" verification.required \
  --optional --list-fields-jsonl name command
```

- [ ] **Step 2: Decode each JSON line before execution**

Replace the `while IFS=$'\t' read -r label command_string; do ... done` block in `run_configured_verification_checks()` with:

```bash
  while IFS= read -r entry_json; do
    [ -n "${entry_json:-}" ] || continue

    if ! label="$(printf '%s\n' "$entry_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')"; then
      echo "FAIL: repo-defined verification config"
      echo "Reason: could not decode verification command name"
      failures=$((failures + 1))
      continue
    fi
    if ! command_string="$(printf '%s\n' "$entry_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["command"])')"; then
      echo "FAIL: repo-defined verification config"
      echo "Reason: could not decode verification command"
      failures=$((failures + 1))
      continue
    fi

    [ -n "${label:-}" ] || continue
    [ -n "${command_string:-}" ] || continue

    echo "COMMAND: $command_string"
    run_check "$label" bash -lc "$command_string"
  done <<EOF
$entries
EOF
```

- [ ] **Step 3: Avoid hard-coding `python3` in the decoder**

Before the loop, resolve Python once:

```bash
  local python_bin

  if ! python_bin="$(find_python)"; then
    echo "FAIL: repo-defined verification config"
    echo "Reason: python is required to decode verification commands"
    failures=$((failures + 1))
    return 0
  fi
```

Then use `"$python_bin" -c ...` in both decode calls.

- [ ] **Step 4: Run the regression and verify it passes**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS through `Repo-defined multiline verification command`; `verification-output.txt` contains both `first` and `second`.

## Task 4: Tighten Contract Documentation

- [ ] **Step 1: Update reader help/contract text**

In `templates/scripts/lib/read-yaml.py`, keep the docstring multiline support claim, and make the CLI distinction clear by adding help text only for JSON-lines structured consumption. Do not remove `--list-fields`; it remains useful for single-line human-oriented fields and existing tests.

- [ ] **Step 2: Add a short comment in `agent-verify.sh`**

Above the extraction command, add:

```bash
  # JSON lines preserve multiline command values; tab-separated rows do not.
```

- [ ] **Step 3: Update the optimization plan acceptance evidence if needed**

If this fix is part of the current Phase 1 PR, add one acceptance bullet to `docs/plans/agent-harness-optimization-plan.md`:

```markdown
- Multiline repo-defined verification commands are either preserved and run completely or rejected clearly.
```

## Task 5: Final Verification

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
bash -n templates/scripts/lib/read-yaml.py
bash -n templates/scripts/agent-verify.sh
bash -n validate-harness.sh
```

Expected: `bash -n templates/scripts/lib/read-yaml.py` is not valid because it is Python. Replace with:

```bash
python3 -m py_compile templates/scripts/lib/read-yaml.py
bash -n templates/scripts/agent-verify.sh
bash -n validate-harness.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Run full harness validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS with `PASS: validation completed`. Ruby-dependent syntax checks may warn if Ruby is unavailable.

- [ ] **Step 3: Review the diff**

Run:

```bash
git diff --stat
git diff -- templates/scripts/lib/read-yaml.py templates/scripts/agent-verify.sh validate-harness.sh tests/fixtures/validate-harness/verification-required-multiline.yml
```

Expected: Diff is limited to the JSON-lines output mode, `agent-verify.sh` consumption, regression fixture, validation scenario, and optional plan note.

## Non-Goals

- Do not add acceptance gates.
- Do not add review evidence gates.
- Do not integrate subagent finish evidence.
- Do not redesign policy approval.
- Do not restructure `docs/agent/`.
- Do not replace the YAML subset reader with PyYAML or another dependency.
