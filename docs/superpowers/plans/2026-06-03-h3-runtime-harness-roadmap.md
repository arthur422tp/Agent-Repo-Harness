# H3 Runtime Harness Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve Agent-Repo-Harness from a strong repo-local completion harness into an H3-style auditable harness package without claiming to be a sandbox or full agent runtime.

**Architecture:** Keep the shell/Python repo-local core and add additive contracts for episode metadata, failure attribution, intervention recording, and entropy auditing. `scripts/agent-finish.sh` remains the canonical completion gate; new gates are opt-in through `.agent/task.yml`, while `scripts/agent-audit.sh` becomes the non-blocking operational audit entrypoint.

**Tech Stack:** POSIX-ish Bash, Python standard library, harness-owned YAML subset reader, JSON Schemas, Markdown templates, existing `tests/harness/*.sh` validation suites.

---

## Current Baseline

Agent-Repo-Harness already has:

- concise agent entrypoints through `templates/AGENTS.md` and `templates/CLAUDE.md`
- repo-local scope, policy, verification, TDD, acceptance, review, architecture, and subagent gates
- durable finish evidence under `.agent/runs/<timestamp>/`
- `finish-summary.json` for tool-readable completion evidence
- resource-envelope limits for finish duration and changed-file count
- doc-link, template-sync, adapter-sync, and install validation through `bash validate-harness.sh`

The remaining gap is not another simple check script. The missing H3-grade pieces are:

- a named episode package contract
- structured failure-attribution evidence
- structured human/tool intervention recording
- a repeatable entropy audit report
- docs that explain how these pieces relate to external sandbox/runtime layers

## File Structure

Create:

- `schemas/episode.schema.json`: machine-readable contract for `.agent/episode.yml` and generated episode summaries.
- `schemas/failure-attribution.schema.json`: contract for `.agent/failure-attribution.yml`.
- `schemas/interventions.schema.json`: contract for `.agent/interventions.yml`.
- `templates/.agent/episode.yml`: per-task episode metadata template.
- `templates/.agent/failure-attribution.yml`: optional failure analysis evidence template.
- `templates/.agent/interventions.yml`: optional intervention log template.
- `templates/scripts/validate-episode.sh`: validates `.agent/episode.yml` when present.
- `templates/scripts/check-failure-attribution.sh`: optional finish gate controlled by `.agent/task.yml`.
- `templates/scripts/check-interventions.sh`: optional finish gate controlled by `.agent/task.yml`.
- `templates/scripts/agent-audit.sh`: non-blocking entropy audit report generator.
- `tests/harness/episode.sh`: validation tests for episode metadata and finish integration.
- `tests/harness/failure-attribution.sh`: gate tests for failure attribution evidence.
- `tests/harness/interventions.sh`: gate tests for intervention evidence.
- `tests/harness/entropy-audit.sh`: audit report tests.
- `docs/agent/episode-package.md`: user-facing description of generated evidence.
- `docs/agent/failure-attribution.md`: repair and attribution workflow.
- `docs/agent/interventions.md`: intervention log rules.
- `docs/agent/entropy-audit.md`: audit command and interpretation guide.

Modify:

- `templates/.agent/task.yml`: add opt-in completion flags for failure attribution and intervention records.
- `schemas/task.schema.json`: validate new completion flags.
- `templates/.agent/harness.yml`: add episode/audit script paths and audit config.
- `schemas/harness.schema.json`: validate audit config shape.
- `templates/scripts/agent-preflight.sh`: include episode validation and audit command discovery.
- `templates/scripts/agent-finish.sh`: run new optional gates and write `episode-summary.json`.
- `templates/AGENTS.md`: point agents to episode, failure attribution, intervention, and audit docs.
- `templates/CLAUDE.md`: mirror concise lifecycle guidance.
- `templates/agent.md`: keep stable repo memory short and link to new docs.
- `install-agent-harness.sh`: copy new schemas.
- `validate-harness.sh`: source new harness suites.
- `tests/harness/lib.sh`: add assertions for new finish evidence files.
- `tests/harness/static-install.sh`: assert new templates and schemas install.
- `tests/harness/template-sync.sh`: assert templates/examples/docs stay aligned.
- `docs/runtime-boundaries.md`: clarify which H3 pieces are implemented locally and which require external runtime/sandbox integration.
- `README.md` and `README.zh-TW.md`: summarize the new H3 follow-up capabilities without overstating isolation.
- `docs/USAGE_WITH_AGENTS.md`: add operational workflow examples.
- `handoff.md`: update after implementation with actual verification evidence.

## Implementation Tasks

### Task 1: Episode Package Contract

**Files:**
- Create: `schemas/episode.schema.json`
- Create: `templates/.agent/episode.yml`
- Create: `templates/scripts/validate-episode.sh`
- Create: `tests/harness/episode.sh`
- Modify: `templates/scripts/agent-preflight.sh`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `validate-harness.sh`
- Modify: `install-agent-harness.sh`

- [x] **Step 1: Write failing install and validation tests**

Add this suite file:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Episode metadata validation =="
episode_root="$tmp_root/episode"
rm -rf "$episode_root"
mkdir -p "$episode_root/.agent" "$episode_root/scripts/lib"
(
  cd "$episode_root"
  cp "$repo_root/templates/.agent/episode.yml" .agent/episode.yml
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  bash scripts/validate-episode.sh > episode.log 2>&1
  assert_contains episode.log "EPISODE_VALIDATION_RESULT=pass"
)
pass "episode metadata validation"

echo
echo "== Episode metadata missing required value =="
episode_bad_root="$tmp_root/episode-bad"
rm -rf "$episode_bad_root"
mkdir -p "$episode_bad_root/.agent" "$episode_bad_root/scripts/lib"
(
  cd "$episode_bad_root"
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'episode:' \
    '  id: ""' \
    '  objective: ""' \
    > .agent/episode.yml
  if bash scripts/validate-episode.sh > episode-bad.log 2>&1; then
    echo "ERROR: expected episode validation failure"
    exit 1
  fi
  assert_contains episode-bad.log "episode.id must be non-empty"
  assert_contains episode-bad.log "EPISODE_VALIDATION_RESULT=fail"
)
pass "episode metadata missing required value"
```

Source it in `validate-harness.sh` after `task-validation.sh`:

```bash
source "$repo_root/tests/harness/episode.sh"
```

Expected first run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/.agent/episode.yml` and `templates/scripts/validate-episode.sh` do not exist.

