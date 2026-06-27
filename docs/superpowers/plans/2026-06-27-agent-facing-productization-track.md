# Agent-Facing Productization Track Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Coordinate the v0.2.x agent-facing productization work from the source spec into independent implementation plans that can land one PR at a time.

**Architecture:** Treat the source spec as a six-PR track. PR 1 is already covered by the existing evidence refs plan; the remaining plans add helpers, repair protocol, architecture sensor examples, dogfood examples, and the stability contract without changing the project's runtime-boundary claims.

**Tech Stack:** Bash, Python standard library, existing repo-local YAML subset reader, JSON Schema, Markdown docs, existing `tests/harness/*.sh` suites.

---

## Source Spec

Primary design source:

- `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`

The spec defines seven capabilities:

1. Artifact-backed `evidence_refs`.
2. `agent-task-profile.sh`.
3. `agent-evidence-bind.sh`.
4. Failed-run repair protocol.
5. Architecture fitness sensor pattern.
6. Dogfood examples and adoption walkthroughs.
7. Stability contract.

## Plan Split

Use these plans in order:

1. `docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md`
   - Covers spec Capability 1.
   - Adds `schemas/evidence-ref.schema.json`, `templates/scripts/check-evidence-refs.py`, strict acceptance config, tests, and docs.
2. `docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md`
   - Covers spec Capability 3.
   - Depends on the evidence refs validator from plan 1.
3. `docs/superpowers/plans/2026-06-27-agent-task-profile-helper.md`
   - Covers spec Capability 2.
   - Can run after plan 1 or plan 2; it is independent of evidence binding.
4. `docs/superpowers/plans/2026-06-27-failed-run-repair-protocol.md`
   - Covers spec Capability 4.
   - Benefits from plan 2 because acceptance repair can point to `agent-evidence-bind.sh`.
5. `docs/superpowers/plans/2026-06-27-architecture-sensor-patterns.md`
   - Covers spec Capability 5.
   - Benefits from plan 1 because sensor output is referenceable through `evidence_refs`.
6. `docs/superpowers/plans/2026-06-27-dogfood-examples-stability-contract.md`
   - Covers spec Capabilities 6 and 7.
   - Runs after plans 1-5 so examples can cite the actual helper scripts and repair protocol.

## Task 1: Confirm Track Entry Conditions

**Files:**
- Read: `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`
- Read: `docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md`
- Read: `docs/public-packaging.md`
- Read: `docs/runtime-boundaries.md`

- [ ] **Step 1: Confirm the source spec is present**

Run:

```bash
test -s docs/superpowers/specs/2026-06-27-agent-facing-productization.md
```

Expected: command exits `0`.

- [ ] **Step 2: Confirm the PR 1 plan exists**

Run:

```bash
test -s docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md
```

Expected: command exits `0`.

- [ ] **Step 3: Confirm public boundary docs still exist**

Run:

```bash
test -s docs/public-packaging.md
test -s docs/runtime-boundaries.md
```

Expected: both commands exit `0`.

## Task 2: Execute Plans In Order

**Files:**
- Modify: plan files listed in the Plan Split section as tasks complete.
- Modify: implementation files named by each downstream plan.

- [ ] **Step 1: Implement plan 1**

Execute:

```text
docs/superpowers/plans/2026-06-27-evidence-refs-strict-acceptance.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 2: Implement plan 2**

Execute:

```text
docs/superpowers/plans/2026-06-27-agent-evidence-bind-helper.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 3: Implement plan 3**

Execute:

```text
docs/superpowers/plans/2026-06-27-agent-task-profile-helper.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 4: Implement plan 4**

Execute:

```text
docs/superpowers/plans/2026-06-27-failed-run-repair-protocol.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 5: Implement plan 5**

Execute:

```text
docs/superpowers/plans/2026-06-27-architecture-sensor-patterns.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 6: Implement plan 6**

Execute:

```text
docs/superpowers/plans/2026-06-27-dogfood-examples-stability-contract.md
```

Expected completion proof:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

## Task 3: Track-Wide Closeout

**Files:**
- Modify: `docs/superpowers/plans/2026-06-27-agent-facing-productization-track.md`
- Modify: `handoff.md`

- [ ] **Step 1: Re-read the source spec global completion criteria**

Review:

```text
docs/superpowers/specs/2026-06-27-agent-facing-productization.md
```

Confirm these outcomes exist in the live checkout:

- Agents can generate `.agent/task.yml` through a helper.
- Agents can bind evidence refs through a helper.
- Acceptance evidence can be artifact-backed and strict.
- Failed runs have a documented repair protocol.
- At least one architecture sensor pattern is documented.
- At least three real workflow examples exist.
- Stable vs experimental interfaces are documented.
- No external dependencies are introduced.
- Default behavior remains backward-compatible.
- Public wording still avoids sandbox, runtime enforcement, and semantic correctness claims.

- [ ] **Step 2: Run final validation**

Run:

```bash
bash validate-harness.sh
bash templates/scripts/check-doc-links.sh .
```

Expected: both commands pass.

- [ ] **Step 3: Update track plan status**

Change completed checkboxes in this file from `- [ ]` to `- [x]` only after the matching implementation evidence exists.

- [ ] **Step 4: Update handoff**

Update `handoff.md` with:

```markdown
## Agent-Facing Productization Track

- Source spec: `docs/superpowers/specs/2026-06-27-agent-facing-productization.md`
- Plan index: `docs/superpowers/plans/2026-06-27-agent-facing-productization-track.md`
- Final validation:
  - `bash validate-harness.sh`: pass
  - `bash templates/scripts/check-doc-links.sh .`: pass
- Boundary: still no sandboxing, runtime orchestration, provider-native tracing, or semantic correctness guarantee claims.
```

- [ ] **Step 5: Commit track closeout**

```bash
git add docs/superpowers/plans/2026-06-27-agent-facing-productization-track.md handoff.md
git commit -m "docs: close agent-facing productization track"
```
