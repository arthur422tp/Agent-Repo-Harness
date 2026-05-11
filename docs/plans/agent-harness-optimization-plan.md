# Agent-Repo-Harness Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve Agent-Repo-Harness from a repo-local guardrail harness into a more complete, agent-first engineering harness without breaking current installed users.

**Architecture:** Keep the universal lightweight core, but move durable repo knowledge into `docs/agent/`, make machine-readable configuration the source of truth, and expand completion gates from scope/policy/tests into acceptance, review, handoff, and optional subagent evidence. Changes should be additive first, with compatibility shims for existing templates and examples.

**Tech Stack:** POSIX-ish Bash, Python standard library for YAML-adjacent config reads where needed, JSON Schemas, Markdown templates, Codex/Claude Code adapter prompt files.

---

## 1. Current State Summary

Agent-Repo-Harness already has a coherent lightweight core:

- `README.md` clearly defines the harness as a repo-local framework, not an agent runtime, sandbox, MCP server, or semantic correctness guarantee.
- `templates/AGENTS.md` and `templates/CLAUDE.md` are concise entrypoints that direct agents to `agent.md`, `handoff.md`, `.agent/policy.yml`, `.agent/task.yml`, preflight, and finish gates.
- `templates/agent.md` separates stable repo facts from task state and includes basic freshness protection through `scripts/check-agent-md.sh`.
- `templates/handoff.md` gives a concise task handoff shape and keeps transient work out of `agent.md`.
- `.agent/task.yml`, `.agent/policy.yml`, `.agent/harness.yml`, and JSON Schemas provide a machine-readable control surface.
- `scripts/check-scope.sh`, `scripts/check-policy.sh`, `scripts/check-tdd-evidence.sh`, `scripts/agent-verify.sh`, and `scripts/agent-finish.sh` cover the current MVP gates and record durable finish evidence under `.agent/runs/<timestamp>/`.
- `agent-verify.sh` already gives priority to repo-defined `.agent/harness.yml` verification commands before heuristic auto-detection.
- `install-agent-harness.sh` installs templates without overwriting by default and supports dry run, force, and backup.
- `validate-harness.sh` has useful smoke coverage for installation, script syntax, config validation, scope failures, policy approval, repo-defined verification, TDD evidence, finish evidence, and universal example behavior.
- Subagent conventions exist through `.agent/subagent-packet.yml`, `.agent/subagent-runs/`, `validate-subagent-packet.sh`, `validate-subagent-run.sh`, and `docs/agent/subagent-result-template.md`.
- Superpowers-compatible skills remain preserved in `skills/`, and `docs/superpowers-integration.md` explains the responsibility split.

The repository is therefore a solid MVP. The optimization work should harden and connect existing pieces rather than replace them.

## 2. Problem Diagnosis

### Gap 1: Durable repo knowledge is seeded but not yet navigable

- Current files involved: `templates/agent.md`, `templates/docs/agent/known-issues.md`, `templates/docs/agent/discoveries.md`, `templates/docs/agent/debug-recipes/README.md`, `templates/docs/agent/decisions/0001-template.md`, `templates/AGENTS.md`, `templates/CLAUDE.md`, `.agent/harness.yml`.
- Why it matters: `agent.md` is still asked to carry project overview, architecture map, entrypoints, commands, verification, risk areas, and rules. This can grow into the giant rulebook that the harness is trying to avoid.
- Risk if left unfixed: installed repos will accumulate stale or oversized `agent.md` files, and future agents will struggle to find the right level of detail.
- Status: MVP acceptable, framework-blocking for the long-term agent-first goal.

### Gap 2: Mechanical freshness checks are shallow

- Current files involved: `templates/scripts/check-agent-md.sh`, `templates/scripts/agent-finish.sh`, `templates/scripts/agent-preflight.sh`, `templates/docs/agent/*`.
- Why it matters: `check-agent-md.sh` only checks headings and that `agent.md` does not contain `Current Task`. There is no link check, ownership/freshness metadata check, or drift check between `agent.md`, `docs/agent/*`, `.agent/harness.yml`, adapters, examples, and templates.
- Risk if left unfixed: docs and adapters can confidently point at files or commands that no longer exist.
- Status: MVP acceptable, framework-blocking for a maintainable harness.

