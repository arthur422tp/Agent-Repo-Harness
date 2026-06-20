# Harness Ergonomics And Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce harness adoption and operating complexity through a canonical gate guide, documentation-only profiles, shorter entrypoint documentation, and grouped human-readable finish summaries.

**Architecture:** Preserve every existing task flag, gate, evidence file, execution order, and `finish-summary.json` contract. Consolidate gate-selection detail into a canonical guide mirrored into installed templates, replace duplicated README/usage detail with profile-based navigation, and group only the Markdown finish summary into Core Guardrails, Optional Evidence, and Verification And Limits.

**Tech Stack:** Markdown, POSIX-ish Bash, Python standard library, existing `tests/harness/*.sh` suites, existing installer/template sync workflow.

---

## Approved Spec

Design source:

- `docs/superpowers/specs/2026-06-20-harness-ergonomics-simplification-design.md`

Hard constraints:

- Do not add or remove completion flags.
- Do not add or remove finish gates.
- Do not add a profile field or runtime profile engine.
- Do not change JSON finish-summary keys, gate names, ordering, statuses, or evidence paths.
- Do not change gate execution order, installer behavior, or strict/best-effort semantics.

## File Structure

Create:

- `docs/agent/gate-guide.md`: canonical public gate-selection guide and documentation-only profiles.
- `templates/docs/agent/gate-guide.md`: installed mirror of the canonical guide.

Modify:

- `tests/harness/doc-consistency.sh`: require the gate guide, profiles, flag coverage, and navigation links.
- `tests/harness/template-sync.sh`: require the public and installed gate guides to match.
- `tests/harness/static-install.sh`: require the installed gate guide.
- `README.md`: replace detailed gate catalog content with profile chooser and canonical guide links.
- `README.zh-TW.md`: mirror concise profile guidance and gate-guide navigation.
- `docs/USAGE_WITH_AGENTS.md`: focus on lifecycle and adapters; link detailed gate selection to the guide.
- `docs/agent-support-matrix.md`: direct supported agents to the gate guide instead of naming only selected gates.
- `templates/AGENTS.md`: add concise gate-guide navigation.
- `templates/CLAUDE.md`: add concise gate-guide navigation.
- `skills/verification-gate/SKILL.md`: link to the installed guide for gate selection.
- `templates/scripts/agent-finish.sh`: group Markdown summary rows only.
- `tests/harness/lib.sh`: assert group headings, one occurrence per gate row, and unchanged JSON contract.
- `CHANGELOG.md`: record the ergonomics and summary presentation update.
- `handoff.md`: record final validation and remaining next action.

## Task 1: Canonical Gate Guide Contract

**Files:**
- Create: `docs/agent/gate-guide.md`
- Create: `templates/docs/agent/gate-guide.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/template-sync.sh`
- Modify: `tests/harness/static-install.sh`

- [x] **Step 1: Add failing gate-guide consistency assertions**

In `tests/harness/doc-consistency.sh`, add these assertions after the existing
agent evidence doc checks:

```bash
assert_exists "$repo_root/docs/agent/gate-guide.md"
assert_contains "$repo_root/docs/agent/gate-guide.md" "# Gate Guide"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Minimal Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Standard Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## High-Risk Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "Profiles are recommendations"

completion_flags="$(
  awk '
    /^  completion:/ { in_completion = 1; next }
    in_completion && /^[^ ]/ { in_completion = 0 }
    in_completion && $1 ~ /^(requires_|expects_)/ {
      flag = $1
      sub(/:$/, "", flag)
      print flag
    }
  ' "$repo_root/templates/.agent/task.yml"
)"

while IFS= read -r flag; do
  [ -n "$flag" ] || continue
  assert_contains "$repo_root/docs/agent/gate-guide.md" "$flag"
done <<EOF
$completion_flags
EOF
```

This dynamically requires every current completion flag to appear in the
canonical guide without hard-coding a second flag list in the test.

- [x] **Step 2: Add failing template and install assertions**

In `tests/harness/template-sync.sh`, add:

```bash
assert_exists "$repo_root/templates/docs/agent/gate-guide.md"
assert_files_match \
  "$repo_root/docs/agent/gate-guide.md" \
  "$repo_root/templates/docs/agent/gate-guide.md"
```

In `tests/harness/static-install.sh`, add `docs/agent/gate-guide.md` to both the
source required-path list and installed required-path list.

- [x] **Step 3: Run validation to verify the guide is missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because `docs/agent/gate-guide.md` and its installed mirror do
not exist.

