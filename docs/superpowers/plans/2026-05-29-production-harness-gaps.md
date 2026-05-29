# Production Harness Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the near-term gaps between Agent-Repo-Harness and current harness engineering expectations by adding consistent docs, machine-readable finish evidence, resource-envelope controls, and optional architecture evidence gates.

**Architecture:** Keep the repo-local shell harness as the core product and do not claim to be a sandbox, runtime, or MCP server. Add production-harness capabilities as additive, opt-in contracts: text evidence remains canonical for humans, JSON evidence becomes canonical for tools, resource limits become explicit repo configuration, and architecture evidence becomes an optional completion gate.

**Tech Stack:** POSIX-ish Bash, Python standard library, harness-owned YAML subset reader, JSON Schemas, Markdown docs, existing `tests/harness/*.sh` smoke suites.

---

## Execution Status

- [x] Task 1: documentation drift and public boundary wording completed in
  `e6fa589` with follow-up boundary clarification in `d99f39e`.
- [x] Task 2: `finish-summary.json` implementation and finish evidence tests
  completed in `cdc341a`.
- [x] Task 1 and Task 2 were reviewed for spec compliance and code/doc quality
  before integration.
- [x] Task 2 behavior was landed before the final Task 1 wording correction, so
  public docs now describe the implemented JSON evidence behavior without
  claiming Task 3 or Task 4 are complete.
- [x] Task 3: local resource envelope limits completed in `8cd2c03`.
- [ ] Tasks 4 and 5 have not started.

Verification status:

- Focused finish evidence suite passed:
  `bash -c 'source tests/harness/lib.sh; source tests/harness/finish-examples.sh'`.
- Clean exported `HEAD` passed `bash validate-harness.sh`.
- Live `bash validate-harness.sh` passed after Task 3 landed.

## Scope Check

This plan intentionally covers only features that fit the existing repo-local harness architecture:

- Fix documentation drift where subagent evidence is now gateable but some docs still describe it as never part of `agent-finish.sh`.
- Add structured JSON run evidence beside the existing Markdown/text evidence.
- Add a small resource envelope for finish runs using wall-clock duration and changed-file count, both locally measurable without agent-provider APIs.
- Add an optional architecture evidence gate for semantic and design-risk claims that ordinary test commands cannot prove.
- Document sandbox/runtime/cost-token limitations honestly instead of presenting them as implemented capabilities.

Out of scope for this plan:

- Real filesystem, network, or secret isolation.
- Token accounting from Codex, Claude Code, or other providers.
- A full graph database for SpecGraph, EvidenceGraph, CostGraph, or LineageGraph.
- Replacing Superpowers workflows.

## Parallel Execution Guidance

Tasks 1 and 2 may run in parallel in separate worktrees or subagent sessions:

- Task 1 owns documentation drift and public boundary wording.
- Task 2 owns `finish-summary.json` implementation and finish evidence tests.

Expected overlap:

- `README.md`
- `README.zh-TW.md`
- `docs/USAGE_WITH_AGENTS.md`

Merge rule:

- Land Task 2 implementation first if conflicts occur, then reapply Task 1 wording so docs describe the actual JSON evidence behavior.
- Do not start Task 3 until Tasks 1 and 2 are both reviewed and integrated, because Task 3 depends on the JSON evidence helper and the resource-envelope documentation introduced by those tasks.
- Tasks 4 and 5 remain sequential after Task 3.

## File Structure

- `docs/USAGE_WITH_AGENTS.md`: Align user-facing agent workflow docs with current subagent evidence behavior and JSON evidence.
- `README.md`: Summarize JSON evidence, resource-envelope limits, architecture evidence, and explicit runtime boundaries.
- `README.zh-TW.md`: Mirror the README changes in Traditional Chinese.
- `docs/public-packaging.md`: Add a production-harness follow-up checklist after the v0.1.0 checklist.
- `docs/runtime-boundaries.md`: New doc that clearly separates implemented guardrails from non-implemented sandbox/runtime/cost controls.
- `templates/.agent/harness.yml`: Add disabled-by-default `runtime.resource_limits`.
- `schemas/harness.schema.json`: Validate the new `runtime.resource_limits` shape.
- `templates/.agent/task.yml`: Add `completion.requires_architecture_evidence: false`.
- `schemas/task.schema.json`: Validate `requires_architecture_evidence`.
- `templates/.agent/architecture.yml`: New optional architecture evidence template.
- `schemas/architecture.schema.json`: New schema for architecture evidence.
- `templates/scripts/check-architecture-evidence.sh`: New optional gate for architecture evidence.
- `templates/scripts/agent-finish.sh`: Add JSON evidence output, duration tracking, resource-envelope check, and architecture evidence gate.
- `templates/scripts/agent-preflight.sh`: Include architecture evidence validation when available.
- `install-agent-harness.sh`: Install the new architecture template, schema, and script.
- `validate-harness.sh`: Source the new harness test suite if the suite is split out.
- `tests/harness/doc-consistency.sh`: Assert the docs no longer contain obsolete subagent wording and reference JSON evidence accurately.
- `tests/harness/finish-examples.sh`: Assert `finish-summary.json` is written and contains required fields.
- `tests/harness/resource-envelope.sh`: New focused tests for disabled, passing, and failing resource limits.
- `tests/harness/architecture-evidence.sh`: New focused tests for optional architecture evidence.
- `tests/harness/static-install.sh`: Assert the new template files install.
- `tests/harness/template-sync.sh`: Assert templates, schemas, examples, and docs stay aligned.
- `examples/universal-minimal-repo/.agent/harness.yml`: Mirror disabled resource limits.
- `examples/universal-minimal-repo/.agent/task.yml`: Mirror disabled architecture evidence flag.
- `examples/universal-minimal-repo/.agent/architecture.yml`: Mirror optional architecture evidence template.
- `handoff.md`: Update only after execution with the actual completed work and verification results.