### Gap 3: YAML/config parsing is brittle

- Current files involved: `templates/scripts/check-scope.sh`, `templates/scripts/check-policy.sh`, `templates/scripts/check-tdd-evidence.sh`, `templates/scripts/agent-verify.sh`, `templates/scripts/validate-subagent-packet.sh`, `templates/scripts/validate-task.sh`, `templates/scripts/validate-config.sh`.
- Why it matters: many scripts use `awk`, `grep`, and section indentation assumptions to parse YAML. This works for current templates but is fragile around quoting, comments, reordered keys, nested structures, and list indentation.
- Risk if left unfixed: valid YAML can be misread, invalid task boundaries can pass, and repo-defined verification commands can be skipped or malformed.
- Status: MVP acceptable, framework-blocking before adding more config files.

### Gap 4: Repo-defined verification priority exists but is not strongly validated

- Current files involved: `.agent/harness.yml`, `schemas/harness.schema.json`, `templates/scripts/agent-verify.sh`, `validate-harness.sh`, `examples/universal-minimal-repo/.agent/harness.yml`.
- Why it matters: `agent-verify.sh` already runs `.agent/harness.yml` `verification.required` before auto-detection, but the extractor is `awk` based and schema validation is syntax/key oriented rather than contract oriented.
- Risk if left unfixed: a repo can believe it has required verification configured while the harness silently misses or misparses the commands.
- Status: MVP acceptable, framework-blocking for reliable engineering workflows.

### Gap 5: High-risk policy approval is self-grantable

- Current files involved: `templates/.agent/policy.yml`, `templates/scripts/check-policy.sh`, `adapters/claude-code/.claude/skills/policy-gate/SKILL.md`.
- Why it matters: strict mode accepts `AGENT_APPROVED_HIGH_RISK=1` or `.agent/approvals/high-risk-approved`. An agent can create that file or set the env var unless the surrounding runtime prevents it.
- Risk if left unfixed: the policy gate gives a false sense of control for migrations, auth, billing, infra, workflow, or secrets-adjacent changes.
- Status: MVP acceptable as a warning/control convention, framework-blocking if policy is positioned as a real approval gate.

### Gap 6: Completion semantics stop short of acceptance and review evidence

- Current files involved: `.agent/task.yml`, `templates/scripts/check-tdd-evidence.sh`, `templates/scripts/agent-finish.sh`, `templates/handoff.md`, `schemas/task.schema.json`, `schemas/handoff.schema.json`.
- Why it matters: finish currently checks agent map, scope, policy, TDD evidence, and verification. It does not check acceptance criteria, reviewer evidence, unresolved review concerns, or whether `handoff.md` was updated after the latest finish run.
- Risk if left unfixed: a task can pass finish while not meeting explicit acceptance criteria or review requirements.
- Status: MVP acceptable, framework-blocking for an engineering harness.

### Gap 7: Subagent packet and run evidence are optional conventions only

- Current files involved: `.agent/subagent-packet.yml`, `.agent/subagent-runs/`, `templates/scripts/validate-subagent-packet.sh`, `templates/scripts/validate-subagent-run.sh`, `templates/scripts/agent-finish.sh`, `docs/superpowers-integration.md`.
- Why it matters: the README explicitly says packet/run evidence is not part of `agent-finish.sh` yet. This is correct for MVP, but it leaves no way for a parent task to require subagent evidence when delegation was part of the task plan.
- Risk if left unfixed: multi-agent work can complete without durable proof that delegated work produced a valid status, result, and verification record.
- Status: MVP acceptable, framework-blocking for subagent-driven workflows.

### Gap 8: Codex and Claude adapters cover startup and finish, not the full lifecycle

- Current files involved: `docs/codex-usage.md`, `adapters/codex/codex-start-prompt.md`, `adapters/codex/AGENTS.md`, `adapters/claude-code/CLAUDE.md`, `adapters/claude-code/.claude/skills/*`.
- Why it matters: adapters guide start, boundaries, and finish. They do not provide separate reusable prompts for plan, implement, verify, repair after gate failure, review evidence, or handoff.
- Risk if left unfixed: users will recreate long prompts, duplicating repo docs and producing inconsistent task lifecycle behavior.
- Status: MVP acceptable, framework-blocking for polished agent-first use.