- [x] **Step 4: Create the canonical gate guide**

Create `docs/agent/gate-guide.md` with this structure and content:

````markdown
# Gate Guide

Use this guide to choose existing Agent-Repo-Harness completion gates. Profiles
are recommendations expressed through existing `.agent/task.yml` flags. The
harness does not read a profile name or enable flags automatically.

## Minimal Profile

Use for small, low-risk maintenance work.

```yaml
completion:
  requires_scope_check: true
  requires_policy_check: true
  requires_verification: true
  expects_handoff_update: true
  requires_tdd_evidence: false
  requires_acceptance_check: false
  requires_review_evidence: false
  requires_architecture_evidence: false
  requires_failure_attribution: false
  requires_intervention_record: false
  requires_command_ledger: false
  requires_sandbox_verification: false
  requires_subagent_evidence: false
```

## Standard Profile

Use for normal feature, bug-fix, refactoring, and behavior-change work. Start
with Minimal, set `requires_tdd_evidence: true` for behavior changes, and enable
acceptance or review evidence when the task contract requires them.

```yaml
completion:
  requires_scope_check: true
  requires_policy_check: true
  requires_verification: true
  expects_handoff_update: true
  requires_tdd_evidence: true
  requires_acceptance_check: true
  requires_review_evidence: false
  requires_architecture_evidence: false
  requires_failure_attribution: false
  requires_intervention_record: false
  requires_command_ledger: false
  requires_sandbox_verification: false
  requires_subagent_evidence: false
```

## High-Risk Profile

Use for security-sensitive, architectural, release-critical, delegated, or
environment-sensitive work. Start with Standard and enable only the additional
evidence that matches the actual risk.

Start with the Standard completion block. Add only the applicable entries from
this menu:

```yaml
completion:
  requires_review_evidence: true          # independent approval required
  requires_architecture_evidence: true    # design invariants need evidence
  requires_failure_attribution: true      # repaired failure needs root cause
  requires_intervention_record: true      # material approval or override used
  requires_command_ledger: true           # important commands need replay evidence
  requires_sandbox_verification: true     # isolated final verification required
  requires_subagent_evidence: true        # delegated execution must be proven
```

High-Risk is a menu, not a requirement to enable every optional gate. Enable a
gate only when its evidence answers a real completion risk.

## Gate Decision Matrix

| Check | Task flag | Default | Enable when | Evidence / command | Failure means |
| --- | --- | --- | --- | --- | --- |
| Agent map | none | always | every finish run | `agent.md`; `check-agent-md.sh` | stable repo map is invalid |
| Scope | `requires_scope_check` | true | changes must stay inside task paths or limits | `.agent/task.yml`; `check-scope.sh` | changed files exceed task scope |
| Policy | `requires_policy_check` | true | protected paths or approvals matter | `.agent/policy.yml`; `check-policy.sh` | repo policy is violated |
| Verification | `requires_verification` | true | every task that claims completion | `.agent/harness.yml`; `agent-verify.sh` | configured checks failed |
| Handoff expectation | `expects_handoff_update` | true | continuity state should be updated | `handoff.md` | advisory only; finish does not enforce freshness |
| TDD evidence | `requires_tdd_evidence` | false | feature, bug-fix, refactor, or behavior change needs red/green proof | `.agent/tdd-evidence.yml`; `check-tdd-evidence.sh` | required TDD evidence is incomplete |
| Acceptance | `requires_acceptance_check` | false | explicit user-visible criteria must be proven | `.agent/acceptance.yml`; `check-acceptance.sh` | criteria are unmet or lack evidence |
| Review | `requires_review_evidence` | false | independent approval is required | `.agent/review.yml`; `check-review-evidence.sh` | review is missing or blocking |
| Architecture | `requires_architecture_evidence` | false | tests cannot prove design invariants | `.agent/architecture.yml`; `check-architecture-evidence.sh` | required invariants are not upheld |
| Failure attribution | `requires_failure_attribution` | false | repaired or recurring failures need root-cause evidence | `.agent/failure-attribution.yml`; `check-failure-attribution.sh` | attribution evidence is incomplete |
| Interventions | `requires_intervention_record` | false | approvals, overrides, or manual actions materially changed the run | `.agent/interventions.yml`; `check-interventions.sh` | intervention record is incomplete |
| Command ledger | `requires_command_ledger` | false | important local commands need replayable evidence | `.agent/command-runs/`; `agent-run.sh` | ledger evidence is missing or malformed |
| Sandbox verification | `requires_sandbox_verification` | false | final verification must run in an external container boundary | `.agent/sandbox-runs/`; `agent-sandbox-run.sh` | passing sandbox evidence is missing |
| Subagent evidence | `requires_subagent_evidence` | false | delegated execution must be proven | `.agent/subagent-runs/`; `check-subagent-evidence.sh` | delegated run evidence is missing or invalid |
| Episode metadata | none | validated when available | episode-level metadata is useful | `.agent/episode.yml`; `validate-episode.sh` | episode metadata is invalid |
| Resource envelope | harness config | disabled with zero limits | finish duration or changed-file count needs a local cap | `.agent/harness.yml`; `agent-finish.sh` | configured local limit was exceeded |