- [x] **Step 2: Add the episode schema**

Create `schemas/episode.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agent-repo-harness.local/schemas/episode.schema.json",
  "title": "Agent episode metadata",
  "type": "object",
  "required": ["episode"],
  "properties": {
    "episode": {
      "type": "object",
      "required": ["id", "objective", "actor", "status"],
      "properties": {
        "id": { "type": "string", "minLength": 1 },
        "objective": { "type": "string", "minLength": 1 },
        "actor": {
          "type": "object",
          "required": ["kind", "name"],
          "properties": {
            "kind": { "type": "string", "enum": ["agent", "human", "hybrid"] },
            "name": { "type": "string", "minLength": 1 }
          },
          "additionalProperties": true
        },
        "status": {
          "type": "string",
          "enum": ["planned", "in_progress", "blocked", "ready_for_finish", "finished"]
        },
        "context": {
          "type": "object",
          "properties": {
            "loaded_files": {
              "type": "array",
              "items": { "type": "string" }
            },
            "external_sources": {
              "type": "array",
              "items": { "type": "string" }
            }
          },
          "additionalProperties": true
        }
      },
      "additionalProperties": true
    }
  },
  "additionalProperties": true
}
```

- [x] **Step 3: Add the episode template**

Create `templates/.agent/episode.yml`:

```yaml
episode:
  id: "local-task"
  objective: "Record the current agent work episode."
  actor:
    kind: "agent"
    name: "coding-agent"
  status: "planned"
  context:
    loaded_files:
      - "AGENTS.md"
      - "agent.md"
      - "handoff.md"
      - ".agent/task.yml"
    external_sources: []
  notes: []
```

- [x] **Step 4: Add episode validation script**

Create `templates/scripts/validate-episode.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

episode_file="${1:-.agent/episode.yml}"
reader="scripts/lib/read-yaml.py"
failures=0

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

require_non_empty() {
  local path="$1"
  local label="$2"
  local value

  value="$("$python_bin" "$reader" "$episode_file" "$path" --optional 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "ERROR: $label must be non-empty"
    failures=$((failures + 1))
  else
    echo "OK: $label"
  fi
}

if [ ! -f "$episode_file" ]; then
  echo "Episode metadata is optional and not present."
  echo "EPISODE_VALIDATION_RESULT=pass"
  exit 0
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for episode validation"
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

echo "== Episode Metadata Validation =="
echo "Episode file: $episode_file"

if ! "$python_bin" "$reader" "$episode_file" episode >/dev/null 2>&1; then
  echo "ERROR: episode must be a map"
  failures=$((failures + 1))
fi

require_non_empty "episode.id" "episode.id"
require_non_empty "episode.objective" "episode.objective"
require_non_empty "episode.actor.kind" "episode.actor.kind"
require_non_empty "episode.actor.name" "episode.actor.name"
require_non_empty "episode.status" "episode.status"

status="$("$python_bin" "$reader" "$episode_file" "episode.status" --optional 2>/dev/null || true)"
case "$status" in
  planned|in_progress|blocked|ready_for_finish|finished)
    echo "OK: episode.status is valid"
    ;;
  *)
    echo "ERROR: episode.status must be planned, in_progress, blocked, ready_for_finish, or finished"
    failures=$((failures + 1))
    ;;
esac

actor_kind="$("$python_bin" "$reader" "$episode_file" "episode.actor.kind" --optional 2>/dev/null || true)"
case "$actor_kind" in
  agent|human|hybrid)
    echo "OK: episode.actor.kind is valid"
    ;;
  *)
    echo "ERROR: episode.actor.kind must be agent, human, or hybrid"
    failures=$((failures + 1))
    ;;
esac

if [ "$failures" -gt 0 ]; then
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

echo "EPISODE_VALIDATION_RESULT=pass"
```

- [x] **Step 5: Wire preflight and finish evidence**

In `templates/scripts/agent-preflight.sh`, add this block after task validation or optional evidence gates:

```bash
echo
echo "== Episode metadata =="
if [ -f scripts/validate-episode.sh ]; then
  if ! bash scripts/validate-episode.sh; then
    echo "WARN: episode metadata is invalid; scripts/agent-finish.sh will still write finish evidence."
  fi
else
  echo "SKIP: scripts/validate-episode.sh not found"
fi
```

In `templates/scripts/agent-finish.sh`, add:

```bash
episode_result_file="$run_dir/episode-result.txt"
episode_summary_json_file="$run_dir/episode-summary.json"
episode_status=""
```

Add a `run_gate` call in both strict and best-effort branches before `agent-verify`:

```bash
run_gate "validate-episode" "$episode_result_file" bash scripts/validate-episode.sh
episode_status="$last_status"
```

Add a row to `write_summary`:

```bash
echo "| validate-episode | $episode_status | $episode_result_file |"
```

Add JSON environment variables in `write_json_summary`:

```bash
AGENT_FINISH_EPISODE_STATUS="${episode_status:-0}" \
AGENT_FINISH_EPISODE_EVIDENCE="$episode_result_file" \
```

Add a gate entry to the Python JSON payload:

```python
{
    "name": "validate-episode",
    "exit_status": int(env["AGENT_FINISH_EPISODE_STATUS"]),
    "evidence": env["AGENT_FINISH_EPISODE_EVIDENCE"],
},
```

Add a second JSON writer after `write_json_summary` that creates `episode-summary.json`:

```bash
write_episode_summary() {
  EPISODE_SUMMARY_JSON_FILE="$episode_summary_json_file" \
  AGENT_FINISH_TIMESTAMP="$timestamp" \
  AGENT_FINISH_MODE="$mode" \
  AGENT_FINISH_RUN_DIR="$run_dir" \
  AGENT_FINISH_OVERALL_RESULT="$1" \
  AGENT_FINISH_SUMMARY_JSON="$summary_json_file" \
  "$python_bin" - <<'PY'
import json
import os
from pathlib import Path

data = {
    "timestamp": os.environ["AGENT_FINISH_TIMESTAMP"],
    "mode": os.environ["AGENT_FINISH_MODE"],
    "run_dir": os.environ["AGENT_FINISH_RUN_DIR"],
    "overall_result": os.environ["AGENT_FINISH_OVERALL_RESULT"],
    "finish_summary_json": os.environ["AGENT_FINISH_SUMMARY_JSON"],
    "contracts": {
        "task": ".agent/task.yml",
        "episode": ".agent/episode.yml",
        "policy": ".agent/policy.yml",
        "harness": ".agent/harness.yml"
    },
    "evidence": {
        "finish_summary": "finish-summary.md",
        "changed_files": "changed-files.txt",
        "diff_stat": "git-diff-stat.txt"
    }
}

Path(os.environ["EPISODE_SUMMARY_JSON_FILE"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
}
```

Call it after each `write_json_summary`:

```bash
write_episode_summary "fail"
```

and:

```bash
write_episode_summary "pass"
```

- [x] **Step 6: Update evidence assertions**

In `tests/harness/lib.sh`, add `episode-result.txt` and `episode-summary.json` to `assert_run_evidence_files`:

```bash
episode-result.txt
episode-summary.json
```

Add finish-summary expectations:

```bash
assert_file_contains "$root" "finish-summary.md" "| validate-episode |"
assert_file_contains "$root" "finish-summary.md" "episode-result.txt"
```

Extend `assert_finish_json_contract` to require the gate name:

```python
gate_names = {gate["name"] for gate in data["gates"]}
if "validate-episode" not in gate_names:
    raise SystemExit("missing validate-episode gate")
```

- [x] **Step 7: Install schema and run tests**

In `install-agent-harness.sh`, add:

```bash
if [ -f "$schema_root/episode.schema.json" ]; then
  copy_path \
    "$schema_root/episode.schema.json" \
    "$target/schemas/episode.schema.json"
fi
```

Run:

```bash
bash validate-harness.sh
```

Expected: PASS, with the new `Episode metadata validation` suite included.

- [x] **Step 8: Commit**

```bash
git add schemas/episode.schema.json templates/.agent/episode.yml templates/scripts/validate-episode.sh templates/scripts/agent-preflight.sh templates/scripts/agent-finish.sh tests/harness/episode.sh tests/harness/lib.sh validate-harness.sh install-agent-harness.sh
git commit -m "feat: add episode package contract"
```

### Task 2: Failure Attribution Evidence

**Files:**
- Create: `schemas/failure-attribution.schema.json`
- Create: `templates/.agent/failure-attribution.yml`
- Create: `templates/scripts/check-failure-attribution.sh`
- Create: `tests/harness/failure-attribution.sh`
- Modify: `templates/.agent/task.yml`
- Modify: `schemas/task.schema.json`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `validate-harness.sh`
- Modify: `install-agent-harness.sh`

- [x] **Step 1: Write failing gate tests**

Create `tests/harness/failure-attribution.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Failure attribution skip semantics =="
failure_attr_skip_root="$tmp_root/failure-attribution-skip"
rm -rf "$failure_attr_skip_root"
mkdir -p "$failure_attr_skip_root/.agent" "$failure_attr_skip_root/scripts/lib"
(
  cd "$failure_attr_skip_root"
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: false' \
    > .agent/task.yml
  bash scripts/check-failure-attribution.sh > failure-attribution-skip.log 2>&1
  assert_contains failure-attribution-skip.log "Failure attribution is not required."
  assert_contains failure-attribution-skip.log "FAILURE_ATTRIBUTION_RESULT=pass"
)
pass "failure attribution skip semantics"

echo
echo "== Failure attribution required and valid =="
failure_attr_pass_root="$tmp_root/failure-attribution-pass"
rm -rf "$failure_attr_pass_root"
mkdir -p "$failure_attr_pass_root/.agent" "$failure_attr_pass_root/scripts/lib"
(
  cd "$failure_attr_pass_root"
  cp "$repo_root/templates/.agent/failure-attribution.yml" .agent/failure-attribution.yml
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: true' \
    > .agent/task.yml
  bash scripts/check-failure-attribution.sh > failure-attribution-pass.log 2>&1
  assert_contains failure-attribution-pass.log "Failure attribution is required."
  assert_contains failure-attribution-pass.log "OK: failure attribution"
  assert_contains failure-attribution-pass.log "FAILURE_ATTRIBUTION_RESULT=pass"
)
pass "failure attribution required and valid"

echo
echo "== Failure attribution required and invalid =="
failure_attr_bad_root="$tmp_root/failure-attribution-bad"
rm -rf "$failure_attr_bad_root"
mkdir -p "$failure_attr_bad_root/.agent" "$failure_attr_bad_root/scripts/lib"
(
  cd "$failure_attr_bad_root"
  cp "$repo_root/templates/scripts/check-failure-attribution.sh" scripts/check-failure-attribution.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_failure_attribution: true' \
    > .agent/task.yml
  printf '%s\n' \
    'failure_attribution:' \
    '  required: true' \
    '  status: incomplete' \
    > .agent/failure-attribution.yml
  if bash scripts/check-failure-attribution.sh > failure-attribution-bad.log 2>&1; then
    echo "ERROR: expected failure attribution gate failure"
    exit 1
  fi
  assert_contains failure-attribution-bad.log "root_cause must be non-empty"
  assert_contains failure-attribution-bad.log "FAILURE_ATTRIBUTION_RESULT=fail"
)
pass "failure attribution required and invalid"
```

Source it in `validate-harness.sh` after `architecture-evidence.sh`:

```bash
source "$repo_root/tests/harness/failure-attribution.sh"
```

Expected first run:

```bash
bash validate-harness.sh
```

Expected: FAIL because the script and template are missing.

- [x] **Step 2: Add failure attribution schema and template**

Create `schemas/failure-attribution.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agent-repo-harness.local/schemas/failure-attribution.schema.json",
  "title": "Failure attribution evidence",
  "type": "object",
  "required": ["failure_attribution"],
  "properties": {
    "failure_attribution": {
      "type": "object",
      "required": ["required", "status", "root_cause", "evidence", "repair"],
      "properties": {
        "required": { "type": "boolean" },
        "status": { "type": "string", "enum": ["complete", "complete_with_concerns"] },
        "root_cause": { "type": "string", "minLength": 1 },
        "evidence": { "type": "string", "minLength": 1 },
        "repair": { "type": "string", "minLength": 1 },
        "verification": { "type": "string" },
        "concerns": {
          "type": "array",
          "items": { "type": "string" }
        }
      },
      "additionalProperties": true
    }
  },
  "additionalProperties": true
}
```