## Implementation Tasks

### Task 1: Fix Harness Engineering Documentation Drift

**Files:**
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/public-packaging.md`
- Create: `docs/runtime-boundaries.md`
- Modify: `tests/harness/doc-consistency.sh`

- [x] **Step 1: Write the failing doc consistency assertions**

Add these assertions near the existing subagent and evidence assertions in `tests/harness/doc-consistency.sh`:

```bash
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Packets are not mandatory for all tasks and are not part"
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "This evidence is optional and is not part of `scripts/agent-finish.sh` yet."
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'completion.requires_subagent_evidence: true'
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'finish-summary.json'
assert_contains "$repo_root/README.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.md" 'finish-summary.json'
assert_contains "$repo_root/README.md" "Resource Envelope"
assert_contains "$repo_root/README.zh-TW.md" "Resource Envelope"
assert_exists "$repo_root/docs/runtime-boundaries.md"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Implemented"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Not Implemented"
assert_contains "$repo_root/docs/public-packaging.md" "Production-harness follow-up checklist"
```

- [x] **Step 2: Run the doc test to verify it fails**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in `Doc consistency` because `docs/USAGE_WITH_AGENTS.md` still contains obsolete subagent wording, `docs/runtime-boundaries.md` does not exist, and README files do not reference JSON evidence or resource envelope text.

- [x] **Step 3: Update `docs/USAGE_WITH_AGENTS.md` subagent and JSON evidence wording**

Replace the current subagent paragraph that says packets and runs are not part of `agent-finish.sh` with:

```markdown
Subagent packets are intended for controller-agent to subagent handoffs. A
controller can fill `.agent/subagent-packet.yml` with the task id, subagent
role, allowed paths, relevant files, required verification, and expected status
enum, then run `scripts/validate-subagent-packet.sh` before spawning or
prompting the subagent. Packets are not mandatory for all tasks.

When `.agent/task.yml` sets `completion.requires_subagent_evidence: true`,
`scripts/agent-finish.sh` requires at least one valid directory under
`.agent/subagent-runs/`. When the flag is false or missing, subagent evidence
remains an optional continuity artifact.
```

Replace the current planned JSON block with:

```markdown
`agent-finish.sh` writes both human-readable and machine-readable evidence:

- `finish-summary.md`: concise Markdown summary for humans and future agents
- `finish-summary.json`: structured run summary for tools, CI, and controller agents
- `*-result.txt`: per-gate command output
- `changed-files.txt`: changed-file evidence
- `git-diff-stat.txt`: diff-size evidence

Treat `finish-summary.json` as the stable machine-readable run envelope. Treat
the text files as the source for detailed command output.
```

- [x] **Step 4: Create `docs/runtime-boundaries.md`**

Create this file:

```markdown
# Runtime Boundaries

Agent-Repo-Harness is a repo-local completion harness. It gives agents
contracts, gates, and evidence requirements before they claim completion.

## Implemented

- Task scope checks against Git changes.
- Repo-local policy checks for high-risk paths.
- Repo-defined verification commands through `.agent/harness.yml`.
- Optional TDD, acceptance, review, subagent, and architecture evidence gates.
- Durable run evidence under `.agent/runs/<timestamp>/`.
- Machine-readable `finish-summary.json` beside the human-readable summary.
- A local resource envelope for finish duration and changed-file count.

## Not Implemented

- Filesystem sandboxing.
- Network sandboxing.
- Secret isolation.
- Agent-provider token accounting.
- Model-cost enforcement.
- Runtime tool orchestration outside local shell scripts.
- Semantic correctness guarantees beyond configured checks and evidence.

## Design Rule

Do not describe the harness as a sandbox, agent runtime, MCP server, or semantic
correctness guarantee. When stronger containment is required, run the harness
inside a separate sandbox, container, VM, worktree, or CI job that provides that
boundary.
```

- [x] **Step 5: Update README evidence and boundary sections**

In `README.md`, add this paragraph after the existing `.agent/runs/<timestamp>/` evidence paragraph:

```markdown
Each finish run also writes `finish-summary.json`, a machine-readable summary
with the run directory, mode, overall result, gate statuses, changed-file
evidence, diff-stat evidence, elapsed seconds, and any resource-envelope result.
Use the JSON file for tools and CI; use the Markdown and text files for human
debugging.
```

Add this section after `Guardrails, Not A Sandbox`:

```markdown
## Resource Envelope

Agent-Repo-Harness can enforce local finish-run limits declared in
`.agent/harness.yml`, such as maximum finish duration and maximum changed-file
count. These limits catch runaway local workflows and scope drift. They do not
measure provider token use or cloud model cost.

For the full runtime boundary, see [docs/runtime-boundaries.md](docs/runtime-boundaries.md).
```

Mirror the same content in `README.zh-TW.md` with this wording:

```markdown
每次 finish run 也會寫入 `finish-summary.json`。這是給工具和 CI 使用的
machine-readable 摘要，包含 run directory、mode、overall result、gate
statuses、changed-file evidence、diff-stat evidence、elapsed seconds，以及
resource-envelope result。人類除錯仍以 Markdown summary 和各 gate 的文字輸出
為主。

## Resource Envelope

Agent-Repo-Harness 可以依 `.agent/harness.yml` 設定本地 finish-run 限制，例如
最大 finish duration 與最大 changed-file count。這些限制用來抓出 runaway local
workflow 和 scope drift；它不會計算 provider token use 或 cloud model cost。

完整 runtime 邊界請看 [docs/runtime-boundaries.md](docs/runtime-boundaries.md)。
```

- [x] **Step 6: Add production-harness follow-up checklist**

Append this section to `docs/public-packaging.md`:

```markdown
## Production-harness follow-up checklist

