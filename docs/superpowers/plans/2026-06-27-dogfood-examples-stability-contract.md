# Dogfood Examples And Stability Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add concrete agent workflow examples and a public stability contract so external users know which interfaces are reliable and which remain experimental.

**Architecture:** Ship at least three examples in the first PR using static sample-run evidence, then document stable and experimental interfaces in `docs/stability-contract.md`. Keep all examples honest: they show workflow traces and allowed claims, but they do not imply sandboxing, provider-native tracing, or semantic correctness guarantees.

**Tech Stack:** Markdown docs, static YAML/JSON examples, existing doc-link checks, existing harness validation suites.

---

## Source Coverage

This plan implements Capabilities 6 and 7 from:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

It should run after:

- `docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md`
- `docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md`
- `docs/superpowers/plans/2026-06-27-agent-task-profile-helper.md`
- `docs/superpowers/plans/2026-06-27-failed-run-repair-protocol.md`

## File Structure

Create:

- `docs/stability-contract.md`: stable, intended-stable, experimental, compatibility, and deprecation contract.
- `examples/docs-only-change/README.md`
- `examples/docs-only-change/.agent/task.yml`
- `examples/docs-only-change/.agent/harness.yml`
- `examples/docs-only-change/sample-run/finish-summary.json`
- `examples/docs-only-change/sample-run/verify-result.txt`
- `examples/docs-only-change/handoff.md`
- `examples/bugfix-with-evidence-refs/README.md`
- `examples/bugfix-with-evidence-refs/.agent/task.yml`
- `examples/bugfix-with-evidence-refs/.agent/harness.yml`
- `examples/bugfix-with-evidence-refs/.agent/acceptance.yml`
- `examples/bugfix-with-evidence-refs/sample-run/finish-summary.json`
- `examples/bugfix-with-evidence-refs/sample-run/verify-result.txt`
- `examples/bugfix-with-evidence-refs/handoff.md`
- `examples/high-risk-policy-change/README.md`
- `examples/high-risk-policy-change/.agent/task.yml`
- `examples/high-risk-policy-change/.agent/harness.yml`
- `examples/high-risk-policy-change/.agent/policy.yml`
- `examples/high-risk-policy-change/sample-run/finish-summary.json`
- `examples/high-risk-policy-change/sample-run/verify-result.txt`
- `examples/high-risk-policy-change/sample-run/policy-result.txt`
- `examples/high-risk-policy-change/handoff.md`
- `tests/harness/productization-examples.sh`: verifies required example files and stability contract markers.

Modify:

- `README.md`: link examples and stability contract.
- `README.zh-TW.md`: mirror links.
- `docs/public-packaging.md`: reference the stability contract.
- `validate-harness.sh`: add the productization examples suite.

## Task 1: Add Failing Example And Stability Tests

**Files:**
- Create: `tests/harness/productization-examples.sh`
- Modify: `validate-harness.sh`

- [ ] **Step 1: Add validation suite entry**

In `validate-harness.sh`, add:

```bash
run_test "productization examples" bash tests/harness/productization-examples.sh
```

- [ ] **Step 2: Create the productization examples test suite**

Create `tests/harness/productization-examples.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

required_examples="
examples/docs-only-change
examples/bugfix-with-evidence-refs
examples/high-risk-policy-change
"

for example in $required_examples; do
  echo "== Example: $example =="
  assert_file_exists "$repo_root/$example/README.md"
  assert_file_exists "$repo_root/$example/.agent/task.yml"
  assert_file_exists "$repo_root/$example/.agent/harness.yml"
  assert_file_exists "$repo_root/$example/sample-run/finish-summary.json"
  assert_file_exists "$repo_root/$example/sample-run/verify-result.txt"
  assert_file_exists "$repo_root/$example/handoff.md"
  assert_contains "$repo_root/$example/README.md" "## Scenario"
  assert_contains "$repo_root/$example/README.md" "## Initial Task"
  assert_contains "$repo_root/$example/README.md" "## Profile Selected"
  assert_contains "$repo_root/$example/README.md" "## Commands Run"
  assert_contains "$repo_root/$example/README.md" "## Final Finish Result"
  assert_contains "$repo_root/$example/README.md" "## What The Agent May Claim"
  assert_contains "$repo_root/$example/README.md" "## What The Agent Must Not Claim"
done

echo
echo "== Strict evidence refs example =="
assert_file_exists "$repo_root/examples/bugfix-with-evidence-refs/.agent/acceptance.yml"
assert_contains "$repo_root/examples/bugfix-with-evidence-refs/.agent/acceptance.yml" "evidence_refs:"
assert_contains "$repo_root/examples/bugfix-with-evidence-refs/.agent/harness.yml" "strict_refs: true"

echo
echo "== High-risk policy example =="
assert_file_exists "$repo_root/examples/high-risk-policy-change/.agent/policy.yml"
assert_contains "$repo_root/examples/high-risk-policy-change/README.md" "Expected Failure"
assert_contains "$repo_root/examples/high-risk-policy-change/sample-run/policy-result.txt" "POLICY_RESULT=fail"

echo
echo "== Stability contract =="
assert_file_exists "$repo_root/docs/stability-contract.md"
assert_contains "$repo_root/docs/stability-contract.md" "scripts/agent-finish.sh"
assert_contains "$repo_root/docs/stability-contract.md" "finish-summary.json"
assert_contains "$repo_root/docs/stability-contract.md" "Experimental Interfaces"
assert_contains "$repo_root/docs/stability-contract.md" "Deprecation Policy"
pass "productization examples and stability contract"
```