Create `templates/.agent/failure-attribution.yml`:

```yaml
failure_attribution:
  required: false
  status: "complete"
  root_cause: "No failure attribution required for the current task."
  evidence: "No blocking gate failure is being attributed."
  repair: "No repair action required."
  verification: "bash scripts/agent-finish.sh --best-effort"
  concerns: []
```

- [x] **Step 3: Add failure attribution gate**

Create `templates/scripts/check-failure-attribution.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

task_file="${TASK_FILE:-.agent/task.yml}"
attribution_file="${FAILURE_ATTRIBUTION_FILE:-.agent/failure-attribution.yml}"
reader="scripts/lib/read-yaml.py"
failures=0

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

read_value() {
  "$python_bin" "$reader" "$1" "$2" --optional 2>/dev/null || true
}

require_non_empty() {
  local path="$1"
  local label="$2"
  local value

  value="$(read_value "$attribution_file" "$path")"
  if [ -z "$value" ]; then
    echo "ERROR: $label must be non-empty"
    failures=$((failures + 1))
  else
    echo "OK: $label"
  fi
}

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for failure attribution checks"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

required="$(read_value "$task_file" "task.completion.requires_failure_attribution")"
if [ "$required" != "true" ]; then
  echo "Failure attribution is not required."
  echo "FAILURE_ATTRIBUTION_RESULT=pass"
  exit 0
fi

echo "Failure attribution is required."

if [ ! -f "$attribution_file" ]; then
  echo "ERROR: missing $attribution_file"
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

status="$(read_value "$attribution_file" "failure_attribution.status")"
case "$status" in
  complete|complete_with_concerns)
    echo "OK: failure attribution status"
    ;;
  *)
    echo "ERROR: failure_attribution.status must be complete or complete_with_concerns"
    failures=$((failures + 1))
    ;;
esac

require_non_empty "failure_attribution.root_cause" "root_cause"
require_non_empty "failure_attribution.evidence" "evidence"
require_non_empty "failure_attribution.repair" "repair"

if [ "$failures" -gt 0 ]; then
  echo "FAILURE_ATTRIBUTION_RESULT=fail"
  exit 1
fi

echo "OK: failure attribution"
echo "FAILURE_ATTRIBUTION_RESULT=pass"
```

- [x] **Step 4: Add task flag validation**

In `templates/.agent/task.yml`, add:

```yaml
    requires_failure_attribution: false
```

In `schemas/task.schema.json`, add the boolean property under `completion.properties`:

```json
"requires_failure_attribution": { "type": "boolean" }
```

In `templates/scripts/validate-task.sh`, add the same style of boolean check already used for other completion flags:

```bash
check_optional_bool "task.completion.requires_failure_attribution"
```

- [x] **Step 5: Wire the finish gate**

In `templates/scripts/agent-finish.sh`, add:

```bash
failure_attribution_result_file="$run_dir/failure-attribution-result.txt"
failure_attribution_status=""
```

Run it in both branches before `agent-verify`:

```bash
run_gate "check-failure-attribution" "$failure_attribution_result_file" bash scripts/check-failure-attribution.sh
failure_attribution_status="$last_status"
```

Add the summary row:

```bash
echo "| check-failure-attribution | $failure_attribution_status | $failure_attribution_result_file |"
```

Add JSON environment variables:

```bash
AGENT_FINISH_FAILURE_ATTRIBUTION_STATUS="${failure_attribution_status:-0}" \
AGENT_FINISH_FAILURE_ATTRIBUTION_EVIDENCE="$failure_attribution_result_file" \
```

Add JSON gate entry:

```python
{
    "name": "check-failure-attribution",
    "exit_status": int(env["AGENT_FINISH_FAILURE_ATTRIBUTION_STATUS"]),
    "evidence": env["AGENT_FINISH_FAILURE_ATTRIBUTION_EVIDENCE"],
},
```

- [x] **Step 6: Update install and evidence assertions**

In `install-agent-harness.sh`, add:

```bash
if [ -f "$schema_root/failure-attribution.schema.json" ]; then
  copy_path \
    "$schema_root/failure-attribution.schema.json" \
    "$target/schemas/failure-attribution.schema.json"
fi
```

In `tests/harness/lib.sh`, add:

```bash
failure-attribution-result.txt
```

and finish-summary assertions:

```bash
assert_file_contains "$root" "finish-summary.md" "| check-failure-attribution |"
assert_file_contains "$root" "finish-summary.md" "failure-attribution-result.txt"
```

- [x] **Step 7: Run tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

Verified locally on 2026-06-04 with `bash validate-harness.sh`.
Result: PASS, with Ruby unavailable warnings for optional YAML/JSON syntax checks.

- [ ] **Step 8: Commit**

```bash
git add schemas/failure-attribution.schema.json templates/.agent/failure-attribution.yml templates/.agent/task.yml templates/scripts/check-failure-attribution.sh templates/scripts/agent-finish.sh schemas/task.schema.json templates/scripts/validate-task.sh tests/harness/failure-attribution.sh tests/harness/lib.sh validate-harness.sh install-agent-harness.sh
git commit -m "feat: add failure attribution gate"
```

### Task 3: Intervention Recording

**Files:**
- Create: `schemas/interventions.schema.json`
- Create: `templates/.agent/interventions.yml`
- Create: `templates/scripts/check-interventions.sh`
- Create: `tests/harness/interventions.sh`
- Modify: `templates/.agent/task.yml`
- Modify: `schemas/task.schema.json`
- Modify: `templates/scripts/agent-finish.sh`
- Modify: `tests/harness/lib.sh`
- Modify: `validate-harness.sh`
- Modify: `install-agent-harness.sh`

- [ ] **Step 1: Write failing intervention tests**