- [ ] `finish-summary.json` is documented and validated by `validate-harness.sh`.
- [ ] Resource-envelope limits are documented as local shell limits, not token-cost controls.
- [ ] Architecture evidence is documented as an optional semantic/design-risk gate.
- [ ] `docs/runtime-boundaries.md` clearly separates implemented guardrails from sandbox/runtime features that are not implemented.
- [ ] Public wording avoids claiming filesystem isolation, network isolation, secret isolation, model-cost enforcement, or semantic correctness guarantees.
```

- [x] **Step 7: Run doc consistency verification**

Run:

```bash
bash validate-harness.sh
```

Expected: The previous doc-consistency failures are gone. New failures from later unimplemented tasks are acceptable only if those assertions were added before their implementation task starts.

- [x] **Step 8: Commit**

```bash
git add docs/USAGE_WITH_AGENTS.md README.md README.zh-TW.md docs/public-packaging.md docs/runtime-boundaries.md tests/harness/doc-consistency.sh
git commit -m "docs: align production harness boundaries"
```

### Task 2: Add Machine-Readable Finish Evidence

**Files:**
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/finish-examples.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [x] **Step 1: Add failing assertions for `finish-summary.json`**

In `tests/harness/lib.sh`, add this helper near the existing finish evidence helpers:

```bash
assert_finish_json_contract() {
  local root="$1"
  local expected_result="$2"
  local summary_json

  summary_json="$(find "$root/.agent/runs" -type f -name "finish-summary.json" | sort | tail -n 1)"
  if [ -z "$summary_json" ]; then
    echo "ERROR: expected finish-summary.json under $root/.agent/runs"
    exit 1
  fi

  python3 - "$summary_json" "$expected_result" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
expected_result = sys.argv[2]
data = json.loads(summary_path.read_text(encoding="utf-8"))

required_top_level = {
    "timestamp",
    "mode",
    "command",
    "run_dir",
    "overall_result",
    "gates",
    "evidence",
    "elapsed_seconds",
}
missing = sorted(required_top_level - set(data))
if missing:
    raise SystemExit(f"missing top-level keys: {missing}")

if data["overall_result"] != expected_result:
    raise SystemExit(
        f"expected overall_result {expected_result}, got {data['overall_result']}"
    )

if not isinstance(data["gates"], list) or not data["gates"]:
    raise SystemExit("gates must be a non-empty list")

for gate in data["gates"]:
    for key in ("name", "exit_status", "evidence"):
        if key not in gate:
            raise SystemExit(f"gate missing {key}: {gate}")
    if not isinstance(gate["exit_status"], int):
        raise SystemExit(f"gate exit_status must be int: {gate}")

for key in ("changed_files", "diff_stat", "markdown_summary"):
    if key not in data["evidence"]:
        raise SystemExit(f"evidence missing {key}")

if not isinstance(data["elapsed_seconds"], int):
    raise SystemExit("elapsed_seconds must be an integer")
PY
}
```

If the CI environment lacks `python3`, replace `python3` with the existing project Python finder from `tests/harness/lib.sh`; do not add a new dependency.

- [x] **Step 2: Call the helper from finish examples**

After every existing `assert_finish_summary_contract "$root" "pass"` or `"fail"` call in `tests/harness/finish-examples.sh`, add:

```bash
assert_finish_json_contract "$finish_acceptance_review_root" "pass"
```

Use the matching root variable and expected result for each scenario:

```bash
assert_finish_json_contract "$finish_strict_root" "fail"
assert_finish_json_contract "$tdd_required_failure_root" "fail"
assert_finish_json_contract "$subagent_required_failure_root" "fail"
assert_finish_json_contract "$finish_nongit_root" "pass"
```

- [x] **Step 3: Run finish tests to verify they fail**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because no run writes `finish-summary.json`.

- [x] **Step 4: Add JSON summary path and elapsed tracking**

In `templates/scripts/agent-finish.sh`, add these variables near the existing `summary_file` assignment:

```bash
summary_json_file="$run_dir/finish-summary.json"
start_epoch="$(date -u +%s)"
elapsed_seconds=0
resource_status="0"
resource_result_file="$run_dir/resource-envelope-result.txt"
```

- [x] **Step 5: Add a JSON string helper**

Add this function above `write_summary()` in `templates/scripts/agent-finish.sh`:

```bash
json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}
```

If `python3` is not available in installed environments, update the helper before implementation to use the same `python` fallback pattern already used by the harness scripts.

- [x] **Step 6: Add `write_json_summary()`**

Add this function after `write_summary()`:

```bash
write_json_summary() {
  local overall_result="$1"
  local end_epoch

  end_epoch="$(date -u +%s)"
  elapsed_seconds=$((end_epoch - start_epoch))

  python3 - "$summary_json_file" <<PY
import json
from pathlib import Path

data = {
    "timestamp": "$timestamp",
    "mode": "$mode",
    "command": "scripts/agent-finish.sh $mode_arg",
    "run_dir": "$run_dir",
    "overall_result": "$overall_result",
    "elapsed_seconds": int("$elapsed_seconds"),
    "resource_envelope_status": int("${resource_status:-0}"),
    "gates": [
        {
            "name": "check-agent-md",
            "exit_status": int("${agent_md_status:-0}"),
            "evidence": "$check_agent_md_result_file",
        },
        {
            "name": "check-scope",
            "exit_status": int("${scope_status:-0}"),
            "evidence": "$scope_result_file",
        },
        {
            "name": "check-policy",
            "exit_status": int("${policy_status:-0}"),
            "evidence": "$policy_result_file",
        },
        {
            "name": "check-tdd-evidence",
            "exit_status": int("${tdd_evidence_status:-0}"),
            "evidence": "$tdd_evidence_result_file",
        },
        {
            "name": "check-acceptance",
            "exit_status": int("${acceptance_status:-0}"),
            "evidence": "$acceptance_result_file",
        },
        {
            "name": "check-review-evidence",
            "exit_status": int("${review_status:-0}"),
            "evidence": "$review_result_file",
        },
        {
            "name": "check-subagent-evidence",
            "exit_status": int("${subagent_evidence_status:-0}"),
            "evidence": "$subagent_evidence_result_file",
        },
        {
            "name": "agent-verify",
            "exit_status": int("${verify_status:-0}"),
            "evidence": "$verify_result_file",
        },
        {
            "name": "resource-envelope",
            "exit_status": int("${resource_status:-0}"),
            "evidence": "$resource_result_file",
        },
    ],
    "evidence": {
        "markdown_summary": "$summary_file",
        "changed_files": "$changed_files_file",
        "diff_stat": "$diff_stat_file",
    },
}

Path("$summary_json_file").write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
}
```

- [x] **Step 7: Write JSON summary on pass and fail**

Change both places that call `write_summary` so they call `write_json_summary` immediately after:

```bash
write_summary "fail"
write_json_summary "fail"
```

and:

```bash
write_summary "pass"
write_json_summary "pass"
```

- [x] **Step 8: Run finish examples**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for finish JSON assertions. If `python3` is unavailable, update `json_string` and `write_json_summary` to use the existing Python fallback pattern before rerunning.

- [x] **Step 9: Commit**

```bash
git add templates/scripts/agent-finish.sh tests/harness/lib.sh tests/harness/finish-examples.sh docs/USAGE_WITH_AGENTS.md README.md README.zh-TW.md
git commit -m "feat: write machine-readable finish evidence"
```

### Task 3: Add Local Resource Envelope Limits

**Files:**
- Modify: `templates/.agent/harness.yml`
- Modify: `examples/universal-minimal-repo/.agent/harness.yml`
- Modify: `schemas/harness.schema.json`
- Modify: `templates/scripts/agent-finish.sh`
- Create: `tests/harness/resource-envelope.sh`
- Modify: `validate-harness.sh`
- Modify: `tests/harness/template-sync.sh`
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [x] **Step 1: Add failing resource-envelope tests**

Create `tests/harness/resource-envelope.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Resource envelope disabled by default =="
resource_disabled_root="$tmp_root/resource-disabled"
rm -rf "$resource_disabled_root"
mkdir -p "$resource_disabled_root/.agent" "$resource_disabled_root/scripts/lib"
git init -q "$resource_disabled_root"
(
  cd "$resource_disabled_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/.agent/harness.yml" .agent/harness.yml
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_tdd_evidence: false' > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent scripts
  git commit -q -m "Add harness files"
  bash scripts/agent-finish.sh --best-effort > finish.log 2>&1
  assert_contains finish.log "AGENT_FINISH_RESULT=pass"
  assert_file_contains "$resource_disabled_root" "resource-envelope-result.txt" "Resource envelope is disabled."
  assert_finish_json_contract "$resource_disabled_root" "pass"
)
pass "resource envelope disabled by default"

