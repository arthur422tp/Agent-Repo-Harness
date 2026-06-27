# Spec: Agent-Facing Productization for Agent-Repo-Harness

Status: Draft  
Target version: v0.2.x  
Scope: Agent-facing protocol, helper scripts, evidence binding, repair loop, architecture sensor patterns, examples, and stability contract.

## 1. Background

Agent-Repo-Harness is currently a repo-local completion gate for AI coding agents. Its core purpose is to prevent agents from claiming completion before checking task scope, policy, verification, evidence, and handoff expectations. This positioning is already explicit in the README. The project also explicitly avoids claiming to be a full runtime, MCP server, sandbox, or semantic correctness guarantee.

The current `agent-finish.sh` already creates durable run evidence under `.agent/runs/<timestamp>/`, including Markdown and JSON finish summaries, changed files, diff stat, gate result files, and verification output. This gives the project a strong base for artifact-backed evidence.

However, the next maturity gap is not merely adding more gates. The next maturity gap is making the harness easier and more reliable for AI coding agents to operate.

The desired direction is:

> Human sets repo policy and verification contracts.  
> Agent fills task state, runs checks, binds evidence, repairs failures, and updates handoff.  
> Harness validates the agent’s claims with deterministic repo-local checks.

Relevant current behavior:
- README positions the project as a repo-local completion gate for AI coding agents. 
- README explicitly says the project is not a full runtime, MCP server, sandbox, or semantic correctness guarantee. 
- Runtime boundaries also explicitly list non-goals such as filesystem sandboxing, network sandboxing, secret isolation, token accounting, and semantic correctness guarantees. 
- `agent-finish.sh` already writes machine-readable `finish-summary.json` with gate statuses and evidence paths. 
- Gate profiles currently exist as guidance, but the harness does not read profile names or automatically enable flags. 

## 2. Problem Statement

The harness is usable, but still too dependent on the agent correctly inferring and hand-writing workflow state.

Current weaknesses:

1. Agents may hand-write `.agent/task.yml` flags incorrectly.
2. Agents may produce weak text-only evidence.
3. Agents may fail to bind run artifacts back to acceptance criteria.
4. Agents may not know how to repair failed harness runs.
5. Architecture evidence is structured, but still mostly self-attestation.
6. External repos lack enough concrete adoption examples.
7. Output formats and script interfaces need a clearer stability contract.

This is not primarily a human UX issue. It is an **agent UX** issue.

The goal is to reduce the entropy of agent behavior.

## 3. Goals

Implement an agent-facing productization layer that makes the following agent workflow deterministic:

1. Select an appropriate task profile.
2. Generate or update `.agent/task.yml`.
3. Run implementation and verification.
4. Run `scripts/agent-finish.sh`.
5. Bind `.agent/runs/<timestamp>/` artifacts into acceptance evidence.
6. Repair common gate failures.
7. Update handoff.
8. Claim completion only after valid artifact-backed evidence exists.

The mature workflow should be:

```text
agent reads repo protocol
agent creates task state using helper
agent runs checks
agent binds evidence using helper
harness validates artifact references
agent repairs failures using protocol
agent updates handoff
agent claims completion
4. Non-goals

Do not:

Build a full agent runtime.
Build an MCP server.
Build a security sandbox.
Add external Python dependencies.
Replace scripts/lib/read-yaml.py.
Add hosted CI provider integrations in this phase.
Add provider-native tracing.
Claim semantic correctness.
Claim filesystem, network, or secret isolation.
Make humans manually fill every task file.
5. Design Principles
5.1 Repo-local first

All checks should run through repo-local shell/Python scripts.

5.2 Agent-operable interfaces

Prefer deterministic helper scripts over asking agents to manually compose complex YAML.

5.3 Human policy, agent state

Humans or repo owners define:

.agent/policy.yml
.agent/harness.yml
protected paths
verification commands
architecture invariants
high-risk approvals

Agents update:

.agent/task.yml
.agent/acceptance.yml
handoff.md
.agent/handoff.yml
evidence_refs
5.4 Artifact-backed evidence

Text evidence is acceptable only for low-risk/default workflows. Standard and high-risk workflows should prefer references to concrete run artifacts.

5.5 Repairability

Every gate failure should tell the agent what to inspect and what to do next.

5.6 Backward compatibility

Existing users should not break by default. Strict behavior should be opt-in until a later major version.

6. Target Capabilities

This spec defines seven capabilities.

evidence_refs support.
agent-task-profile.sh.
agent-evidence-bind.sh.
Failed-run repair protocol.
Architecture fitness sensor pattern.
Dogfood examples and adoption walkthroughs.
Stability contract.

Each capability can be implemented in a separate PR.

Capability 1: Artifact-backed evidence_refs
7. Purpose

Upgrade evidence from text-only self-attestation to verifiable artifact references.

Current weak evidence:

acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence: "Ran verification."

Target strong evidence:

acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence_refs:
        - type: finish_summary_json
          path: ".agent/runs/20260627-091500/finish-summary.json"
          overall_result: "pass"
          gate: "agent-verify"
          expected_exit_status: 0
8. Functional Requirements
8.1 Add schemas/evidence-ref.schema.json

Supported MVP types:

command_output
gate_result
finish_summary_json
changed_files
diff_stat

Required fields:

type: string
path: string

Optional fields:

command: string
gate: string
expected_exit_status: integer
overall_result: pass | fail | warn
must_contain: list[string]
must_not_contain: list[string]
8.2 Add templates/scripts/check-evidence-refs.py

The validator must:

Use Python stdlib only.
Reuse scripts/lib/read-yaml.py.
Reject absolute paths.
Reject path traversal.
Reject paths outside repo root.
Reject .git/ paths.
Reject missing files.
Validate must_contain.
Validate must_not_contain.
Parse finish_summary_json.
Validate overall_result.
Validate gate exit_status.

Expected markers:

EVIDENCE_REFS_RESULT=pass
EVIDENCE_REFS_RESULT=fail
8.3 Update check-acceptance.sh

Add .agent/harness.yml config:

evidence:
  strict_refs: false
  allow_text_only_evidence: true

Default mode:

strict_refs=false
allow_text_only_evidence=true

Behavior:

If strict_refs=false, existing text evidence behavior remains valid.
If evidence_refs are present, validate them.
If strict_refs=true, each acceptance criterion must have non-empty valid evidence_refs.
If allow_text_only_evidence=false, evidence and verification may remain as human explanation but do not satisfy the gate.
9. Acceptance Criteria
Existing acceptance files continue to pass by default.
Strict mode rejects text-only evidence.
Strict mode accepts valid finish_summary_json evidence.
Missing files fail.
Path traversal fails.
Malformed JSON fails.
Wrong gate status fails.
must_contain and must_not_contain are enforced.
bash validate-harness.sh passes.
Capability 2: agent-task-profile.sh
10. Purpose

Avoid requiring agents to hand-write complex .agent/task.yml completion flags.

Current risk:

Agent manually writes profile flags and may omit required fields.

Target behavior:

bash scripts/agent-task-profile.sh standard \
  --goal "Add evidence_refs validation" \
  --current-task "Implement evidence_refs MVP" \
  --allowed "templates/scripts/**" \
  --allowed "tests/harness/**" \
  --allowed "schemas/**" \
  --allowed "docs/**"

The helper generates or updates .agent/task.yml.

11. CLI
scripts/agent-task-profile.sh PROFILE [options]

Profiles:

minimal
standard
high-risk

Options:

--goal TEXT
--current-task TEXT
--source-plan PATH_OR_TEXT
--allowed GLOB
--forbidden GLOB
--max-changed-files N
--max-diff-lines N
--architecture
--review
--command-ledger
--sandbox
--subagent
--failure-attribution
--intervention-record
--status STATUS
--output PATH

Default output:

.agent/task.yml
12. Profile Semantics
12.1 Minimal

Use for small low-risk maintenance.

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
12.2 Standard

Use for normal feature, bugfix, refactor, or behavior change.

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
12.3 High-risk

Start with Standard. Enable only selected risk gates.

Example:

bash scripts/agent-task-profile.sh high-risk \
  --architecture \
  --review \
  --command-ledger

Result:

completion:
  requires_scope_check: true
  requires_policy_check: true
  requires_verification: true
  expects_handoff_update: true
  requires_tdd_evidence: true
  requires_acceptance_check: true
  requires_review_evidence: true
  requires_architecture_evidence: true
  requires_failure_attribution: false
  requires_intervention_record: false
  requires_command_ledger: true
  requires_sandbox_verification: false
  requires_subagent_evidence: false
13. Requirements
Must preserve YAML subset compatibility.
Must not require external dependencies.
Must be deterministic.
Must not silently remove existing unknown fields.
Must print summary of selected profile and enabled gates.
Must support dry-run mode.

Suggested extra option:

--dry-run
14. Acceptance Criteria
Minimal profile generates valid .agent/task.yml.
Standard profile generates valid .agent/task.yml.
High-risk selected gates are reflected correctly.
Multiple --allowed and --forbidden flags are supported.
Output passes existing task validation.
bash validate-harness.sh passes.
Capability 3: agent-evidence-bind.sh
15. Purpose

Allow agents to bind run artifacts into acceptance criteria without manually editing evidence paths.

Target command:

bash scripts/agent-evidence-bind.sh \
  --run .agent/runs/20260627-091500 \
  --acceptance .agent/acceptance.yml \
  --criterion AC-1 \
  --gate agent-verify

Expected result:

acceptance:
  criteria:
    - id: AC-1
      description: "Verification passed."
      met: true
      evidence_refs:
        - type: finish_summary_json
          path: ".agent/runs/20260627-091500/finish-summary.json"
          gate: "agent-verify"
          expected_exit_status: 0
16. CLI
scripts/agent-evidence-bind.sh [options]

Options:

--run PATH
--acceptance PATH
--criterion ID
--gate GATE_NAME
--type TYPE
--path PATH
--overall-result pass|fail|warn
--expected-exit-status N
--must-contain TEXT
--must-not-contain TEXT
--replace
--append
--dry-run

Defaults:

--acceptance .agent/acceptance.yml
--type finish_summary_json
--overall-result pass
--expected-exit-status 0
--append
17. Behavior

If --run is provided:

Locate finish-summary.json.
Validate that it exists.
Parse gate statuses.
If --gate is provided, find that gate.
Bind expected_exit_status from the actual gate unless explicitly passed.
Write or update the matching criterion.

If criterion does not exist:

Fail by default.
Do not invent acceptance criteria unless an explicit --create-criterion option is implemented later.

Idempotency:

Running the same command twice should not create duplicate refs.
18. Acceptance Criteria
Binds valid finish_summary_json evidence.
Fails if run directory is missing.
Fails if finish-summary.json is missing.
Fails if gate is missing.
Does not duplicate existing equivalent refs.
Output passes check-evidence-refs.py.
Output passes check-acceptance.sh in strict mode.
bash validate-harness.sh passes.
Capability 4: Failed-run Repair Protocol
19. Purpose

Give agents a deterministic repair flow when agent-finish.sh fails.

Mature agent workflows must handle failure, not only success.

20. Add Documentation

Add:

docs/agent/repair-failed-run.md

The document should define failure classes:

check-agent-md failed
check-scope failed
check-policy failed
check-tdd-evidence failed
check-acceptance failed
check-review-evidence failed
check-architecture-evidence failed
check-failure-attribution failed
check-interventions failed
check-command-ledger failed
check-sandbox-evidence failed
check-subagent-evidence failed
validate-episode failed
agent-verify failed
resource-envelope failed

For each failure class, define:

Meaning
Primary evidence file
Likely cause
Agent repair procedure
Human escalation condition
21. Required Repair Procedures
21.1 Scope failure

Agent should:

Inspect .agent/runs/<timestamp>/scope-result.txt.
Inspect .agent/runs/<timestamp>/changed-files.txt.
If change is out of scope, revert or ask for explicit scope expansion.
Do not silently widen allowed_paths to fit accidental edits.
21.2 Policy failure

Agent should:

Inspect policy-result.txt.
Identify protected path.
If not required, avoid protected path.
If required, stop for human approval.
Do not self-approve high-risk changes.
21.3 Verification failure

Agent should:

Inspect verify-result.txt.
Fix code or tests.
Rerun verification.
Rerun finish gate.
21.4 Acceptance failure

Agent should:

Inspect acceptance-result.txt.
If evidence_refs are missing, locate latest .agent/runs/<timestamp>/.
Bind evidence using agent-evidence-bind.sh.
Rerun check-acceptance.sh.
Rerun agent-finish.sh.
21.5 Architecture failure

Agent should:

Inspect architecture-evidence-result.txt.
Determine whether invariant is actually violated or evidence is incomplete.
Fix design if violated.
Add sensor-backed evidence if evidence is incomplete.
Do not mark violated invariants as upheld without supporting evidence.
22. Adapter Updates

Update adapter prompts / skills:

adapters/codex/
adapters/claude-code/

They should instruct agents:

Never claim completion after failed finish gate.
Read the specific gate result file.
Repair based on failure class.
Rerun the failed gate.
Rerun agent-finish.sh.
23. Acceptance Criteria
Repair doc exists.
Codex adapter references the repair protocol.
Claude Code adapter references the repair protocol.
Failure outputs in relevant scripts include actionable next steps.
bash validate-harness.sh passes.
Capability 5: Architecture Fitness Sensor Pattern
24. Purpose

Move architecture evidence from pure self-attestation toward command-backed invariants.

Current architecture evidence validates structured fields such as status, reviewer, evidence, and invariants. This is useful, but still primarily self-reported.

Target:

architecture:
  status: upheld
  reviewer: "agent"
  invariants:
    - id: ARCH-IMPORT-1
      description: "CLI layer must not import test fixtures."
      status: upheld
      evidence_refs:
        - type: command_output
          path: ".agent/runs/20260627-091500/import-boundaries.txt"
          must_contain:
            - "IMPORT_BOUNDARY_RESULT=pass"
25. Add Sensor Examples

Add example patterns, not necessarily universal enforcement.

Suggested files:

docs/agent/architecture-sensors.md
examples/architecture-sensors/import-boundary/
examples/architecture-sensors/generated-files-clean/
examples/architecture-sensors/public-api-contract/

Optional template scripts:

templates/scripts/check-import-boundaries.py
templates/scripts/check-generated-files-clean.sh
templates/scripts/check-public-api-contract.sh

If adding scripts, keep them configurable and conservative.

26. Sensor Requirements

A sensor should:

Run locally.
Use no external dependencies unless explicitly configured by the repo.
Emit stable result markers.
Be usable from .agent/harness.yml.
Be referenceable through evidence_refs.

Example marker:

IMPORT_BOUNDARY_RESULT=pass
IMPORT_BOUNDARY_RESULT=fail
27. Acceptance Criteria
At least one architecture sensor example exists.
The example shows .agent/harness.yml integration.
The example shows .agent/architecture.yml evidence_refs integration.
Documentation states that sensors strengthen evidence but do not guarantee semantic correctness.
bash validate-harness.sh passes.
Capability 6: Dogfood Examples and Adoption Walkthroughs
28. Purpose

Prove that real agents can operate the harness end-to-end.

Add examples that show not just final config, but workflow traces.

29. Required Examples

Add at least these:

examples/docs-only-change/
examples/bugfix-with-evidence-refs/
examples/feature-with-acceptance/
examples/high-risk-policy-change/
examples/failed-run-repair/
examples/existing-repo-adoption/

Each example should contain:

README.md
.agent/task.yml
.agent/harness.yml
.agent/policy.yml where relevant
.agent/acceptance.yml where relevant
sample-run/finish-summary.json
sample-run/verify-result.txt
handoff.md
30. Example README Structure

Each example README should include:

Scenario
Initial task
Profile selected
Commands run
Expected failure, if any
Repair step, if any
Final finish result
What the agent is allowed to claim
What the agent is not allowed to claim
31. Acceptance Criteria
At least three examples are added in the first PR.
At least one example includes a failed run and repair.
At least one example includes strict evidence_refs.
At least one example includes high-risk policy behavior.
Examples are referenced from README.
bash validate-harness.sh passes.
Capability 7: Stability Contract
32. Purpose

Define which interfaces external users and agents may rely on.

Add:

docs/stability-contract.md
33. Stable Interfaces

Mark as stable or intended-stable:

scripts/agent-finish.sh CLI
scripts/agent-preflight.sh CLI
finish-summary.json core fields
AGENT_FINISH_RESULT=pass|fail
HARNESS_VERIFY_RESULT=pass|warn|fail
.agent/task.yml core fields
.agent/harness.yml verification.required
.agent/policy.yml risk_files.high
evidence_refs MVP fields
.agent/runs/<timestamp>/ directory convention
34. Experimental Interfaces

Mark as experimental:

entropy audit
subagent packet format
sandbox evidence format
architecture evidence schema
adapter-specific prompts
repair skills
future architecture sensors
35. Compatibility Rules

Define:

Patch version:
- no breaking changes to stable scripts or core JSON fields

Minor version:
- may add fields
- may add optional gates
- may add new evidence_ref types

Major version:
- may remove deprecated fields
- may change default strictness
- may remove legacy approval behavior
36. Deprecation Policy

Add a policy:

Deprecated fields or behaviors should remain for at least one minor version unless they are unsafe.
Warnings should be emitted before removal.
Legacy approval paths should be explicitly marked deprecated before stricter defaults are introduced.
37. Acceptance Criteria
Stability contract document exists.
README links to it.
Public packaging doc references it.
finish-summary.json stable fields are listed.
Experimental features are clearly marked.
bash validate-harness.sh passes.
38. Recommended Implementation Order

Do not implement all capabilities in one PR.

Recommended sequence:

PR 1: Artifact-backed evidence_refs

Includes:

schemas/evidence-ref.schema.json
templates/scripts/check-evidence-refs.py
check-acceptance.sh strict_refs support
tests for strict evidence refs
README / Gate Guide docs
PR 2: Evidence binding helper

Includes:

scripts/agent-evidence-bind.sh
tests
docs
strict acceptance example
PR 3: Task profile helper

Includes:

scripts/agent-task-profile.sh
tests
Gate Guide update
adapter prompt update
PR 4: Repair failed run protocol

Includes:

docs/agent/repair-failed-run.md
adapter updates
failure message improvements
tests where applicable
PR 5: Architecture sensor examples

Includes:

docs/agent/architecture-sensors.md
examples/architecture-sensors/*
optional template scripts
PR 6: Dogfood examples + stability contract

Includes:

examples/*
docs/stability-contract.md
README links
public packaging update
39. Global Completion Criteria

The productization track is complete when:

Agents can generate .agent/task.yml through a helper.
Agents can bind evidence refs through a helper.
Acceptance evidence can be artifact-backed and strict.
Failed runs have a documented repair protocol.
At least one architecture sensor pattern is documented.
At least three real workflow examples exist.
Stable vs experimental interfaces are documented.
No external dependencies are introduced.
Default behavior remains backward-compatible unless explicitly changed in a major version.
The project still avoids claiming sandboxing, runtime enforcement, or semantic correctness guarantees.
bash validate-harness.sh passes.
CI continues to run the validation path.
40. Definition of Mature Pilot

After PR 1–4, the project may be described as:

A repo-local, agent-facing completion and evidence harness suitable for controlled AI coding workflow pilots.

Do not yet describe it as:

production-grade agent governance
secure sandbox
semantic correctness framework
complete agent runtime
41. Definition of Mature OSS Framework

After PR 1–6, with dogfood examples and stability contract, the project may be described as:

A repo-local agent engineering framework for completion discipline, task scope control, verification evidence, repairable failed runs, and artifact-backed handoff across AI coding agents.

Still do not claim:

security isolation
semantic correctness guarantees
provider-native tracing
runtime tool orchestration