Create `tests/harness/interventions.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Intervention evidence skip semantics =="
interventions_skip_root="$tmp_root/interventions-skip"
rm -rf "$interventions_skip_root"
mkdir -p "$interventions_skip_root/.agent" "$interventions_skip_root/scripts/lib"
(
  cd "$interventions_skip_root"
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: false' \
    > .agent/task.yml
  bash scripts/check-interventions.sh > interventions-skip.log 2>&1
  assert_contains interventions-skip.log "Intervention record is not required."
  assert_contains interventions-skip.log "INTERVENTIONS_RESULT=pass"
)
pass "intervention evidence skip semantics"

echo
echo "== Intervention evidence required and valid =="
interventions_pass_root="$tmp_root/interventions-pass"
rm -rf "$interventions_pass_root"
mkdir -p "$interventions_pass_root/.agent" "$interventions_pass_root/scripts/lib"
(
  cd "$interventions_pass_root"
  cp "$repo_root/templates/.agent/interventions.yml" .agent/interventions.yml
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: true' \
    > .agent/task.yml
  bash scripts/check-interventions.sh > interventions-pass.log 2>&1
  assert_contains interventions-pass.log "Intervention record is required."
  assert_contains interventions-pass.log "OK: intervention 0"
  assert_contains interventions-pass.log "INTERVENTIONS_RESULT=pass"
)
pass "intervention evidence required and valid"

echo
echo "== Intervention evidence required and missing actor =="
interventions_bad_root="$tmp_root/interventions-bad"
rm -rf "$interventions_bad_root"
mkdir -p "$interventions_bad_root/.agent" "$interventions_bad_root/scripts/lib"
(
  cd "$interventions_bad_root"
  cp "$repo_root/templates/scripts/check-interventions.sh" scripts/check-interventions.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'task:' \
    '  completion:' \
    '    requires_intervention_record: true' \
    > .agent/task.yml
  printf '%s\n' \
    'interventions:' \
    '  required: true' \
    '  entries:' \
    '    - timestamp: "2026-06-03T00:00:00Z"' \
    '      type: "approval"' \
    '      summary: "Approved high-risk change."' \
    > .agent/interventions.yml
  if bash scripts/check-interventions.sh > interventions-bad.log 2>&1; then
    echo "ERROR: expected intervention gate failure"
    exit 1
  fi
  assert_contains interventions-bad.log "entries[0].actor must be non-empty"
  assert_contains interventions-bad.log "INTERVENTIONS_RESULT=fail"
)
pass "intervention evidence required and missing actor"
```

Source it in `validate-harness.sh` after `failure-attribution.sh`:

```bash
source "$repo_root/tests/harness/interventions.sh"
```

- [ ] **Step 2: Add intervention schema and template**

Create `schemas/interventions.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agent-repo-harness.local/schemas/interventions.schema.json",
  "title": "Intervention log",
  "type": "object",
  "required": ["interventions"],
  "properties": {
    "interventions": {
      "type": "object",
      "required": ["required", "entries"],
      "properties": {
        "required": { "type": "boolean" },
        "entries": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["timestamp", "actor", "type", "summary"],
            "properties": {
              "timestamp": { "type": "string", "minLength": 1 },
              "actor": { "type": "string", "minLength": 1 },
              "type": {
                "type": "string",
                "enum": ["approval", "scope_change", "blocker_resolution", "manual_verification", "runtime_override"]
              },
              "summary": { "type": "string", "minLength": 1 },
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

Create `templates/.agent/interventions.yml`:

```yaml
interventions:
  required: false
  entries:
    - timestamp: "2026-06-03T00:00:00Z"
      actor: "local-agent"
      type: "manual_verification"
      summary: "No human intervention required for the default template."
      evidence: "Template entry; replace when intervention evidence is required."
```

- [ ] **Step 3: Add intervention gate**

Create `templates/scripts/check-interventions.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

task_file="${TASK_FILE:-.agent/task.yml}"
interventions_file="${INTERVENTIONS_FILE:-.agent/interventions.yml}"
reader="scripts/lib/read-yaml.py"
failures=0

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

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for intervention checks"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

read_value() {
  "$python_bin" "$reader" "$1" "$2" --optional 2>/dev/null || true
}

required="$(read_value "$task_file" "task.completion.requires_intervention_record")"
if [ "$required" != "true" ]; then
  echo "Intervention record is not required."
  echo "INTERVENTIONS_RESULT=pass"
  exit 0
fi

echo "Intervention record is required."

if [ ! -f "$interventions_file" ]; then
  echo "ERROR: missing $interventions_file"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

entries_json="$("$python_bin" "$reader" "$interventions_file" "interventions.entries" --json --optional 2>/dev/null || true)"
if [ -z "$entries_json" ] || [ "$entries_json" = "null" ]; then
  echo "ERROR: interventions.entries must contain at least one entry"
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

INTERVENTIONS_JSON="$entries_json" "$python_bin" - <<'PY'
import json
import os
import sys

entries = json.loads(os.environ["INTERVENTIONS_JSON"])
if not isinstance(entries, list) or not entries:
    print("ERROR: interventions.entries must contain at least one entry")
    sys.exit(1)

allowed = {"approval", "scope_change", "blocker_resolution", "manual_verification", "runtime_override"}
failures = 0
for index, entry in enumerate(entries):
    if not isinstance(entry, dict):
        print(f"ERROR: entries[{index}] must be a map")
        failures += 1
        continue
    for key in ("timestamp", "actor", "type", "summary"):
        if not str(entry.get(key, "")).strip():
            print(f"ERROR: entries[{index}].{key} must be non-empty")
            failures += 1
    if entry.get("type") and entry.get("type") not in allowed:
        print(f"ERROR: entries[{index}].type has unsupported value: {entry.get('type')}")
        failures += 1
    if failures == 0:
        print(f"OK: intervention {index}")

sys.exit(1 if failures else 0)
PY
status=$?

if [ "$status" -ne 0 ]; then
  echo "INTERVENTIONS_RESULT=fail"
  exit 1
fi

echo "INTERVENTIONS_RESULT=pass"
```

- [ ] **Step 4: Add task flag, finish wiring, install wiring, and tests**

Use the same pattern as Task 2:

In `templates/.agent/task.yml`:

```yaml
    requires_intervention_record: false