echo
echo "== Resource envelope fails changed-file limit =="
resource_changed_files_root="$tmp_root/resource-changed-files"
rm -rf "$resource_changed_files_root"
mkdir -p "$resource_changed_files_root/.agent" "$resource_changed_files_root/scripts/lib" "$resource_changed_files_root/src"
git init -q "$resource_changed_files_root"
(
  cd "$resource_changed_files_root"
  cp "$repo_root/templates/agent.md" agent.md
  cp "$repo_root/templates/scripts/check-agent-md.sh" scripts/check-agent-md.sh
  cp "$repo_root/templates/scripts/check-scope.sh" scripts/check-scope.sh
  cp "$repo_root/templates/scripts/check-policy.sh" scripts/check-policy.sh
  cp "$repo_root/templates/scripts/check-tdd-evidence.sh" scripts/check-tdd-evidence.sh
  cp "$repo_root/templates/scripts/check-acceptance.sh" scripts/check-acceptance.sh
  cp "$repo_root/templates/scripts/check-review-evidence.sh" scripts/check-review-evidence.sh
  cp "$repo_root/templates/scripts/check-subagent-evidence.sh" scripts/check-subagent-evidence.sh
  cp "$repo_root/templates/scripts/agent-verify.sh" scripts/agent-verify.sh
  cp "$repo_root/templates/scripts/agent-finish.sh" scripts/agent-finish.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/scripts/lib/policy-approval.sh" scripts/lib/policy-approval.sh
  chmod +x scripts/*.sh
  printf '%s\n' \
    'name: Resource Test' \
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
    'runtime:' \
    '  resource_limits:' \
    '    max_finish_seconds: 0' \
    '    max_changed_files: 1' \
    > .agent/harness.yml
  printf '%s\n' 'task:' '  completion:' '    requires_tdd_evidence: false' > .agent/task.yml
  printf '%s\n' 'risk_files:' '  high: []' > .agent/policy.yml
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add agent.md .agent scripts
  git commit -q -m "Add harness files"
  printf '%s\n' one > src/one.txt
  printf '%s\n' two > src/two.txt
  if bash scripts/agent-finish.sh --best-effort > finish.log 2>&1; then
    echo "ERROR: expected resource envelope failure"
    exit 1
  fi
  assert_contains finish.log "Resource envelope failed."
  assert_contains finish.log "AGENT_FINISH_RESULT=fail"
  assert_file_contains "$resource_changed_files_root" "resource-envelope-result.txt" "changed files 2 exceeds limit 1"
  assert_finish_json_contract "$resource_changed_files_root" "fail"
)
pass "resource envelope fails changed-file limit"
```

- [x] **Step 2: Source the new test suite**

Add this line to `validate-harness.sh` after `finish-examples.sh`:

```bash
source "$repo_root/tests/harness/resource-envelope.sh"
```

- [x] **Step 3: Run the test to verify it fails**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `resource-envelope-result.txt` is not written and `.agent/harness.yml` has no `runtime.resource_limits`.

- [x] **Step 4: Add disabled default resource limits**

Append this section to `templates/.agent/harness.yml` and `examples/universal-minimal-repo/.agent/harness.yml`:

```yaml
runtime:
  resource_limits:
    # 0 disables the local finish duration limit.
    max_finish_seconds: 0
    # 0 disables the changed-file count limit.
    max_changed_files: 0
```

- [x] **Step 5: Extend `schemas/harness.schema.json`**

Add this top-level property inside `properties`:

```json
"runtime": {
  "type": "object",
  "properties": {
    "resource_limits": {
      "type": "object",
      "properties": {
        "max_finish_seconds": { "type": "integer", "minimum": 0 },
        "max_changed_files": { "type": "integer", "minimum": 0 }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": true
}
```

- [x] **Step 6: Add resource-envelope helper functions to `agent-finish.sh`**

Add these functions above `write_summary()`:

```bash
find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

read_harness_value() {
  local path="$1"
  local python_bin
  local reader

  if [ ! -f ".agent/harness.yml" ]; then
    return 0
  fi

  if ! python_bin="$(find_python)"; then
    return 0
  fi

  reader="scripts/lib/read-yaml.py"
  if [ ! -f "$reader" ]; then
    return 0
  fi

  "$python_bin" "$reader" ".agent/harness.yml" "$path" --optional 2>/dev/null || true
}

count_changed_files() {
  if [ ! -f "$changed_files_file" ]; then
    printf '%s\n' 0
    return 0
  fi
  awk '
    NF &&
    $0 !~ /^#/ &&
    $0 != "No changed files detected." &&
    $0 !~ /^git is unavailable/ &&
    $0 !~ /^Not inside a git repository/ {
      count++
    }
    END { print count + 0 }
  ' "$changed_files_file"
}

check_resource_envelope() {
  local max_finish_seconds
  local max_changed_files
  local changed_count
  local failures_local=0

  max_finish_seconds="$(read_harness_value "runtime.resource_limits.max_finish_seconds")"
  max_changed_files="$(read_harness_value "runtime.resource_limits.max_changed_files")"
  max_finish_seconds="${max_finish_seconds:-0}"
  max_changed_files="${max_changed_files:-0}"

  {
    echo "Check: resource-envelope"
    echo "Exit status: pending"
    echo
    if [ "$max_finish_seconds" = "0" ] && [ "$max_changed_files" = "0" ]; then
      echo "Resource envelope is disabled."
    else
      echo "Configured limits:"
      echo "- max_finish_seconds: $max_finish_seconds"
      echo "- max_changed_files: $max_changed_files"
      echo "- elapsed_seconds: $elapsed_seconds"
      changed_count="$(count_changed_files)"
      echo "- changed_files: $changed_count"

      if [ "$max_finish_seconds" != "0" ] && [ "$elapsed_seconds" -gt "$max_finish_seconds" ]; then
        echo "ERROR: elapsed seconds $elapsed_seconds exceeds limit $max_finish_seconds"
        failures_local=$((failures_local + 1))
      fi
      if [ "$max_changed_files" != "0" ] && [ "$changed_count" -gt "$max_changed_files" ]; then
        echo "ERROR: changed files $changed_count exceeds limit $max_changed_files"
        failures_local=$((failures_local + 1))
      fi
    fi
  } >"$resource_result_file"

  if [ "$failures_local" -gt 0 ]; then
    resource_status=1
    failures=$((failures + 1))
    echo "Resource envelope failed."
    cat "$resource_result_file"
    return 1
  fi

  resource_status=0
  cat "$resource_result_file"
  return 0
}
```

- [x] **Step 7: Run the resource check after git evidence is written**

In `agent-finish.sh`, immediately after `write_git_evidence`, add:

```bash
elapsed_seconds=$(($(date -u +%s) - start_epoch))
check_resource_envelope || true
```

Ensure `write_json_summary` includes `resource_envelope_status` and the `resource-envelope` gate as described in Task 2.

- [x] **Step 8: Update docs**

In `README.md` and `README.zh-TW.md`, add the concrete config example:

```yaml
runtime:
  resource_limits:
    max_finish_seconds: 300
    max_changed_files: 20
```

Add this sentence after the example:

```markdown
A value of `0` disables that limit. These limits are local shell-run controls
and do not measure provider tokens or hosted model cost.
```

- [x] **Step 9: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS, including the new resource-envelope suite.

- [x] **Step 10: Commit**

```bash
git add templates/.agent/harness.yml examples/universal-minimal-repo/.agent/harness.yml schemas/harness.schema.json templates/scripts/agent-finish.sh tests/harness/resource-envelope.sh validate-harness.sh tests/harness/template-sync.sh README.md README.zh-TW.md
git commit -m "feat: add local resource envelope"
```

### Task 4: Add Optional Architecture Evidence Gate

**Files:**
- Create: `templates/.agent/architecture.yml`
- Create: `schemas/architecture.schema.json`
- Create: `templates/scripts/check-architecture-evidence.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `templates/scripts/agent-preflight.sh`
- Modify: `templates/.agent/task.yml`
- Modify: `examples/universal-minimal-repo/.agent/task.yml`
- Create: `examples/universal-minimal-repo/.agent/architecture.yml`
- Modify: `schemas/task.schema.json`
- Create: `tests/harness/architecture-evidence.sh`
- Modify: `validate-harness.sh`
- Modify: `install-agent-harness.sh`
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [ ] **Step 1: Add failing architecture evidence tests**

Create `tests/harness/architecture-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Architecture evidence not required by default =="
architecture_optional_root="$tmp_root/architecture-optional"
rm -rf "$architecture_optional_root"
mkdir -p "$architecture_optional_root/.agent" "$architecture_optional_root/scripts/lib"
(
  cd "$architecture_optional_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: false' > .agent/task.yml
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "Architecture evidence is not required."
)
pass "architecture evidence not required by default"

echo
echo "== Architecture evidence required and valid =="
architecture_valid_root="$tmp_root/architecture-valid"
rm -rf "$architecture_valid_root"
mkdir -p "$architecture_valid_root/.agent" "$architecture_valid_root/scripts/lib"
(
  cd "$architecture_valid_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  printf '%s\n' \
    'architecture:' \
    '  status: upheld' \
    '  reviewer: "Human Reviewer"' \
    '  evidence: "Reviewed changed module boundaries and public API shape."' \
    '  invariants:' \
    '    - id: "small-public-api"' \
    '      description: "No new broad public API was introduced."' \
    '      status: upheld' \
    '      evidence: "Diff only changes internal harness files."' \
    > .agent/architecture.yml
  bash scripts/check-architecture-evidence.sh > architecture.log 2>&1
  assert_contains architecture.log "Architecture evidence is required."
  assert_contains architecture.log "OK: invariant small-public-api"
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=pass"
)
pass "architecture evidence required and valid"

echo
echo "== Architecture evidence required and invalid =="
architecture_invalid_root="$tmp_root/architecture-invalid"
rm -rf "$architecture_invalid_root"
mkdir -p "$architecture_invalid_root/.agent" "$architecture_invalid_root/scripts/lib"
(
  cd "$architecture_invalid_root"
  cp "$repo_root/templates/scripts/check-architecture-evidence.sh" scripts/check-architecture-evidence.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' 'task:' '  completion:' '    requires_architecture_evidence: true' > .agent/task.yml
  printf '%s\n' \
    'architecture:' \
    '  status: violated' \
    '  reviewer: ""' \
    '  evidence: ""' \
    '  invariants: []' \
    > .agent/architecture.yml
  if bash scripts/check-architecture-evidence.sh > architecture.log 2>&1; then
    echo "ERROR: expected architecture evidence failure"
    exit 1
  fi
  assert_contains architecture.log "architecture.reviewer must be non-empty"
  assert_contains architecture.log "architecture.evidence must be non-empty"
  assert_contains architecture.log "architecture.invariants must contain at least one invariant"
  assert_contains architecture.log "ARCHITECTURE_EVIDENCE_RESULT=fail"
)
pass "architecture evidence required and invalid"
```

- [ ] **Step 2: Source the new test suite**

Add this line to `validate-harness.sh`:

```bash
source "$repo_root/tests/harness/architecture-evidence.sh"
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/check-architecture-evidence.sh` does not exist.

- [ ] **Step 4: Add the architecture evidence template**

Create `templates/.agent/architecture.yml` and `examples/universal-minimal-repo/.agent/architecture.yml`:

```yaml
architecture:
  status: not_reviewed
  reviewer: ""
  evidence: ""
  invariants:
    - id: "public-api-shape"
      description: "The change does not introduce unnecessary public API surface."
      status: not_reviewed
      evidence: ""
    - id: "module-boundaries"
      description: "The change stays within existing module ownership boundaries."
      status: not_reviewed
      evidence: ""
```

- [ ] **Step 5: Add architecture schema**

Create `schemas/architecture.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agent-repo-harness.local/schemas/architecture.schema.json",
  "title": "Agent-Repo-Harness architecture evidence",
  "type": "object",
  "required": ["architecture"],
  "properties": {
    "architecture": {
      "type": "object",
      "required": ["status", "reviewer", "evidence", "invariants"],
      "properties": {
        "status": {
          "enum": ["not_reviewed", "upheld", "upheld_with_concerns", "violated"]
        },
        "reviewer": { "type": "string" },
        "evidence": { "type": "string" },
        "invariants": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["id", "description", "status", "evidence"],
            "properties": {
              "id": { "type": "string" },
              "description": { "type": "string" },
              "status": {
                "enum": ["not_reviewed", "upheld", "upheld_with_concerns", "violated", "not_applicable"]
              },
              "evidence": { "type": "string" }
            },
            "additionalProperties": true
          }
        }
      },
      "additionalProperties": true
    }
  },
  "additionalProperties": true
}
```

- [ ] **Step 6: Add task completion flag**

Add this flag to `templates/.agent/task.yml` and `examples/universal-minimal-repo/.agent/task.yml` under `task.completion`:

```yaml
requires_architecture_evidence: false
```

Add this property to `schemas/task.schema.json` under `task.completion.properties`:

```json
"requires_architecture_evidence": { "type": "boolean" }
```

- [ ] **Step 7: Implement `check-architecture-evidence.sh`**

Create `templates/scripts/check-architecture-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

task_file=".agent/task.yml"
architecture_file=".agent/architecture.yml"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_python() {
  if have_cmd python3; then
    printf '%s\n' "python3"
    return 0
  fi
  if have_cmd python; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"

if [ ! -f "$task_file" ]; then
  echo "Architecture evidence is not required."
  echo "ARCHITECTURE_EVIDENCE_RESULT=pass"
  exit 0
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for architecture evidence checks"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

requires_architecture="$("$python_bin" "$reader" "$task_file" "task.completion.requires_architecture_evidence" --optional 2>/dev/null || true)"
if [ "$requires_architecture" != "true" ]; then
  echo "Architecture evidence is not required."
  echo "ARCHITECTURE_EVIDENCE_RESULT=pass"
  exit 0
fi

echo "Architecture evidence is required."

if [ ! -f "$architecture_file" ]; then
  echo "ERROR: missing $architecture_file"
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

failures=0

read_value() {
  "$python_bin" "$reader" "$architecture_file" "$1" --optional 2>/dev/null || true
}

status="$(read_value "architecture.status")"
reviewer="$(read_value "architecture.reviewer")"
evidence="$(read_value "architecture.evidence")"
invariants_json="$(read_value "architecture.invariants")"

case "$status" in
  upheld|upheld_with_concerns)
    ;;
  *)
    echo "ERROR: architecture.status must be upheld or upheld_with_concerns"
    failures=$((failures + 1))
    ;;
esac

if [ -z "$reviewer" ] || [ "$reviewer" = "null" ] || [ "$reviewer" = "{}" ]; then
  echo "ERROR: architecture.reviewer must be non-empty"
  failures=$((failures + 1))
fi

if [ -z "$evidence" ] || [ "$evidence" = "null" ] || [ "$evidence" = "{}" ]; then
  echo "ERROR: architecture.evidence must be non-empty"
  failures=$((failures + 1))
fi

if [ -z "$invariants_json" ] || [ "$invariants_json" = "[]" ] || [ "$invariants_json" = "{}" ]; then
  echo "ERROR: architecture.invariants must contain at least one invariant"
  failures=$((failures + 1))
else
  if ! printf '%s\n' "$invariants_json" | "$python_bin" -c '
import json
import sys

invariants = json.load(sys.stdin)
if not isinstance(invariants, list) or not invariants:
    raise SystemExit("architecture.invariants must contain at least one invariant")

failed = 0
for invariant in invariants:
    ident = str(invariant.get("id", "")).strip()
    status = str(invariant.get("status", "")).strip()
    evidence = str(invariant.get("evidence", "")).strip()
    if not ident:
        print("ERROR: invariant id must be non-empty")
        failed += 1
        continue
    if status not in {"upheld", "upheld_with_concerns", "not_applicable"}:
        print(f"ERROR: invariant {ident} status must be upheld, upheld_with_concerns, or not_applicable")
        failed += 1
    elif not evidence:
        print(f"ERROR: invariant {ident} evidence must be non-empty")
        failed += 1
    else:
        print(f"OK: invariant {ident}")

raise SystemExit(1 if failed else 0)
'; then
    failures=$((failures + 1))
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "ARCHITECTURE_EVIDENCE_RESULT=fail"
  exit 1
fi

echo "ARCHITECTURE_EVIDENCE_RESULT=pass"
```

- [ ] **Step 8: Wire architecture evidence into finish gate**

In `templates/scripts/agent-finish.sh`, add:

```bash
architecture_result_file="$run_dir/architecture-evidence-result.txt"
architecture_status=""
```

Add a gate row to `write_summary()`:

```bash
echo "| check-architecture-evidence | $architecture_status | $architecture_result_file |"
```

In strict mode and best-effort mode, run the gate after review evidence and before subagent evidence:

```bash
run_gate "check-architecture-evidence" "$architecture_result_file" bash scripts/check-architecture-evidence.sh
architecture_status="$last_status"
```

Add this gate to `write_json_summary()`:

```python
{
    "name": "check-architecture-evidence",
    "exit_status": int("${architecture_status:-0}"),
    "evidence": "$architecture_result_file",
},
```

- [ ] **Step 9: Install the new files**

Update `install-agent-harness.sh` so a default install copies:

```text
templates/.agent/architecture.yml -> .agent/architecture.yml
templates/scripts/check-architecture-evidence.sh -> scripts/check-architecture-evidence.sh
schemas/architecture.schema.json -> schemas/architecture.schema.json
```

Follow the existing install list style. Preserve dry-run, backup, and no-overwrite behavior.

- [ ] **Step 10: Update preflight**

In `templates/scripts/agent-preflight.sh`, add:

```bash
bash scripts/check-architecture-evidence.sh
```

Place it after review evidence if that script is already called, or after task validation if preflight only validates the core files.

- [ ] **Step 11: Update docs**

Add this section to `README.md`:

```markdown
## Architecture Evidence

For changes where tests are not enough to prove design quality, set
`completion.requires_architecture_evidence: true` in `.agent/task.yml` and fill
`.agent/architecture.yml`. The gate requires a reviewer, summary evidence, and
at least one invariant marked `upheld`, `upheld_with_concerns`, or
`not_applicable` with concrete evidence.
```

Add the Traditional Chinese version to `README.zh-TW.md`:

```markdown
## Architecture Evidence

當測試不足以證明設計品質時，可以在 `.agent/task.yml` 設定
`completion.requires_architecture_evidence: true`，並填寫
`.agent/architecture.yml`。此 gate 會要求 reviewer、summary evidence，以及至少
一個標記為 `upheld`、`upheld_with_concerns` 或 `not_applicable` 且包含具體
evidence 的 invariant。
```

- [ ] **Step 12: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS, including architecture evidence, install smoke, template sync, and finish examples.

- [ ] **Step 13: Commit**

```bash
git add templates/.agent/architecture.yml examples/universal-minimal-repo/.agent/architecture.yml schemas/architecture.schema.json templates/scripts/check-architecture-evidence.sh templates/scripts/agent-finish.sh templates/scripts/agent-preflight.sh templates/.agent/task.yml examples/universal-minimal-repo/.agent/task.yml schemas/task.schema.json tests/harness/architecture-evidence.sh validate-harness.sh install-agent-harness.sh README.md README.zh-TW.md
git commit -m "feat: add architecture evidence gate"
```

### Task 5: Final Alignment and Public Baseline Readiness

**Files:**
- Modify: `docs/public-packaging.md`
- Modify: `docs/plans/agent-harness-optimization-plan.md`
- Modify: `handoff.md`
- Possibly modify: `CHANGELOG.md`

- [ ] **Step 1: Add final consistency assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_contains "$repo_root/README.md" "Architecture Evidence"
assert_contains "$repo_root/README.md" "Resource Envelope"
assert_contains "$repo_root/README.md" "finish-summary.json"
assert_contains "$repo_root/README.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.zh-TW.md" "Architecture Evidence"
assert_contains "$repo_root/README.zh-TW.md" "Resource Envelope"
assert_contains "$repo_root/docs/public-packaging.md" "Production-harness follow-up checklist"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Agent-provider token accounting"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Filesystem sandboxing"
```

- [ ] **Step 2: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 3: Update the optimization plan status**

In `docs/plans/agent-harness-optimization-plan.md`, add this section near the top after `## 1. Current State Summary`:

```markdown
## 1.1 2026-05-29 Production Harness Gap Update

The earlier MVP gaps around shared config parsing, acceptance evidence, review
evidence, subagent evidence, doc-link checks, template sync, and adapter sync
have been implemented. Remaining production-harness work is now tracked as:

- machine-readable finish evidence through `finish-summary.json`
- local resource-envelope limits for finish runs
- optional architecture evidence for semantic and design-risk claims
- explicit runtime-boundary documentation for sandbox, token-cost, and semantic-correctness limits

Agent-Repo-Harness remains a repo-local completion harness. It is not a
filesystem sandbox, network sandbox, MCP server, full agent runtime, or semantic
correctness guarantee.
```

- [ ] **Step 4: Update changelog if this work is part of the release**

If the branch targets v0.1.0, add this bullet under the v0.1.0 entry in `CHANGELOG.md`:

```markdown
- Added machine-readable finish evidence, local resource-envelope controls, architecture evidence, and runtime-boundary documentation.
```

If the branch targets a post-v0.1.0 release, create a new `Unreleased` section instead:

```markdown
## Unreleased

- Added machine-readable finish evidence, local resource-envelope controls, architecture evidence, and runtime-boundary documentation.
```

- [ ] **Step 5: Run final verification**

Run:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected:

```text
All runnable harness suites pass.
```

and:

```text
DOC_LINKS_RESULT=pass
```

- [ ] **Step 6: Update handoff**

Replace `handoff.md` with a concise current-state summary:

```markdown
# handoff.md

## Current Task
Close the near-term production harness engineering gaps identified from the
public harness engineering comparison.

## Current State
Completed. The harness now documents runtime boundaries, writes
machine-readable finish evidence, supports local resource-envelope limits, and
offers optional architecture evidence for semantic/design-risk claims.

## Changed Files
- `README.md`
- `README.zh-TW.md`
- `CHANGELOG.md`
- `docs/USAGE_WITH_AGENTS.md`
- `docs/public-packaging.md`
- `docs/runtime-boundaries.md`
- `docs/plans/agent-harness-optimization-plan.md`
- `schemas/architecture.schema.json`
- `schemas/harness.schema.json`
- `schemas/task.schema.json`
- `templates/.agent/architecture.yml`
- `templates/.agent/harness.yml`
- `templates/.agent/task.yml`
- `templates/scripts/agent-finish.sh`
- `templates/scripts/agent-preflight.sh`
- `templates/scripts/check-architecture-evidence.sh`
- `examples/universal-minimal-repo/.agent/architecture.yml`
- `examples/universal-minimal-repo/.agent/harness.yml`
- `examples/universal-minimal-repo/.agent/task.yml`
- `install-agent-harness.sh`
- `tests/harness/architecture-evidence.sh`
- `tests/harness/doc-consistency.sh`
- `tests/harness/finish-examples.sh`
- `tests/harness/lib.sh`
- `tests/harness/resource-envelope.sh`
- `tests/harness/static-install.sh`
- `tests/harness/template-sync.sh`
- `validate-harness.sh`
- `handoff.md`

## Verification
- `bash validate-harness.sh`: pass
- `bash templates/scripts/check-doc-links.sh .`: pass

## Remaining Limits
- The harness is still not a filesystem sandbox, network sandbox, MCP server, or
  full agent runtime.
- Resource-envelope controls are local shell limits, not provider token-cost
  accounting.
- Architecture evidence improves review discipline but is not a semantic
  correctness guarantee.

## Next Recommended Step
- Review the public wording and decide whether these changes belong in v0.1.0
  or the next post-v0.1.0 release.
```

- [ ] **Step 7: Commit**

```bash
git add docs/public-packaging.md docs/plans/agent-harness-optimization-plan.md CHANGELOG.md handoff.md tests/harness/doc-consistency.sh
git commit -m "docs: finalize production harness gap tracking"
```

## Self-Review

Spec coverage:

- Documentation drift: Task 1 and Task 5.
- JSON evidence / episode package: Task 2.
- Resource envelope: Task 3.
- Architecture and semantic-risk evidence: Task 4.
- Runtime/sandbox/cost boundary: Task 1 and Task 5.
- Public baseline readiness: Task 5.

Placeholder scan:

- Every step uses concrete implementation text instead of open-ended work markers.
- Every code-changing task includes concrete file paths, snippets, commands, and expected results.

Type and name consistency:

- The task flag is consistently named `requires_architecture_evidence`.
- The architecture file is consistently named `.agent/architecture.yml`.
- The architecture script is consistently named `scripts/check-architecture-evidence.sh`.
- The JSON evidence file is consistently named `finish-summary.json`.
- Resource config is consistently under `runtime.resource_limits`.