### Gap 9: Maintenance and drift control are missing

- Current files involved: `validate-harness.sh`, `install-agent-harness.sh`, `templates/`, `examples/`, `adapters/`, `schemas/`, `docs/`.
- Why it matters: `validate-harness.sh` checks many behaviors but not doc links, template/example sync, adapter command references, obsolete examples, schema/template alignment, or required docs under `docs/agent/`.
- Risk if left unfixed: examples and adapters can rot while core scripts still pass.
- Status: MVP acceptable, framework-blocking for long-lived harness quality.

## 3. Proposed Target Architecture

The target architecture should keep `AGENTS.md` and `CLAUDE.md` short and route agents into a durable repo knowledge system.

### Entrypoint layer

- `AGENTS.md`: concise map for generic agents and Codex. It should name the required files, preflight command, finish command, and where deeper docs live. It should not grow into a policy manual.
- `CLAUDE.md`: concise Claude Code equivalent that points to installed project skills and the same repo-owned files.
- `adapters/codex/`: lifecycle prompts that can be copied or referenced without duplicating long repo docs.
- `adapters/claude-code/`: Claude Code entrypoint plus project skills that mirror the same lifecycle.

### Durable knowledge layer

Add or promote:

- `docs/agent/index.md`: map of the repo knowledge system, with links to stable maps, verification, review, maintenance, decisions, known issues, discoveries, debug recipes, and subagent evidence.
- `docs/agent/architecture-map.md`: stable architecture facts that outgrow `agent.md`.
- `docs/agent/verification-map.md`: repo-defined verification commands, how they map to `.agent/harness.yml`, and failure interpretation.
- `docs/agent/failure-recovery.md`: repair workflow after failed policy, scope, acceptance, review, subagent, or verification gates.
- `docs/agent/review.md`: expected review evidence, reviewer roles, status values, and how concerns block finish.
- `docs/agent/maintenance.md`: how to run freshness, link, template sync, adapter sync, schema/example, and install smoke checks.

Keep:

- `agent.md`: short durable repo overview and pointer map into `docs/agent/`.
- `handoff.md`: current task state only.
- `docs/agent/known-issues.md`, `docs/agent/discoveries.md`, `docs/agent/debug-recipes/`, `docs/agent/decisions/`: existing knowledge stores.

### Machine-readable task and evidence layer

Add only where justified:

- `.agent/acceptance.yml`: explicit acceptance criteria and their evidence status.
- `.agent/review.yml`: review requirements, reviewer roles, statuses, concerns, and evidence links.
- `.agent/subagent-packet.yml`: keep existing packet convention.
- `.agent/subagent-runs/`: keep existing run evidence convention.

Extend `.agent/task.yml` completion flags additively:

- `requires_acceptance_check`
- `requires_review_evidence`
- `requires_subagent_evidence`
- `requires_doc_freshness_check`

### Gate layer

Add:

- `scripts/lib/read-yaml.py`: standard-library parser/reader for the subset of YAML the harness owns. It should first try Python stdlib-compatible JSON if files are JSON-compatible, then a small strict YAML subset reader for maps/lists/scalars, or fail with a clear message. It must not require PyYAML unless the repo explicitly opts in later.
- `scripts/check-acceptance.sh`: validates `.agent/acceptance.yml` when required.
- `scripts/check-review-evidence.sh`: validates `.agent/review.yml` when required.
- `scripts/check-doc-links.sh`: checks local Markdown links and referenced scripts/files.
- `scripts/check-doc-freshness.sh`: checks required metadata and stale markers for `agent.md` and `docs/agent/*`.
- `scripts/check-template-sync.sh`: checks templates, examples, adapters, schemas, and README command references for drift.
- `scripts/check-subagent-evidence.sh`: validates required subagent run evidence and acceptable statuses.

Update:

- `scripts/agent-verify.sh`: use robust config reading for `verification.required`; keep auto-detection as fallback.
- `scripts/agent-finish.sh`: include acceptance, review, subagent evidence, handoff update, and maintenance gates only when configured.
- `scripts/validate-config.sh` and `scripts/validate-task.sh`: use the shared YAML reader and schema-like structural checks.
- `validate-harness.sh`: include unit-style checks and fixtures for every new gate.

### Adapter lifecycle layer

Add Codex lifecycle prompts under `adapters/codex/`:

- `codex-start-prompt.md`
- `codex-plan-prompt.md`
- `codex-implement-prompt.md`
- `codex-verify-prompt.md`
- `codex-repair-prompt.md`
- `codex-review-prompt.md`
- `codex-handoff-prompt.md`

Update Claude Code guidance:

- keep `adapters/claude-code/CLAUDE.md` concise;
- extend existing project skills or add lifecycle-specific skills only if they are not duplicative;
- make repair/review/handoff flows point to repo files and scripts rather than repeating docs.

## 4. Phased Implementation Roadmap

### Phase 1: Reliability and Config Parsing

**Goal:** Make config reads and repo-defined verification reliable before adding more gates.

**Files to add:**

- `templates/scripts/lib/read-yaml.py`
- `templates/scripts/check-doc-links.sh`
- `docs/plans/fixtures/` or `tests/fixtures/` only if fixture placement is agreed.

**Files to modify:**

- `templates/scripts/agent-verify.sh`
- `templates/scripts/check-scope.sh`
- `templates/scripts/check-policy.sh`
- `templates/scripts/validate-config.sh`
- `templates/scripts/validate-task.sh`
- `templates/.agent/harness.yml`
- `schemas/harness.schema.json`
- `install-agent-harness.sh`
- `validate-harness.sh`
- `README.md`

**Scripts to update:**

- Replace `awk` extraction of `.agent/harness.yml` `verification.required` with `scripts/lib/read-yaml.py`.
- Move `check-scope.sh` and `check-policy.sh` to the shared reader after the verification reader is proven.
- Add link checks for local Markdown links and script references.
- Harden high-risk approval by adding a non-self-granting mode, such as a configured approval token file outside `.agent/` or a required human-authored approval record with approver, reason, timestamp, and changed paths. Keep current env/file approval as legacy compatibility.

**Validation command:**

```bash
bash validate-harness.sh
```

Expected additional checks:

```bash
bash templates/scripts/check-doc-links.sh
bash templates/scripts/agent-verify.sh --best-effort
```

**Expected outcome:**

- Valid `.agent/harness.yml` verification commands are read predictably.
- Auto-detection remains fallback behavior.
- Existing installs still pass.
- Markdown and script references are mechanically checked.
- High-risk approval gains a safer path without breaking legacy behavior.

**Risks:**

- Writing a YAML subset reader can accidentally become a full parser project. Keep the supported config subset explicit.
- Python path handling must work from installed target repos, not only this repo.
- Policy approval hardening must not strand existing users who rely on the env var.

### Phase 2: Completion Semantics

**Goal:** Make `agent-finish.sh` prove task completion more directly, not just boundary and test execution.

**Files to add:**

- `templates/.agent/acceptance.yml`
- `templates/.agent/review.yml`
- `templates/scripts/check-acceptance.sh`
- `templates/scripts/check-review-evidence.sh`
- `schemas/acceptance.schema.json`
- `schemas/review.schema.json`
- `templates/docs/agent/review.md`

**Files to modify:**

- `templates/.agent/task.yml`
- `templates/scripts/agent-finish.sh`
- `templates/scripts/validate-task.sh`
- `templates/handoff.md`
- `templates/AGENTS.md`
- `templates/CLAUDE.md`
- `schemas/task.schema.json`
- `schemas/handoff.schema.json`
- `install-agent-harness.sh`
- `validate-harness.sh`
- `README.md`
- `docs/agent-support-matrix.md`

**Scripts to update:**