```

In `schemas/task.schema.json`:

```json
"requires_intervention_record": { "type": "boolean" }
```

In `templates/scripts/validate-task.sh`:

```bash
check_optional_bool "task.completion.requires_intervention_record"
```

In `templates/scripts/agent-finish.sh`, add result file, status variable, `run_gate`, summary row, JSON environment variables, and JSON gate entry named `check-interventions`.

In `install-agent-harness.sh`, copy `schemas/interventions.schema.json` into target repos.

In `tests/harness/lib.sh`, add `interventions-result.txt` evidence assertions and require `check-interventions` in `finish-summary.json`.

- [ ] **Step 5: Run tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add schemas/interventions.schema.json templates/.agent/interventions.yml templates/.agent/task.yml templates/scripts/check-interventions.sh templates/scripts/agent-finish.sh schemas/task.schema.json templates/scripts/validate-task.sh tests/harness/interventions.sh tests/harness/lib.sh validate-harness.sh install-agent-harness.sh
git commit -m "feat: add intervention evidence gate"
```

### Task 4: Entropy Audit Command

**Files:**
- Create: `templates/scripts/agent-audit.sh`
- Create: `tests/harness/entropy-audit.sh`
- Modify: `templates/.agent/harness.yml`
- Modify: `schemas/harness.schema.json`
- Modify: `templates/scripts/agent-preflight.sh`
- Modify: `validate-harness.sh`
- Modify: `tests/harness/static-install.sh`
- Modify: `tests/harness/template-sync.sh`

- [ ] **Step 1: Write failing audit tests**

Create `tests/harness/entropy-audit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Entropy audit report =="
audit_root="$tmp_root/entropy-audit"
rm -rf "$audit_root"
mkdir -p "$audit_root/.agent" "$audit_root/scripts/lib" "$audit_root/docs"
git init -q "$audit_root"
(
  cd "$audit_root"
  cp "$repo_root/templates/scripts/agent-audit.sh" scripts/agent-audit.sh
  cp "$repo_root/templates/scripts/check-doc-links.sh" scripts/check-doc-links.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/.agent/harness.yml" .agent/harness.yml
  chmod +x scripts/*.sh
  printf '%s\n' '# Audit Fixture' > README.md
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .
  git commit -q -m "Add audit fixture"
  bash scripts/agent-audit.sh > audit.log 2>&1
  assert_contains audit.log "AGENT_AUDIT_RESULT=pass"
  audit_json="$(find .agent/audits -type f -name "entropy-report.json" | sort | tail -n 1)"
  audit_md="$(find .agent/audits -type f -name "entropy-report.md" | sort | tail -n 1)"
  assert_exists "$audit_json"
  assert_exists "$audit_md"
  assert_contains "$audit_md" "## Audit Checks"
  "$(find_python)" - "$audit_json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
required = {"timestamp", "overall_result", "checks", "evidence"}
missing = required.difference(data)
if missing:
    raise SystemExit(f"missing audit keys: {sorted(missing)}")
names = {check["name"] for check in data["checks"]}
for expected in ("doc-links", "git-status", "harness-config"):
    if expected not in names:
        raise SystemExit(f"missing audit check: {expected}")
PY
)
pass "entropy audit report"
```

Source it near the end of `validate-harness.sh`:

```bash
source "$repo_root/tests/harness/entropy-audit.sh"
```

Expected first run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `templates/scripts/agent-audit.sh` does not exist.

- [ ] **Step 2: Add audit config**

In `templates/.agent/harness.yml`, add:

```yaml
audit:
  command: scripts/agent-audit.sh
  evidence_dir: .agent/audits
  checks:
    - doc-links
    - git-status
    - harness-config
```

In `schemas/harness.schema.json`, add:

```json
"audit": {
  "type": "object",
  "properties": {
    "command": { "type": "string" },
    "evidence_dir": { "type": "string" },
    "checks": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "additionalProperties": true
}
```

- [ ] **Step 3: Add audit script**

Create `templates/scripts/agent-audit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
audit_dir=".agent/audits/$timestamp"
report_md="$audit_dir/entropy-report.md"
report_json="$audit_dir/entropy-report.json"
mkdir -p "$audit_dir"

failures=0
doc_links_status=0
git_status_status=0
harness_config_status=0

run_check() {
  local label="$1"
  local output_file="$audit_dir/$label.txt"
  shift

  set +e
  "$@" >"$output_file" 2>&1
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    failures=$((failures + 1))
  fi

  printf '%s\n' "$status"
}

if [ -f scripts/check-doc-links.sh ]; then
  doc_links_status="$(run_check doc-links bash scripts/check-doc-links.sh)"
else
  printf '%s\n' "SKIP: scripts/check-doc-links.sh not found" > "$audit_dir/doc-links.txt"
  doc_links_status=0
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_status_status="$(run_check git-status git status --short)"
else
  printf '%s\n' "SKIP: not inside a git repository" > "$audit_dir/git-status.txt"
  git_status_status=0
fi

if [ -f .agent/harness.yml ] && [ -f scripts/validate-config.sh ]; then
  harness_config_status="$(run_check harness-config bash scripts/validate-config.sh)"
else
  printf '%s\n' "SKIP: harness config validation unavailable" > "$audit_dir/harness-config.txt"
  harness_config_status=0
fi

overall_result="pass"
if [ "$failures" -gt 0 ]; then
  overall_result="fail"
fi

{
  echo "# Agent Entropy Audit"
  echo
  echo "- Timestamp: $timestamp"
  echo "- Overall result: $overall_result"
  echo "- Audit directory: $audit_dir"
  echo
  echo "## Audit Checks"
  echo
  echo "| Check | Exit status | Evidence |"
  echo "| --- | ---: | --- |"
  echo "| doc-links | $doc_links_status | $audit_dir/doc-links.txt |"
  echo "| git-status | $git_status_status | $audit_dir/git-status.txt |"
  echo "| harness-config | $harness_config_status | $audit_dir/harness-config.txt |"
} > "$report_md"

REPORT_JSON="$report_json" \
AUDIT_TIMESTAMP="$timestamp" \
AUDIT_RESULT="$overall_result" \
AUDIT_DIR="$audit_dir" \
DOC_LINKS_STATUS="$doc_links_status" \
GIT_STATUS_STATUS="$git_status_status" \
HARNESS_CONFIG_STATUS="$harness_config_status" \
python3 - <<'PY'
import json
import os
from pathlib import Path

data = {
    "timestamp": os.environ["AUDIT_TIMESTAMP"],
    "overall_result": os.environ["AUDIT_RESULT"],
    "audit_dir": os.environ["AUDIT_DIR"],
    "checks": [
        {"name": "doc-links", "exit_status": int(os.environ["DOC_LINKS_STATUS"]), "evidence": f'{os.environ["AUDIT_DIR"]}/doc-links.txt'},
        {"name": "git-status", "exit_status": int(os.environ["GIT_STATUS_STATUS"]), "evidence": f'{os.environ["AUDIT_DIR"]}/git-status.txt'},
        {"name": "harness-config", "exit_status": int(os.environ["HARNESS_CONFIG_STATUS"]), "evidence": f'{os.environ["AUDIT_DIR"]}/harness-config.txt'}
    ],
    "evidence": {
        "markdown_report": f'{os.environ["AUDIT_DIR"]}/entropy-report.md'
    }
}
Path(os.environ["REPORT_JSON"]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "AGENT_AUDIT_RESULT=$overall_result"
echo "Audit directory: $audit_dir"

if [ "$overall_result" = "fail" ]; then
  exit 1
fi
```