- [ ] **Step 3: Run the new suite to verify it is red**

Run:

```bash
bash tests/harness/productization-examples.sh
```

Expected: FAIL because the new example directories and stability contract do not exist yet.

## Task 2: Add Three Required Examples

**Files:**
- Create: all files under `examples/docs-only-change/`
- Create: all files under `examples/bugfix-with-evidence-refs/`
- Create: all files under `examples/high-risk-policy-change/`

- [ ] **Step 1: Add docs-only change example**

Create `examples/docs-only-change/README.md`:

````markdown
# Docs Only Change

## Scenario

An agent updates documentation without touching code or protected policy files.

## Initial Task

Clarify one README paragraph.

## Profile Selected

Minimal.

## Commands Run

```bash
bash scripts/agent-task-profile.sh minimal --goal "Clarify README" --allowed "README.md"
bash scripts/agent-finish.sh --best-effort
```

## Expected Failure

None.

## Repair Step

None.

## Final Finish Result

`AGENT_FINISH_RESULT=pass`.

## What The Agent May Claim

The docs-only scoped change passed the configured local finish checks.

## What The Agent Must Not Claim

The agent must not claim semantic correctness, sandboxing, or runtime isolation.
````

Create `examples/docs-only-change/.agent/task.yml`:

```yaml
task:
  status: "complete"
  goal: "Clarify README."
  current_task: "Docs-only update."
  allowed_paths:
    - "README.md"
  forbidden_paths: []
  completion:
    requires_scope_check: true
    requires_policy_check: true
    requires_verification: true
    expects_handoff_update: true
    requires_tdd_evidence: false
    requires_acceptance_check: false
```

Create `examples/docs-only-change/.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "docs link check"
      command: "bash templates/scripts/check-doc-links.sh ."
```

Create `examples/docs-only-change/sample-run/finish-summary.json`:

```json
{
  "overall_result": "pass",
  "mode": "best-effort",
  "gates": {
    "check-scope": { "result": "pass", "exit_status": 0 },
    "check-policy": { "result": "pass", "exit_status": 0 },
    "agent-verify": { "result": "pass", "exit_status": 0 }
  }
}
```

Create `examples/docs-only-change/sample-run/verify-result.txt`:

```text
HARNESS_VERIFY_RESULT=pass
```

Create `examples/docs-only-change/handoff.md`:

```markdown
# Handoff

Docs-only example completed with sample finish evidence in
`sample-run/finish-summary.json`.
```

- [ ] **Step 2: Add bugfix with evidence refs example**

Create `examples/bugfix-with-evidence-refs/README.md` with the required sections and this command sequence:

````markdown
# Bugfix With Evidence Refs

## Scenario

An agent fixes behavior and must bind artifact-backed acceptance evidence.

## Initial Task

Fix a failing edge case and prove verification passed.

## Profile Selected

Standard with strict evidence refs.

## Commands Run

```bash
bash scripts/agent-task-profile.sh standard --goal "Fix edge case" --allowed "src/**" --allowed "tests/**"
bash scripts/agent-finish.sh --strict
bash scripts/agent-evidence-bind.sh --run .agent/runs/20260627-091500 --criterion AC-1 --gate agent-verify
```

