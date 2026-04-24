# Agent-Repo-Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve Agent-Repo-Guide into a lightweight Agent-Repo-Harness that adds repo-aware control layers around Superpowers without replacing it.

**Architecture:** Keep the existing repo-guidance core, then add a harness scaffold with templates, safety-first scripts, repo-aware skills, installer support, and example projects. Migrate concepts additively first, keeping old skills in place until their harness replacements and compatibility notes exist.

**Tech Stack:** Markdown, YAML, Bash, existing Codex/Superpowers skill format

---

### Task 1: Scaffold additive harness directories

**Files:**
- Create: `templates/`
- Create: `templates/docs/agent/`
- Create: `templates/docs/agent/debug-recipes/`
- Create: `templates/docs/agent/decisions/`
- Create: `templates/scripts/`
- Create: `templates/.agent/`
- Create: `templates/.agent/evals/`
- Create: `skills/`
- Create: `examples/go-iot-platform/`
- Create: `examples/rag-contract-system/`

- [ ] **Step 1: Create the directory skeleton**

Run: `mkdir -p templates/docs/agent/debug-recipes templates/docs/agent/decisions templates/scripts templates/.agent/evals skills examples/go-iot-platform examples/rag-contract-system`
Expected: directories exist with no errors

- [ ] **Step 2: Verify the skeleton exists**

Run: `find templates skills examples -maxdepth 3 -type d | sort`
Expected: output includes the target harness directories

- [ ] **Step 3: Commit**

```bash
git add templates skills examples docs/superpowers/plans/2026-04-24-agent-repo-harness.md
git commit -m "chore: scaffold agent repo harness layout"
```

### Task 2: Add template docs and config

**Files:**
- Create: `templates/agent.md`
- Create: `templates/handoff.md`
- Create: `templates/docs/agent/known-issues.md`
- Create: `templates/docs/agent/discoveries.md`
- Create: `templates/docs/agent/debug-recipes/README.md`
- Create: `templates/docs/agent/decisions/0001-template.md`
- Create: `templates/.agent/harness.yml`
- Create: `templates/.agent/policy.yml`
- Create: `templates/.agent/evals/repo-guidance-cases.yml`

- [ ] **Step 1: Write the template files**

Add markdown and YAML templates that reflect the separation of stable repo map, current-task handoff, discoveries, decisions, and policy metadata.

- [ ] **Step 2: Review the templates for boundary violations**

Run: `rg -n "Current Task|implementation plan|chronological" templates/agent.md templates/handoff.md templates/docs/agent -S`
Expected: `templates/agent.md` does not contain handoff-only state and template docs stay within their intended scope

- [ ] **Step 3: Commit**

```bash
git add templates/agent.md templates/handoff.md templates/docs/agent templates/.agent
git commit -m "feat: add agent repo harness templates"
```

### Task 3: Add safe-by-default scripts with shell validation

**Files:**
- Create: `templates/scripts/agent-preflight.sh`
- Create: `templates/scripts/agent-verify.sh`
- Create: `templates/scripts/check-agent-md.sh`
- Create: `templates/scripts/collect-context.sh`
- Create: `templates/scripts/check-policy.sh`

- [ ] **Step 1: Write a failing shell validation command**

Run: `for f in templates/scripts/*.sh; do bash -n "$f"; done`
Expected: FAIL before the scripts exist

- [ ] **Step 2: Write minimal scripts**

Implement safe scripts that:
- summarize repo markers without mutating project files
- skip unavailable commands cleanly
- avoid destructive actions
- warn on policy matches instead of blocking by default unless configured

- [ ] **Step 3: Verify shell syntax**

Run: `for f in templates/scripts/*.sh; do bash -n "$f"; done`
Expected: PASS with no syntax errors

- [ ] **Step 4: Run representative checks**

Run: `templates/scripts/check-agent-md.sh` after copying or inspecting `templates/agent.md` logic as needed
Expected: checker behavior is documented and script exits intentionally

- [ ] **Step 5: Commit**

```bash
git add templates/scripts
git commit -m "feat: add safe harness scripts"
```

### Task 4: Add harness skill replacements and compatibility bridge

**Files:**
- Create: `skills/harness-entrypoint/SKILL.md`
- Create: `skills/repo-context-bootstrap/SKILL.md`
- Create: `skills/repo-map-maintenance/SKILL.md`
- Create: `skills/handoff-update/SKILL.md`
- Create: `skills/subagent-context-packet/SKILL.md`
- Create: `skills/policy-gate/SKILL.md`
- Create: `skills/verification-gate/SKILL.md`
- Create: `skills/discoveries-memory/SKILL.md`
- Create: `skills/domain-risk-review/SKILL.md`
- Modify: `README.md`
- Modify: `README.en.md`

- [ ] **Step 1: Reuse and adapt existing concepts**

Copy the routing, evidence, and patch-vs-rebuild discipline from the current skills into the new harness skills, expanding them to cover preflight, context packets, discoveries, policy gates, verification gates, and domain risk review.

- [ ] **Step 2: Keep old skills in place**

Add migration language in the README instead of deleting `project-agent-docs`, `project-map-agent-md`, or `update-agent-handoff`.

- [ ] **Step 3: Check for consistent terminology**

Run: `rg -n "Verified:|Inferred:|TODO:|handoff|policy|verification" skills README.md README.en.md references -S`
Expected: terminology stays consistent across new and existing guidance

- [ ] **Step 4: Commit**

```bash
git add skills README.md README.en.md
git commit -m "feat: add harness skills and migration guidance"
```

### Task 5: Add installer and examples

**Files:**
- Create: `install-agent-harness.sh`
- Create: `examples/go-iot-platform/README.md`
- Create: `examples/rag-contract-system/README.md`

- [ ] **Step 1: Write a failing smoke check**

Run: `bash -n install-agent-harness.sh`
Expected: FAIL before the installer exists

- [ ] **Step 2: Write the installer**

Implement an additive installer that:
- copies `templates/` into a target repo
- refuses dangerous destinations
- supports a dry-run mode
- avoids overwriting existing files unless explicitly requested

- [ ] **Step 3: Add example READMEs**

Document how the harness should be applied to a Go IoT platform and a RAG-style contract system, including likely policy/risk areas and verification expectations.

- [ ] **Step 4: Verify installer syntax**

Run: `bash -n install-agent-harness.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add install-agent-harness.sh examples
git commit -m "feat: add harness installer and examples"
```

### Task 6: Validate the repository and document gaps

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: any files needed to fix validation failures

- [ ] **Step 1: Run repository validation**

Run: `bash -n install-agent-harness.sh && for f in templates/scripts/*.sh; do bash -n "$f"; done`
Expected: PASS

- [ ] **Step 2: Run content sanity checks**

Run: `rg --files templates skills examples | sort`
Expected: required files exist for templates, skills, and examples

- [ ] **Step 3: Record limitations if anything cannot be validated**

Update the README with explicit limitations for commands that depend on target-repo tooling or optional local tools.

- [ ] **Step 4: Commit**

```bash
git add README.md README.en.md templates skills examples install-agent-harness.sh
git commit -m "docs: finalize harness validation notes"
```