- [ ] **Step 4: Replace hardcoded python3**

Before committing, replace the final `python3` call in `agent-audit.sh` with the repo's `find_python` helper pattern used in other scripts:

```bash
python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "ERROR: python is required for audit JSON writes"
  exit 1
fi
```

Then invoke:

```bash
"$python_bin" - <<'PY'
```

- [ ] **Step 5: Add preflight discovery**

In `templates/scripts/agent-preflight.sh`, add:

```bash
echo
echo "== Audit command =="
if [ -f scripts/agent-audit.sh ]; then
  echo "FOUND scripts/agent-audit.sh"
else
  echo "SKIP: scripts/agent-audit.sh not found"
fi
```

- [ ] **Step 6: Run tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add templates/scripts/agent-audit.sh templates/.agent/harness.yml schemas/harness.schema.json templates/scripts/agent-preflight.sh tests/harness/entropy-audit.sh tests/harness/static-install.sh tests/harness/template-sync.sh validate-harness.sh
git commit -m "feat: add entropy audit command"
```

### Task 5: Documentation And Adapter Lifecycle Alignment

**Files:**
- Create: `docs/agent/episode-package.md`
- Create: `docs/agent/failure-attribution.md`
- Create: `docs/agent/interventions.md`
- Create: `docs/agent/entropy-audit.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/runtime-boundaries.md`
- Modify: `docs/public-packaging.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `templates/agent.md`
- Modify: `adapters/codex/codex-start-prompt.md`
- Modify: `adapters/codex/codex-verify-prompt.md`
- Modify: `adapters/codex/codex-repair-prompt.md`
- Modify: `adapters/codex/codex-handoff-prompt.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/adapter-sync.sh`

- [ ] **Step 1: Write failing doc consistency assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_exists "$repo_root/docs/agent/episode-package.md"
assert_exists "$repo_root/docs/agent/failure-attribution.md"
assert_exists "$repo_root/docs/agent/interventions.md"
assert_exists "$repo_root/docs/agent/entropy-audit.md"
assert_contains "$repo_root/README.md" "episode-summary.json"
assert_contains "$repo_root/README.md" "scripts/agent-audit.sh"
assert_contains "$repo_root/docs/runtime-boundaries.md" "episode package"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Failure attribution"
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/episode-package.md"
assert_contains "$repo_root/templates/AGENTS.md" "scripts/agent-audit.sh"
```

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL in doc consistency.

- [ ] **Step 2: Add episode package docs**

Create `docs/agent/episode-package.md`:

```markdown
# Episode Package

The episode package is the durable evidence bundle for one agent work episode.
It is local to the repository and does not replace an external sandbox,
runtime, or CI system.

## Inputs

- `.agent/task.yml`: scope and completion requirements.
- `.agent/episode.yml`: episode id, objective, actor, status, and loaded context.
- `.agent/policy.yml`: local policy rules.
- `.agent/harness.yml`: configured scripts, verification, resource limits, and audit command.

## Outputs

- `.agent/runs/<timestamp>/finish-summary.md`
- `.agent/runs/<timestamp>/finish-summary.json`
- `.agent/runs/<timestamp>/episode-summary.json`
- `.agent/runs/<timestamp>/*-result.txt`
- `.agent/runs/<timestamp>/changed-files.txt`
- `.agent/runs/<timestamp>/git-diff-stat.txt`

## Rule

Use `finish-summary.json` for completion status automation. Use
`episode-summary.json` to find the contracts and evidence files that belong to
the episode.
```

- [ ] **Step 3: Add failure attribution docs**

Create `docs/agent/failure-attribution.md`:

```markdown
# Failure Attribution

Failure attribution records why a gate or verification command failed, what
evidence supports that diagnosis, and what repair was applied.

Enable it per task:

```yaml
task:
  completion:
    requires_failure_attribution: true
```

When enabled, fill `.agent/failure-attribution.yml` before claiming completion.

Required fields:

- `failure_attribution.status`
- `failure_attribution.root_cause`
- `failure_attribution.evidence`
- `failure_attribution.repair`

The finish gate records the result in
`.agent/runs/<timestamp>/failure-attribution-result.txt`.
```

- [ ] **Step 4: Add intervention docs**

Create `docs/agent/interventions.md`:

```markdown
# Interventions

Interventions record meaningful human or runtime changes to the episode:
approvals, scope changes, blocker resolutions, manual verification, and runtime
overrides.

Enable it per task:

```yaml
task:
  completion:
    requires_intervention_record: true
```

When enabled, `.agent/interventions.yml` must contain at least one entry with:

- `timestamp`
- `actor`
- `type`
- `summary`

Use this file for durable intervention evidence. Do not use it to invent
approval that was not explicitly given.
```

- [ ] **Step 5: Add entropy audit docs**

Create `docs/agent/entropy-audit.md`:

```markdown
# Entropy Audit

Run:

```bash
bash scripts/agent-audit.sh
```

The audit writes:

- `.agent/audits/<timestamp>/entropy-report.md`
- `.agent/audits/<timestamp>/entropy-report.json`
- per-check text evidence files

The audit is an operational maintenance report. It is not a replacement for
`scripts/agent-finish.sh`.
```

- [ ] **Step 6: Update public README wording**

In `README.md`, add this concise section after Evidence And Optional Gates:

```markdown
## Episode And Audit Evidence

The harness can record an episode package for a task through `.agent/episode.yml`
and `.agent/runs/<timestamp>/episode-summary.json`. This package links the task,
policy, harness config, finish summary, changed files, and gate evidence for a
single agent work episode.

For maintenance checks, run:

```bash
bash scripts/agent-audit.sh
```

The audit writes `.agent/audits/<timestamp>/entropy-report.json` and a Markdown
report. It checks local harness drift signals; it does not provide sandboxing,
secret isolation, or model-cost accounting.
```

Mirror the same section in `README.zh-TW.md` with Traditional Chinese wording.

- [ ] **Step 7: Update runtime boundary docs**

In `docs/runtime-boundaries.md`, add under Implemented:

```markdown
- Optional episode package metadata and generated `episode-summary.json`.
- Optional failure-attribution and intervention evidence gates.
- Local entropy audit reports through `scripts/agent-audit.sh`.
```

Add under Not Implemented:

```markdown
- Full tool-call replay outside evidence explicitly written by local scripts.
- Provider-native trace capture unless an external runtime supplies it.
```

- [ ] **Step 8: Update agent entrypoints and adapter prompts**

In `templates/AGENTS.md`, add before completion:

```markdown
- If `.agent/episode.yml` is present, keep its status and objective aligned with
  the current task.
- If failure attribution or intervention evidence is required by
  `.agent/task.yml`, fill the matching `.agent/*.yml` file before finish.
- For maintenance checks, run `scripts/agent-audit.sh`; do not treat audit as a
  substitute for `scripts/agent-finish.sh`.
```

In `adapters/codex/codex-repair-prompt.md`, add:

```markdown
When a gate failure needs diagnosis, record the root cause, evidence, repair,
and verification in `.agent/failure-attribution.yml` if the task requires
failure attribution evidence.
```

In `adapters/codex/codex-handoff-prompt.md`, add:

```markdown
Include the latest `.agent/runs/<timestamp>/episode-summary.json` path when it
exists, plus any required intervention or failure-attribution evidence.
```

- [ ] **Step 9: Run docs and adapter tests**

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add docs/agent/episode-package.md docs/agent/failure-attribution.md docs/agent/interventions.md docs/agent/entropy-audit.md README.md README.zh-TW.md docs/USAGE_WITH_AGENTS.md docs/runtime-boundaries.md docs/public-packaging.md templates/AGENTS.md templates/CLAUDE.md templates/agent.md adapters/codex/codex-start-prompt.md adapters/codex/codex-verify-prompt.md adapters/codex/codex-repair-prompt.md adapters/codex/codex-handoff-prompt.md tests/harness/doc-consistency.sh tests/harness/adapter-sync.sh
git commit -m "docs: document h3 harness workflows"
```

### Task 6: Final Integration And Public Baseline

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/public-packaging.md`
- Modify: `handoff.md`

- [ ] **Step 1: Run full validation**

```bash
bash validate-harness.sh
```

Expected: PASS with these suites present:

- Episode metadata validation
- Failure attribution skip/required tests
- Intervention evidence skip/required tests
- Entropy audit report
- Existing finish, resource envelope, architecture, acceptance, review, subagent, policy, scope, doc, adapter, and template suites

- [ ] **Step 2: Run a local finish gate**

```bash
bash scripts/agent-finish.sh --best-effort
```

Expected: `AGENT_FINISH_RESULT=pass` or a clear failure caused by current repo task state. If it fails because the live repo task state intentionally requires evidence not filled in this planning branch, record the failing run path and reason in `handoff.md`.

- [ ] **Step 3: Update changelog**

Add this under `CHANGELOG.md` Unreleased section:

```markdown
## Unreleased

- Add optional episode package metadata and generated `episode-summary.json`.
- Add optional failure attribution and intervention evidence gates.
- Add `scripts/agent-audit.sh` for local entropy audit reports.
- Document H3-style harness workflows while preserving the repo-local runtime boundary.
```

- [ ] **Step 4: Update handoff**

Update `handoff.md` with:

```markdown
## Current State

Implemented the H3 runtime harness roadmap plan through episode package,
failure attribution, intervention recording, entropy audit, and documentation
alignment tasks.

## Verification

- `bash validate-harness.sh`: PASS
- `bash scripts/agent-finish.sh --best-effort`: PASS

## Evidence

- Latest finish run: `.agent/runs/<timestamp>/`
- Latest audit run: `.agent/audits/<timestamp>/`

## Next Action

Review the generated episode and audit evidence, then decide whether to package
the changes as the next minor release.
```

Replace `<timestamp>` with the actual run directories from Step 1 and Step 2.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md docs/public-packaging.md handoff.md
git commit -m "chore: finalize h3 harness roadmap integration"
```

## Self-Review

Spec coverage:

- Episode package: Task 1 and Task 5.
- Failure attribution: Task 2 and Task 5.
- Intervention recording: Task 3 and Task 5.
- Entropy audit: Task 4 and Task 5.
- Runtime boundary honesty: Task 5.
- Validation evidence: Task 6.

Placeholder scan:

- The plan does not rely on undefined files without a create step.
- The plan avoids unspecified validation commands.
- Each new contract has a schema, template, script, test suite, install wiring, and docs.

Type consistency:

- Task flags use `requires_failure_attribution` and `requires_intervention_record` consistently.
- Evidence files use `failure-attribution-result.txt`, `interventions-result.txt`, and `episode-summary.json` consistently.
- Audit output uses `.agent/audits/<timestamp>/entropy-report.json` and `.agent/audits/<timestamp>/entropy-report.md` consistently.

## Execution Options

Plan complete and saved to `docs/superpowers/plans/2026-06-03-h3-runtime-harness-roadmap.md`.

1. **Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fastest feedback.
2. **Inline Execution** - execute tasks in this session using `superpowers:executing-plans`, batching with review checkpoints.
