# Failed Run Repair Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give agents a deterministic repair protocol for failed `scripts/agent-finish.sh` runs and wire that protocol into adapter guidance and actionable failure messages.

**Architecture:** Add a repo-local repair document that maps each finish gate to its evidence file, likely causes, repair steps, and escalation condition. Then update adapter prompts and selected gate failure outputs to point agents at the exact evidence file and repair document without adding a new gate.

**Tech Stack:** Markdown docs, existing Bash gate scripts, existing adapter prompt files, harness doc-link and shell tests.

---

## Source Coverage

This plan implements Capability 4 from:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

It should run after:

- `docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md`

## File Structure

Create:

- `docs/agent/repair-failed-run.md`: canonical repair protocol for failed finish runs.
- `templates/docs/agent/repair-failed-run.md`: installed mirror.

Modify:

- `adapters/codex/AGENTS.md`: require repair protocol use after finish failure.
- `adapters/codex/codex-repair-prompt.md`: align prompt with the canonical protocol.
- `adapters/claude-code/CLAUDE.md`: require repair protocol use after finish failure.
- `templates/AGENTS.md`: installed agent guidance link.
- `templates/CLAUDE.md`: installed Claude guidance link.
- `README.md`: link the repair protocol from Evidence Vs Handoff or How It Works.
- `README.zh-TW.md`: mirror the link.
- `tests/harness/doc-consistency.sh`: assert source/template repair docs stay in sync.
- `tests/harness/adapter-sync.sh`: assert adapters mention the repair protocol.
- Selected scripts if needed: `templates/scripts/check-scope.sh`, `templates/scripts/check-policy.sh`, `templates/scripts/check-acceptance.sh`, `templates/scripts/check-architecture-evidence.sh`, `templates/scripts/agent-verify.sh`.

## Task 1: Add Documentation And Sync Tests

**Files:**
- Create: `docs/agent/repair-failed-run.md`
- Create: `templates/docs/agent/repair-failed-run.md`
- Modify: `tests/harness/doc-consistency.sh`
- Modify: `tests/harness/adapter-sync.sh`

- [ ] **Step 1: Add doc consistency assertion**

In `tests/harness/doc-consistency.sh`, add a source/template mirror check:

```bash
cmp docs/agent/repair-failed-run.md templates/docs/agent/repair-failed-run.md
```

If this file uses helper functions for mirror checks, add `repair-failed-run.md` to that existing list instead of adding a standalone `cmp`.

- [ ] **Step 2: Add adapter sync assertions**

In `tests/harness/adapter-sync.sh`, add assertions that the Codex and Claude adapters reference the repair protocol:

```bash
assert_contains "$repo_root/adapters/codex/AGENTS.md" "docs/agent/repair-failed-run.md"
assert_contains "$repo_root/adapters/claude-code/CLAUDE.md" "docs/agent/repair-failed-run.md"
```

- [ ] **Step 3: Create the repair protocol doc**

Create `docs/agent/repair-failed-run.md`:

```markdown
# Repair Failed Finish Runs

Use this protocol when `scripts/agent-finish.sh` exits non-zero. A failed
finish run means the agent must inspect the run evidence, repair the failing
condition, rerun the relevant check, and rerun `scripts/agent-finish.sh`
before claiming completion.

Do not claim completion from a failed finish run. Do not widen scope, weaken
policy, or mark evidence as passing only to make the gate pass.

## Evidence Location

Each finish run writes evidence under `.agent/runs/<timestamp>/`.

Start with:

- `finish-summary.md`
- `finish-summary.json`
- the gate-specific `*-result.txt` file named by the failing row
- `changed-files.txt`
- `git-diff-stat.txt`

## Failure Classes

| Failure class | Primary evidence file | Meaning | Agent repair procedure | Human escalation condition |
| --- | --- | --- | --- | --- |
| `check-agent-md` failed | `check-agent-md-result.txt` | Required stable agent context is missing or invalid. | Restore or update the required agent context file, then rerun the check. | Escalate if the repo intentionally removed the context contract. |
| `check-scope` failed | `scope-result.txt`, `changed-files.txt` | Changed files are outside `.agent/task.yml` scope. | Revert unrelated edits or ask for explicit scope expansion. Do not silently widen `allowed_paths`. | Escalate when the task truly requires paths outside the approved scope. |
| `check-policy` failed | `policy-result.txt` | A policy or protected-path rule blocked the change. | Avoid the protected path if possible. If required, stop for explicit human approval. | Escalate for any high-risk approval or protected path that must change. |
| `check-tdd-evidence` failed | `tdd-evidence-result.txt` | Required TDD evidence is missing or malformed. | Fill the structured TDD evidence from real test commands and rerun the check. | Escalate if the task is intentionally non-testable. |
| `check-acceptance` failed | `acceptance-result.txt` | Acceptance criteria are missing, unmet, or weakly evidenced. | Fix `.agent/acceptance.yml`. If strict refs are enabled, bind run artifacts with `scripts/agent-evidence-bind.sh`, rerun `scripts/check-acceptance.sh`, then rerun finish. | Escalate if criteria need product clarification. |
| `check-review-evidence` failed | `review-result.txt` | Required review evidence is missing or not accepted. | Add real review evidence or perform the requested review step. | Escalate if human review is required. |
| `check-architecture-evidence` failed | `architecture-evidence-result.txt` | Architecture evidence is missing, malformed, or says an invariant is violated. | Determine whether the invariant is actually violated. Fix design if violated; otherwise add command-backed evidence. | Escalate if the invariant conflicts with the requested change. |
| `check-failure-attribution` failed | `failure-attribution-result.txt` | Required failure attribution is missing or incomplete. | Record the failed command, cause, fix, and verification before rerunning finish. | Escalate if the cause cannot be determined after investigation. |
| `check-interventions` failed | `interventions-result.txt` | Required intervention records are missing or incomplete. | Record human intervention or approval details that actually occurred. | Escalate if the needed approval did not occur. |
| `check-command-ledger` failed | `command-ledger-result.txt` | Required command ledger evidence is missing or inconsistent. | Record real commands and outcomes; rerun the command if evidence is stale. | Escalate if a required command cannot be rerun. |
| `check-sandbox-evidence` failed | `sandbox-evidence-result.txt` | Required sandbox evidence is missing, failed, or skipped without allowed reason. | Run the sandbox helper where available or record an allowed skip. | Escalate when the task requires sandbox evidence but no runner is available. |
| `check-subagent-evidence` failed | `subagent-evidence-result.txt` | Required delegated-run evidence is missing or incomplete. | Add real subagent packet and run evidence. | Escalate if delegation was required but not performed. |
| `validate-episode` failed | `episode-result.txt`, `episode-summary.json` | Episode package metadata is missing or invalid. | Fix episode metadata and regenerate validation evidence. | Escalate if the episode contract is not applicable. |
| `agent-verify` failed | `verify-result.txt` | Repository verification failed. | Fix code or tests, rerun verification, then rerun finish. | Escalate when the failure is environmental or contradicts task requirements. |
| `resource-envelope` failed | `resource-envelope-result.txt` | Finish duration or changed-file count exceeded configured limits. | Reduce scope or ask for explicit limit changes. | Escalate if the configured limit is too small for the approved task. |

## Repair Loop

1. Read `.agent/runs/<timestamp>/finish-summary.md`.
2. Open the primary evidence file for the failing gate.
3. Repair the underlying cause.
4. Rerun the specific failing check when possible.
5. Rerun `scripts/agent-finish.sh`.
6. Update `handoff.md` with the new run evidence.
7. Claim completion only after the final finish run passes.
```

- [ ] **Step 4: Copy the installed mirror**

Run:

```bash
cp docs/agent/repair-failed-run.md templates/docs/agent/repair-failed-run.md
```

- [ ] **Step 5: Run doc consistency to verify the new checks**

Run:

```bash
bash tests/harness/doc-consistency.sh
```

Expected: FAIL until adapter docs are updated.

## Task 2: Wire Adapter And Entrypoint Guidance

**Files:**
- Modify: `adapters/codex/AGENTS.md`
- Modify: `adapters/codex/codex-repair-prompt.md`
- Modify: `adapters/claude-code/CLAUDE.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [ ] **Step 1: Update adapter instructions**

Add this guidance to Codex and Claude adapter files:

```markdown
If `scripts/agent-finish.sh` fails, do not claim completion. Read
`.agent/runs/<timestamp>/finish-summary.md`, inspect the failing
`*-result.txt` file, follow `docs/agent/repair-failed-run.md`, repair the
underlying cause, rerun the failed check when possible, and rerun
`scripts/agent-finish.sh`.
```

- [ ] **Step 2: Update installed entrypoint docs**

Add the same guidance to `templates/AGENTS.md` and `templates/CLAUDE.md`.

- [ ] **Step 3: Link from README files**

Add this sentence to `README.md`:

```markdown
When a finish run fails, agents should follow
[Repair Failed Finish Runs](docs/agent/repair-failed-run.md) before making any
completion claim.
```

Add the Traditional Chinese equivalent to `README.zh-TW.md`.

- [ ] **Step 4: Run adapter and doc checks**

Run:

```bash
bash tests/harness/adapter-sync.sh
bash tests/harness/doc-consistency.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: all commands pass.

## Task 3: Improve Selected Failure Messages

**Files:**
- Modify: `templates/scripts/check-scope.sh`
- Modify: `templates/scripts/check-policy.sh`
- Modify: `templates/scripts/check-acceptance.sh`
- Modify: `templates/scripts/check-architecture-evidence.sh`
- Modify: `templates/scripts/agent-verify.sh`
- Modify: relevant `tests/harness/*.sh` suites if assertions need to cover the new message.

- [ ] **Step 1: Add a standard repair hint**

For each selected script, add a failure hint near the existing result marker:

```bash
echo "Repair: inspect this result file in .agent/runs/<timestamp>/ and follow docs/agent/repair-failed-run.md"
```

Use the script's existing wording style and avoid claiming the script knows the actual timestamp when it is run outside `agent-finish.sh`.

- [ ] **Step 2: Add focused assertions only where stable**

If a test already asserts failure output for one of these scripts, add:

```bash
assert_contains "$log_file" "docs/agent/repair-failed-run.md"
```

Do not broaden every gate test just to assert the same string.

- [ ] **Step 3: Run affected suites**

Run:

```bash
bash tests/harness/scope.sh
bash tests/harness/policy.sh
bash tests/harness/acceptance-review.sh
bash tests/harness/architecture-evidence.sh
bash tests/harness/repo-verification.sh
```

Expected: all commands pass.

## Task 4: Full Verification And Commit

**Files:**
- Modify: all files from Tasks 1-3.
- Modify: `docs/superpowers/plans/2026-06-27-failed-run-repair-protocol.md`

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
git add docs/agent/repair-failed-run.md templates/docs/agent/repair-failed-run.md adapters/codex/AGENTS.md adapters/codex/codex-repair-prompt.md adapters/claude-code/CLAUDE.md templates/AGENTS.md templates/CLAUDE.md README.md README.zh-TW.md tests/harness/doc-consistency.sh tests/harness/adapter-sync.sh templates/scripts/check-scope.sh templates/scripts/check-policy.sh templates/scripts/check-acceptance.sh templates/scripts/check-architecture-evidence.sh templates/scripts/agent-verify.sh tests/harness docs/superpowers/plans/2026-06-27-failed-run-repair-protocol.md
git commit -m "docs: add failed finish repair protocol"
```