## Selection Rules

1. Start with Minimal.
2. Use Standard for behavior changes.
3. Add High-Risk gates only when they answer a named risk.
4. Do not enable evidence gates merely because they exist.
5. Record exceptions and material manual actions through existing intervention
   or handoff evidence instead of adding new gate types.
````

- [x] **Step 5: Mirror the guide into installed templates**

Run:

```bash
cp docs/agent/gate-guide.md templates/docs/agent/gate-guide.md
```

- [x] **Step 6: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for gate-guide existence, flag coverage, template sync, and
installed file assertions.

- [x] **Step 7: Commit**

```bash
git add docs/agent/gate-guide.md templates/docs/agent/gate-guide.md tests/harness/doc-consistency.sh tests/harness/template-sync.sh tests/harness/static-install.sh
git commit -m "docs: add canonical harness gate guide"
```

## Task 2: README And Usage Simplification

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`
- Modify: `docs/USAGE_WITH_AGENTS.md`
- Modify: `docs/agent-support-matrix.md`
- Modify: `tests/harness/doc-consistency.sh`

- [x] **Step 1: Add failing documentation navigation assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_contains "$repo_root/README.md" "## Choose A Gate Profile"
assert_contains "$repo_root/README.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/README.md" "Minimal"
assert_contains "$repo_root/README.md" "Standard"
assert_contains "$repo_root/README.md" "High-Risk"
assert_contains "$repo_root/README.md" "Profiles are recommendations"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇 Gate Profile"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "agent/gate-guide.md"
assert_contains "$repo_root/docs/agent-support-matrix.md" "agent/gate-guide.md"
```

Add negative assertions preventing the removed detailed catalog from returning
to the public README:

```bash
assert_not_contains "$repo_root/README.md" "## Architecture Evidence"
assert_not_contains "$repo_root/README.md" "## Episode And Audit Evidence"
```

- [x] **Step 2: Run validation to verify the profile chooser is absent**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because README and usage docs do not yet contain the new
profile-based navigation.

- [x] **Step 3: Add a concise profile chooser to README**

In `README.md`, insert after `## Verification Strategy`:

```markdown
## Choose A Gate Profile

Profiles are recommendations expressed through existing `.agent/task.yml`
flags; the harness does not read a profile name or enable gates automatically.

- **Minimal:** scope, policy, verification, and handoff expectation for small,
  low-risk maintenance.
- **Standard:** Minimal plus TDD for behavior changes, with acceptance or review
  evidence when the task requires it.
- **High-Risk:** Standard plus only the architecture, command ledger, sandbox,
  subagent, failure-attribution, or intervention evidence that answers a named
  risk.

See [Gate Guide](docs/agent/gate-guide.md) for the decision matrix, profile
examples, evidence files, and failure meanings.
```

- [x] **Step 4: Replace README's detailed optional-gate catalog**

Replace content from `## Evidence And Optional Gates` through the end of the
current architecture/subagent details, stopping before `## Useful Commands`,
with:

```markdown
## Evidence And Optional Gates

`agent-finish.sh` writes authoritative evidence under
`.agent/runs/<timestamp>/`, including `finish-summary.md`,
`finish-summary.json`, per-check result files, changed files, and diff stat.

Optional evidence gates remain disabled by default. Enable one only when it
answers a concrete completion risk. The available categories cover TDD,
acceptance, review, architecture, failure attribution, interventions, command
ledger, sandbox verification, and delegated subagent runs.

Use [Gate Guide](docs/agent/gate-guide.md) for detailed flag selection and
evidence requirements. See [Handoff And Evidence](docs/handoff.md) for the
difference between run evidence and continuity notes, and
[Runtime Boundaries](docs/runtime-boundaries.md) for containment and tracing
limits.
```