- `agent-finish.sh`: run acceptance and review gates when `task.completion` requires them.
- `validate-task.sh`: recognize new completion flags.
- New acceptance gate: fail if required criteria lack `met: true`, evidence, or verification reference.
- New review gate: fail if required review is missing, has unresolved blocking concerns, or lacks evidence path.
- Add handoff update validation as a check that `handoff.md` references the latest `.agent/runs/<timestamp>/finish-summary.md` after finish, or run it as a post-finish warning to avoid circularity.

**Validation command:**

```bash
bash validate-harness.sh
```

Expected targeted checks:

```bash
bash templates/scripts/check-acceptance.sh templates/.agent/task.yml templates/.agent/acceptance.yml
bash templates/scripts/check-review-evidence.sh templates/.agent/task.yml templates/.agent/review.yml
```

**Expected outcome:**

- Completion can be tied to explicit acceptance criteria.
- Review expectations become machine-readable.
- Finish evidence records acceptance and review gate results.
- Handoff update requirements become checkable.

**Risks:**

- Over-requiring review can slow small tasks. Keep review optional per task.
- Acceptance evidence can become performative if the contract is too vague. Require concrete command, file, or reviewer evidence.

### Phase 3: Agent Lifecycle Adapters

**Goal:** Cover the full agent task lifecycle with concise reusable adapter prompts and skills.

**Files to add:**

- `adapters/codex/codex-plan-prompt.md`
- `adapters/codex/codex-implement-prompt.md`
- `adapters/codex/codex-verify-prompt.md`
- `adapters/codex/codex-repair-prompt.md`
- `adapters/codex/codex-review-prompt.md`
- `adapters/codex/codex-handoff-prompt.md`
- `templates/docs/agent/failure-recovery.md`
- `templates/docs/agent/verification-map.md`

**Files to modify:**

- `docs/codex-usage.md`
- `adapters/codex/AGENTS.md`
- `adapters/codex/codex-start-prompt.md`
- `adapters/claude-code/CLAUDE.md`
- `adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md`
- `adapters/claude-code/.claude/skills/verification-gate/SKILL.md`
- `adapters/claude-code/.claude/skills/handoff-update/SKILL.md`
- `docs/agent-support-matrix.md`
- `validate-harness.sh`

**Scripts to update:**

- Add adapter drift checks in `validate-harness.sh` so documented prompt filenames exist.
- Optionally include adapter prompt file references in `check-doc-links.sh`.