## Expected Failure

The first acceptance check fails if `evidence_refs` are missing.

## Repair Step

Bind the finish summary with `scripts/agent-evidence-bind.sh`, rerun
`scripts/check-acceptance.sh`, then rerun `scripts/agent-finish.sh`.

## Final Finish Result

`AGENT_FINISH_RESULT=pass`.

## What The Agent May Claim

The bugfix passed configured verification and strict acceptance evidence points
to a captured finish summary.

## What The Agent Must Not Claim

The agent must not claim the harness proved semantic correctness beyond the
configured checks.
````

Create `examples/bugfix-with-evidence-refs/.agent/task.yml`:

```yaml
task:
  status: "complete"
  goal: "Fix edge case."
  current_task: "Bugfix with strict acceptance evidence."
  allowed_paths:
    - "src/**"
    - "tests/**"
  forbidden_paths: []
  completion:
    requires_scope_check: true
    requires_policy_check: true
    requires_verification: true
    expects_handoff_update: true
    requires_tdd_evidence: true
    requires_acceptance_check: true
```

Create `examples/bugfix-with-evidence-refs/.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "unit tests"
      command: "python3 -m pytest tests"
evidence:
  strict_refs: true
  allow_text_only_evidence: false
```

Create `examples/bugfix-with-evidence-refs/.agent/acceptance.yml`:

```yaml
acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed for the bugfix."
      met: true
      evidence: "See artifact-backed evidence refs."
      evidence_refs:
        - type: finish_summary_json
          path: "sample-run/finish-summary.json"
          gate: "agent-verify"
          overall_result: "pass"
          expected_exit_status: 0
```

Create `examples/bugfix-with-evidence-refs/sample-run/finish-summary.json`:

```json
{
  "overall_result": "pass",
  "mode": "strict",
  "gates": {
    "check-acceptance": { "result": "pass", "exit_status": 0 },
    "agent-verify": { "result": "pass", "exit_status": 0 }
  }
}
```

Create `examples/bugfix-with-evidence-refs/sample-run/verify-result.txt`:

```text
HARNESS_VERIFY_RESULT=pass
```

Create `examples/bugfix-with-evidence-refs/handoff.md`:

```markdown
# Handoff

Bugfix example completed with strict acceptance evidence in
`.agent/acceptance.yml`.
```

- [ ] **Step 3: Add high-risk policy behavior example**

Create `examples/high-risk-policy-change/README.md` with the required sections and this expected failure:

````markdown
# High-Risk Policy Change

## Scenario

An agent attempts to edit a protected policy path.

## Initial Task

Update `.agent/policy.yml` after explicit human approval.

## Profile Selected

High-risk with review and command ledger selected.

## Commands Run

```bash
bash scripts/agent-task-profile.sh high-risk --goal "Update policy" --allowed ".agent/policy.yml" --review --command-ledger
bash scripts/agent-finish.sh --strict
```

## Expected Failure

Without explicit human approval evidence, `check-policy` fails.

## Repair Step

Stop for human approval or avoid the protected path. Do not self-approve the
policy change.

## Final Finish Result

The sample run records `POLICY_RESULT=fail` to show the blocked state.

## What The Agent May Claim

The agent may claim the harness blocked an unapproved high-risk policy change.

## What The Agent Must Not Claim

The agent must not claim approval, security isolation, or policy correctness.
````

Create `examples/high-risk-policy-change/.agent/task.yml`:

```yaml
task:
  status: "blocked"
  goal: "Update policy."
  current_task: "High-risk policy change."
  allowed_paths:
    - ".agent/policy.yml"
  forbidden_paths: []
  completion:
    requires_scope_check: true
    requires_policy_check: true
    requires_verification: true
    expects_handoff_update: true
    requires_tdd_evidence: true
    requires_acceptance_check: true
    requires_review_evidence: true
    requires_command_ledger: true
```

Create `examples/high-risk-policy-change/.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "policy docs check"
      command: "bash scripts/check-policy.sh"
```

Create `examples/high-risk-policy-change/.agent/policy.yml`:

```yaml
risk_files:
  high:
    - ".agent/policy.yml"
approval:
  require_explicit_for_high_risk: true
```

Create `examples/high-risk-policy-change/sample-run/finish-summary.json`:

```json
{
  "overall_result": "fail",
  "mode": "strict",
  "gates": {
    "check-policy": { "result": "fail", "exit_status": 1 },
    "agent-verify": { "result": "pass", "exit_status": 0 }
  }
}
```

Create `examples/high-risk-policy-change/sample-run/verify-result.txt`:

```text
HARNESS_VERIFY_RESULT=pass
```

Create `examples/high-risk-policy-change/sample-run/policy-result.txt`:

```text
POLICY_RESULT=fail
```

Create `examples/high-risk-policy-change/handoff.md`:

```markdown
# Handoff

High-risk policy example is blocked pending explicit human approval evidence.
```

- [ ] **Step 4: Run focused example tests**

Run:

```bash
bash tests/harness/productization-examples.sh
```

Expected: FAIL only because `docs/stability-contract.md` is not created yet.

## Task 3: Add Stability Contract

**Files:**
- Create: `docs/stability-contract.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/public-packaging.md`

- [ ] **Step 1: Create stability contract**

Create `docs/stability-contract.md`:

```markdown
# Stability Contract

This document defines which Agent-Repo-Harness interfaces external users and
agents may rely on.

## Stable Interfaces

- `scripts/agent-finish.sh --strict`
- `scripts/agent-finish.sh --best-effort`
- `scripts/agent-preflight.sh`
- `.agent/runs/<timestamp>/`
- `AGENT_FINISH_RESULT=pass|fail`
- `HARNESS_VERIFY_RESULT=pass|warn|fail`
- `.agent/task.yml` core fields: `task.status`, `task.goal`,
  `task.allowed_paths`, `task.forbidden_paths`, and `task.completion`
- `.agent/harness.yml` `verification.required`
- `.agent/policy.yml` `risk_files.high`

## Intended-Stable Interfaces

- `finish-summary.json` core fields: `overall_result`, `mode`, `run_dir`,
  `gates`, `changed_files`, `diff_stat`, and `elapsed_seconds`
- `evidence_refs` MVP fields: `type`, `path`, `command`, `gate`,
  `expected_exit_status`, `overall_result`, `must_contain`, and
  `must_not_contain`

## Experimental Interfaces

- Entropy audit reports
- Subagent packet format
- Sandbox evidence format
- Architecture evidence schema
- Adapter-specific prompts
- Repair skills and repair prompt wording
- Architecture sensor examples

## Compatibility Rules

Patch versions do not intentionally break stable scripts or core JSON fields.

Minor versions may add optional fields, optional gates, helper scripts, and new
`evidence_refs` types.

Major versions may remove deprecated fields, change default strictness, or
remove legacy approval behavior.

## Deprecation Policy

Deprecated fields or behaviors should remain for at least one minor version
unless they are unsafe. Warnings should be emitted before removal when a script
can detect the deprecated behavior. Legacy approval paths should be explicitly
marked deprecated before stricter defaults are introduced.

## Boundary

This stability contract does not turn Agent-Repo-Harness into a sandbox, full
runtime, provider-native tracing layer, or semantic correctness framework.
```

- [ ] **Step 2: Link from README files**

Add this sentence to `README.md` near versioning or public packaging:

```markdown
For stable and experimental public interfaces, see
[docs/stability-contract.md](docs/stability-contract.md).
```

Add the Traditional Chinese equivalent to `README.zh-TW.md`.

- [ ] **Step 3: Update public packaging doc**

In `docs/public-packaging.md`, add this checklist item:

```markdown
- [x] `docs/stability-contract.md` defines stable, intended-stable, and experimental interfaces.
```

- [ ] **Step 4: Run focused tests and doc links**

Run:

```bash
bash tests/harness/productization-examples.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

## Task 4: Full Verification And Commit

**Files:**
- Modify: all files from Tasks 1-3.
- Modify: `docs/superpowers/plans/2026-06-27-dogfood-examples-stability-contract.md`

- [ ] **Step 1: Run full validation**

Run:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 2: Mark completed plan steps**

After verification passes, update completed checkboxes in this plan from `- [ ]` to `- [x]`.

- [ ] **Step 3: Commit**

```bash
git add docs/stability-contract.md examples/docs-only-change examples/bugfix-with-evidence-refs examples/high-risk-policy-change tests/harness/productization-examples.sh validate-harness.sh README.md README.zh-TW.md docs/public-packaging.md docs/superpowers/plans/2026-06-27-dogfood-examples-stability-contract.md
git commit -m "docs: add productization examples and stability contract"
```