- [x] **Step 5: Mirror concise guidance in Traditional Chinese README**

Add this section after the verification strategy section in `README.zh-TW.md`:

```markdown
## 選擇 Gate Profile

Profiles 是使用現有 `.agent/task.yml` flags 的建議組合；harness 不會讀取
profile 名稱或自動啟用 gates。

- **Minimal：** 適合低風險維護，使用 scope、policy、verification 與 handoff
  expectation。
- **Standard：** 在 Minimal 之上，對行為變更加上 TDD，並依任務需求啟用
  acceptance 或 review evidence。
- **High-Risk：** 在 Standard 之上，只啟用能回答具體風險的 architecture、
  command ledger、sandbox、subagent、failure attribution 或 intervention
  evidence。

完整決策矩陣、profile 範例與 evidence 要求請見
[Gate Guide](docs/agent/gate-guide.md)。
```

Replace detailed optional-gate sections with a concise summary equivalent to
the English README while preserving the runtime-boundary links.

- [x] **Step 6: Refocus usage and support docs**

In `docs/USAGE_WITH_AGENTS.md`, add near `## Shared Pattern`:

```markdown
Choose completion gates through [Gate Guide](agent/gate-guide.md). Start with
Minimal, use Standard for behavior changes, and add High-Risk evidence only for
named risks. Profiles are documentation guidance, not runtime configuration.
```

Replace repeated detailed paragraphs for TDD, command ledger, sandbox,
failure-attribution, intervention, and subagent gate selection with short
workflow references to the guide. Preserve agent-specific commands, context
loading, evidence layouts, and adapter guidance.

In `docs/agent-support-matrix.md`, replace the opening gate sentence with:

```markdown
All supported agents use the same repo-local contracts and select completion
evidence through [Gate Guide](agent/gate-guide.md). Agent adapters change the
entrypoint, not the underlying task flags or finish semantics.
```

- [x] **Step 7: Run validation and inspect documentation size**

Run:

```bash
bash validate-harness.sh
wc -l README.md README.zh-TW.md docs/USAGE_WITH_AGENTS.md
```

Expected: validation PASS. Record line counts in the task notes; the combined
documents should not grow during this simplification task.

- [x] **Step 8: Commit**

```bash
git add README.md README.zh-TW.md docs/USAGE_WITH_AGENTS.md docs/agent-support-matrix.md tests/harness/doc-consistency.sh
git commit -m "docs: simplify harness gate selection"
```

## Task 3: Installed Entrypoint Navigation

**Files:**
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `skills/verification-gate/SKILL.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/template-sync.sh`

- [x] **Step 1: Add failing entrypoint navigation assertions**

In `tests/harness/doc-consistency.sh`, add:

```bash
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/templates/CLAUDE.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "docs/agent/gate-guide.md"
```

In `tests/harness/template-sync.sh`, add installed target assertions:

```bash
assert_contains "$target_root/AGENTS.md" "docs/agent/gate-guide.md"
assert_contains "$target_root/CLAUDE.md" "docs/agent/gate-guide.md"
```

- [x] **Step 2: Run validation to verify navigation is absent**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because installed entrypoints do not yet reference the guide.

- [x] **Step 3: Add concise entrypoint guidance**

In both `templates/AGENTS.md` and `templates/CLAUDE.md`, add near task setup or
verification guidance:

```markdown
- Choose optional completion evidence through `docs/agent/gate-guide.md`.
  Start with Minimal; add gates only for named task risks.
```

Do not copy the profile tables or per-gate explanations into these files.

- [x] **Step 4: Simplify verification skill guidance**

In `skills/verification-gate/SKILL.md`, add near the task flag instructions:

```markdown
Use `docs/agent/gate-guide.md` to choose optional evidence. Profiles are
recommendations; read the task's existing flags as the actual contract.
```

Retain command-specific instructions for running sandbox and command-ledger
evidence, but remove prose that duplicates the guide's enable/disable decision
rules.

- [x] **Step 5: Run validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS for source and installed entrypoint navigation.

- [x] **Step 6: Commit**

```bash
git add templates/AGENTS.md templates/CLAUDE.md skills/verification-gate/SKILL.md tests/harness/doc-consistency.sh tests/harness/template-sync.sh
git commit -m "docs: route agents through gate guide"
```

## Task 4: Group Human-Readable Finish Summary

**Files:**
- Modify: `tests/harness/lib.sh`
- Modify: `templates/scripts/agent-finish.sh`