**Validation command:**

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh
```

**Expected outcome:**

- Codex and Claude Code users get consistent start, plan, implement, verify, repair, review, and handoff flows.
- Prompts stay short and point to repo docs instead of duplicating them.
- Failed gates have an explicit repair loop.

**Risks:**

- Adapter prompts can drift into a second copy of the docs. Enforce brevity and links.
- Claude Code skills and Codex prompts may diverge unless checked together.

### Phase 4: Subagent Evidence Integration

**Goal:** Make delegated work auditable when a task requires subagent evidence.

**Files to add:**

- `templates/scripts/check-subagent-evidence.sh`
- `schemas/subagent-packet.schema.json`
- `schemas/subagent-run.schema.json`

**Files to modify:**

- `templates/.agent/task.yml`
- `templates/.agent/subagent-packet.yml`
- `templates/.agent/subagent-runs/README.md`
- `templates/scripts/validate-subagent-packet.sh`
- `templates/scripts/validate-subagent-run.sh`
- `templates/scripts/agent-finish.sh`
- `templates/docs/agent/subagent-result-template.md`
- `docs/superpowers-integration.md`
- `install-agent-harness.sh`
- `validate-harness.sh`

**Scripts to update:**

- `check-subagent-evidence.sh`: if `requires_subagent_evidence: true`, verify that each required task id has a run directory, copied `packet.yml`, `result.md`, valid `status.txt`, and acceptable status.
- `validate-subagent-run.sh`: validate the packet/run relationship, not just file presence.
- `agent-finish.sh`: add the subagent evidence gate when required.

**Validation command:**

```bash
bash validate-harness.sh
```

Targeted checks:

```bash
bash templates/scripts/validate-subagent-packet.sh templates/.agent/subagent-packet.yml
bash templates/scripts/validate-subagent-run.sh .agent/subagent-runs/<run-dir>
bash templates/scripts/check-subagent-evidence.sh
```

**Expected outcome:**

- Parent tasks can require subagent evidence explicitly.
- Delegated run status is visible in final finish evidence.
- Superpowers subagent-driven development remains compatible but gains durable repo-local traceability.

**Risks:**

- Subagent evidence must stay optional by default.
- Status semantics need care: `DONE_WITH_CONCERNS` may pass for some tasks and block for others.

### Phase 5: Maintenance and Drift Control

**Goal:** Prevent stale docs, template drift, adapter drift, schema drift, and obsolete examples.

**Files to add:**

- `templates/docs/agent/index.md`
- `templates/docs/agent/architecture-map.md`
- `templates/docs/agent/maintenance.md`
- `templates/scripts/check-doc-freshness.sh`
- `templates/scripts/check-template-sync.sh`

**Files to modify:**

- `templates/agent.md`
- `templates/AGENTS.md`
- `templates/CLAUDE.md`
- `templates/.agent/harness.yml`
- `install-agent-harness.sh`
- `validate-harness.sh`
- `README.md`
- `docs/agent-support-matrix.md`
- `examples/universal-minimal-repo/*`
- `examples/minimal-agent-run/*`
- `schemas/*.json`

**Scripts to update:**

- `check-doc-freshness.sh`: ensure docs contain required metadata such as owner, last-reviewed, source-of-truth, and verified-by where appropriate.
- `check-template-sync.sh`: compare installed example files against templates where exact sync is expected, and allow documented example-specific deltas.
- `validate-harness.sh`: add maintenance checks and CI-ready pass/fail output.

**Validation command:**

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-freshness.sh
bash templates/scripts/check-template-sync.sh
```

**Expected outcome:**

- `docs/agent/` becomes the durable system of record.
- Examples, templates, adapters, schemas, and docs fail fast when they drift.
- CI can run a single validation command.

**Risks:**

- Freshness metadata can become bureaucratic. Only require it for files where staleness is harmful.
- Template sync must support intentional example differences.

## 5. Backward Compatibility Plan

- Existing installed harness users: keep current files valid. New gates should be opt-in through `.agent/task.yml` completion flags or `.agent/harness.yml`. Do not make `.agent/acceptance.yml`, `.agent/review.yml`, or subagent evidence required by default.
- Superpowers-compatible skills: preserve `skills/*` and existing Claude Code skill names. Add guidance around them rather than replacing them.
- Codex adapter: keep `adapters/codex/codex-start-prompt.md` and `adapters/codex/AGENTS.md`. Add lifecycle prompts as new files.
- Claude Code adapter: keep `adapters/claude-code/CLAUDE.md` and existing `.claude/skills/*`. Extend carefully and avoid large duplicated instructions.
- Generic agents: keep `templates/AGENTS.md` as the universal concise map. New docs and gates must be discoverable through `AGENTS.md`, `.agent/harness.yml`, and `scripts/agent-preflight.sh`.
- Installer: keep default no-overwrite behavior. New files should install additively. Use `--force` or `--backup` for intentional replacement.
- Dependencies: require Bash, Git where available, and Python itself only for the shared config reader. Do not require PyYAML, jq, yq, node packages, or Ruby for installed target repos.

## 6. Validation Strategy

Use `validate-harness.sh` as the CI entrypoint and expand it with focused fixtures:

- Unit-style script checks:
  - `scripts/lib/read-yaml.py` reads scalars, lists, nested maps, booleans, nulls, and quoted strings from harness-owned config.
  - `check-acceptance.sh` passes complete criteria and fails missing evidence.
  - `check-review-evidence.sh` passes approved review and fails blocking concerns.
  - `check-subagent-evidence.sh` passes valid required runs and fails missing/blocked runs.
  - `check-doc-links.sh` fails broken local Markdown links.
  - `check-template-sync.sh` detects intentional and unintentional template/example deltas.
- Install smoke tests:
  - dry run install still reports planned copies;
  - normal install copies all required files;
  - scripts remain executable;
  - no existing file is overwritten without `--force`.
- Failing fixture tests:
  - malformed YAML or unsupported YAML shape;
  - missing repo-defined verification command;
  - self-granted strict high-risk approval in hardened mode;
  - unmet acceptance criterion;
  - unresolved blocking review concern;
  - missing subagent run evidence when required;
  - stale doc metadata and broken links.
- Successful fixture tests:
  - minimal installed repo with only legacy gates;
  - repo with explicit `.agent/harness.yml` verification commands;
  - task requiring acceptance and review;
  - task requiring subagent evidence with `DONE` status;
  - docs/adapter/template sync passing.
- End-to-end finish checks:
  - `agent-finish.sh` creates result files for every configured gate;
  - `finish-summary.md` includes acceptance, review, subagent, scope, policy, TDD, verification, changed files, and diff stat when enabled;
  - failing finish still writes complete evidence.
- CI recommendation:
  - Add a simple CI job that runs `bash validate-harness.sh`.
  - Avoid installing extra dependencies in CI unless a future explicitly approved test requires them.

## 7. Minimal First PR Proposal

**Title:** Harden repo-defined verification config reading and add doc link validation

**Scope:**

- Add a shared dependency-light YAML reader for harness-owned config.
- Switch `agent-verify.sh` repo-defined verification extraction to the shared reader.
- Add basic local Markdown/script reference link validation.
- Extend `validate-harness.sh` with passing and failing fixtures for those two behaviors.

**Changed files:**

- Add `templates/scripts/lib/read-yaml.py`
- Add `templates/scripts/check-doc-links.sh`
- Modify `templates/scripts/agent-verify.sh`
- Modify `templates/scripts/validate-config.sh`
- Modify `install-agent-harness.sh`
- Modify `validate-harness.sh`
- Modify `README.md`
- Modify `schemas/harness.schema.json` only if the reader exposes a stricter supported contract

**Non-goals:**

- Do not add acceptance or review gates yet.
- Do not integrate subagent evidence into finish yet.
- Do not rewrite all shell YAML parsing in one PR.
- Do not change default policy approval behavior yet.
- Do not restructure `docs/agent/` yet.

**Acceptance criteria:**

- `.agent/harness.yml` `verification.required` commands are read through `scripts/lib/read-yaml.py`.
- Existing `validate-harness.sh` tests still pass.
- A fixture with two repo-defined verification commands runs both commands in order.
- A fixture with malformed or unsupported verification config fails clearly.
- `check-doc-links.sh` passes current docs/templates or documents allowed missing targets.
- Installed target repos include `scripts/lib/read-yaml.py` and `scripts/check-doc-links.sh`.

**Verification commands:**

```bash
bash validate-harness.sh
bash templates/scripts/agent-verify.sh --best-effort
bash templates/scripts/check-doc-links.sh
```

**Rollback plan:**

- Revert `agent-verify.sh` to the current `awk` extractor.
- Keep `read-yaml.py` and `check-doc-links.sh` unreferenced if needed, then remove them in a follow-up revert.
- Since the PR is additive except for verification extraction, rollback should not affect installed repo templates beyond removing new optional files.

## 8. Open Questions

- What exact YAML subset should `scripts/lib/read-yaml.py` support, and should unsupported YAML fail fast or warn?
- Should hardened high-risk approval require a file outside the repo, a signed/structured approval record, a protected branch check, or simply a stricter non-default mode?
- Should `.agent/acceptance.yml` be separate, or should acceptance criteria live under `.agent/task.yml` to reduce file count?
- What statuses should block review completion by default: only `changes_requested`, or also `needs_context` and `concerns`?
- Should `DONE_WITH_CONCERNS` subagent runs pass by default, warn by default, or be task-configurable?
- How should `handoff.md` freshness be checked without creating a circular dependency with `agent-finish.sh`, which produces the run directory that handoff should reference?
- Where should fixture tests live long term: embedded in `validate-harness.sh`, under `tests/fixtures/`, or under `examples/`?
- Should `docs/agent/*` freshness metadata be required in installed target repos, or only in this harness repository?
- How much adapter lifecycle guidance belongs in prompt files versus Claude Code skills versus `docs/agent/failure-recovery.md`?
- Should examples be exact installed snapshots, teaching examples with allowed deltas, or both?