- [ ] **Step 1: Add a reusable occurrence assertion**

In `tests/harness/lib.sh`, add after `assert_file_not_contains()`:

```bash
assert_file_occurrences() {
  local root="$1"
  local name="$2"
  local expected="$3"
  local expected_count="$4"
  local file
  local actual_count

  file="$(find "$root/.agent/runs" -type f -name "$name" | head -n 1)"
  if [ -z "$file" ]; then
    echo "ERROR: expected run evidence file named: $name"
    exit 1
  fi

  actual_count="$(grep -Fc -- "$expected" "$file" || true)"
  if [ "$actual_count" -ne "$expected_count" ]; then
    echo "ERROR: expected $expected_count occurrences of: $expected"
    echo "Actual: $actual_count"
    echo "File: $file"
    exit 1
  fi
}
```

- [ ] **Step 2: Add failing grouped-summary assertions**

In `assert_finish_summary_contract()`, add:

```bash
  assert_file_contains "$root" "finish-summary.md" "### Core Guardrails"
  assert_file_contains "$root" "finish-summary.md" "### Optional Evidence"
  assert_file_contains "$root" "finish-summary.md" "### Verification And Limits"
```

After the existing gate row assertions, add exactly-once checks:

```bash
  for gate in \
    check-agent-md \
    check-scope \
    check-policy \
    check-tdd-evidence \
    check-acceptance \
    check-review-evidence \
    check-architecture-evidence \
    check-failure-attribution \
    check-interventions \
    check-command-ledger \
    check-sandbox-evidence \
    check-subagent-evidence \
    validate-episode \
    agent-verify \
    resource-envelope
  do
    assert_file_occurrences "$root" "finish-summary.md" "| $gate |" 1
  done
```

Do not change `assert_finish_json_contract()`; its existing expected gate list
is the compatibility regression test.

- [ ] **Step 3: Run validation to verify headings are missing**

Run:

```bash
bash validate-harness.sh
```

Expected: FAIL because current `finish-summary.md` has one flat table and no
group headings.

- [ ] **Step 4: Group Markdown rows in `agent-finish.sh`**

In `write_summary()`, replace the single `## Gate Results` table block with:

```bash
    echo "## Gate Results"
    echo
    echo "### Core Guardrails"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| check-agent-md | $agent_md_status | $check_agent_md_result_file |"
    echo "| check-scope | $scope_status | $scope_result_file |"
    echo "| check-policy | $policy_status | $policy_result_file |"
    echo
    echo "### Optional Evidence"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| check-tdd-evidence | $tdd_evidence_status | $tdd_evidence_result_file |"
    echo "| check-acceptance | $acceptance_status | $acceptance_result_file |"
    echo "| check-review-evidence | $review_status | $review_result_file |"
    echo "| check-architecture-evidence | $architecture_status | $architecture_result_file |"
    echo "| check-failure-attribution | $failure_attribution_status | $failure_attribution_result_file |"
    echo "| check-interventions | $interventions_status | $interventions_result_file |"
    echo "| check-command-ledger | $command_ledger_status | $command_ledger_result_file |"
    echo "| check-sandbox-evidence | $sandbox_evidence_status | $sandbox_evidence_result_file |"
    echo "| check-subagent-evidence | $subagent_evidence_status | $subagent_evidence_result_file |"
    echo
    echo "### Verification And Limits"
    echo
    echo "| Check | Exit status | Evidence |"
    echo "| --- | ---: | --- |"
    echo "| validate-episode | $episode_status | $episode_result_file |"
    echo "| agent-verify | $verify_status | $verify_result_file |"
    echo "| resource-envelope | $resource_status | $resource_result_file |"
```

Do not edit `write_json_summary()` or the gate execution blocks.

- [ ] **Step 5: Run targeted and full validation**

Run:

```bash
bash validate-harness.sh
git diff -- templates/scripts/agent-finish.sh tests/harness/lib.sh
```

Expected: validation PASS. The diff must contain only Markdown summary rendering
and its assertions; JSON writer and gate execution order must be unchanged.

- [ ] **Step 6: Commit**

```bash
git add templates/scripts/agent-finish.sh tests/harness/lib.sh
git commit -m "refactor: group finish summary checks"
```

## Task 5: Final Alignment And Verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `handoff.md`
- Modify: `docs/superpowers/plans/2026-06-20-harness-ergonomics-simplification.md`

- [ ] **Step 1: Update changelog**

Under `## Unreleased` in `CHANGELOG.md`, add:

```markdown
- Add a canonical gate guide with Minimal, Standard, and High-Risk
  documentation profiles.
- Simplify public and installed gate-selection guidance.
- Group human-readable finish checks without changing the JSON evidence
  contract.
```

- [ ] **Step 2: Run full validation**

Run:

```bash
bash validate-harness.sh
```

Expected: PASS.

- [ ] **Step 3: Run doc-link validation**

Run:

```bash
bash templates/scripts/check-doc-links.sh .
```

Expected: `DOC_LINKS_RESULT=pass`.

- [ ] **Step 4: Run installed-target finish smoke**

Run:

```bash
target="/private/tmp/agent-harness-ergonomics-target"
rm -rf "$target"
mkdir -p "$target"
git init -q "$target"
bash install-agent-harness.sh --force "$target"
cd "$target"
git config user.email "agent-harness@example.invalid"
git config user.name "Agent Harness Smoke"
git add .
git commit -q -m "chore: install harness"
bash scripts/agent-finish.sh --best-effort
```

Expected:

- `AGENT_FINISH_RESULT=pass`
- installed `docs/agent/gate-guide.md` exists
- latest `finish-summary.md` contains `### Core Guardrails`
- latest `finish-summary.md` contains `### Optional Evidence`
- latest `finish-summary.md` contains `### Verification And Limits`
- latest `finish-summary.json` passes the unchanged test contract through the
  full validation suite

- [ ] **Step 5: Run source checkout audit**

Return to the source checkout and run:

```bash
cd /Users/arthuryu/Desktop/Agent-Repo-Harness
bash templates/scripts/agent-audit.sh
```

Expected: `AGENT_AUDIT_RESULT=pass`.

- [ ] **Step 6: Review simplification boundaries**

Run:

```bash
git diff HEAD~4 -- schemas templates/.agent templates/scripts/agent-finish.sh
```

Expected:

- no schema changes
- no task flag changes
- no new gate scripts
- `agent-finish.sh` changes are limited to Markdown summary grouping

- [ ] **Step 7: Update handoff**

Update `handoff.md` with actual results:

```markdown
## Current State

Harness ergonomics and simplification are complete. Gate-selection detail now
lives in `docs/agent/gate-guide.md`, Minimal/Standard/High-Risk profiles remain
documentation-only recommendations, public and installed entrypoints use
concise navigation, and the human-readable finish summary groups existing
checks without changing the JSON contract.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- Installed-target finish smoke: PASS in `/private/tmp/agent-harness-ergonomics-target`
- `bash templates/scripts/agent-audit.sh`: PASS

## Compatibility

- No completion flags, schemas, or gates added or removed.
- Gate execution order and strict/best-effort semantics unchanged.
- `finish-summary.json` contract unchanged.

## Next Action

Use the simplified profile guidance in real repositories and collect adoption
feedback before considering additional runtime or evidence capabilities.
```

- [ ] **Step 8: Mark this plan complete**

Mark completed steps `[x]` only after validation, smoke, audit, and handoff are
complete.

- [ ] **Step 9: Inspect final status**

Run:

```bash
git status --short
```

Expected: only intended tracked changes plus expected untracked `.agent/`
runtime evidence.

- [ ] **Step 10: Commit**

```bash
git add CHANGELOG.md handoff.md docs/superpowers/plans/2026-06-20-harness-ergonomics-simplification.md
git commit -m "chore: finalize harness ergonomics simplification"
```

## Self-Review

Spec coverage:

- Canonical gate guide and flag coverage: Task 1.
- Documentation-only profiles: Tasks 1 and 2.
- README and usage simplification: Task 2.
- Installed entrypoint navigation: Task 3.
- Grouped Markdown summary: Task 4.
- Unchanged JSON contract and execution behavior: Tasks 4 and 5.
- Final validation, installed smoke, audit, and handoff: Task 5.

Incomplete-content scan:

- No incomplete-content markers are intentionally left in this plan.

Type and name consistency:

- Profiles are consistently `Minimal`, `Standard`, and `High-Risk`.
- Canonical guide path is consistently `docs/agent/gate-guide.md`.
- Summary groups are consistently `Core Guardrails`, `Optional Evidence`, and
  `Verification And Limits`.
- Existing gate names and task flags are not renamed.

Plan complete and saved to `docs/superpowers/plans/2026-06-20-harness-ergonomics-simplification.md`.
