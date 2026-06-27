# Gate Guide

Use this guide to choose existing Agent-Repo-Harness completion gates. Profiles are recommendations expressed through existing `.agent/task.yml` flags. The
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
| Acceptance | `requires_acceptance_check` | false | explicit user-visible criteria must be proven | `.agent/acceptance.yml`; optional `evidence_refs`; `check-acceptance.sh` | criteria are unmet, lack evidence, or strict refs are invalid |
| Review | `requires_review_evidence` | false | independent approval is required | `.agent/review.yml`; `check-review-evidence.sh` | review is missing or blocking |
| Architecture | `requires_architecture_evidence` | false | tests cannot prove design invariants | `.agent/architecture.yml`; `check-architecture-evidence.sh` | required invariants are not upheld |
| Failure attribution | `requires_failure_attribution` | false | repaired or recurring failures need root-cause evidence | `.agent/failure-attribution.yml`; `check-failure-attribution.sh` | attribution evidence is incomplete |
| Interventions | `requires_intervention_record` | false | approvals, overrides, or manual actions materially changed the run | `.agent/interventions.yml`; `check-interventions.sh` | intervention record is incomplete |
| Command ledger | `requires_command_ledger` | false | important local commands need replayable evidence | `.agent/command-runs/`; `agent-run.sh` | ledger evidence is missing or malformed |
| Sandbox verification | `requires_sandbox_verification` | false | final verification must run in an external container boundary | `.agent/sandbox-runs/`; `agent-sandbox-run.sh` | passing sandbox evidence is missing |
| Subagent evidence | `requires_subagent_evidence` | false | delegated execution must be proven | `.agent/subagent-runs/`; `check-subagent-evidence.sh` | delegated run evidence is missing or invalid |
| Episode metadata | none | validated when available | episode-level metadata is useful | `.agent/episode.yml`; `validate-episode.sh` | episode metadata is invalid |
| Resource envelope | harness config | disabled with zero limits | finish duration or changed-file count needs a local cap | `.agent/harness.yml`; `agent-finish.sh` | configured local limit was exceeded |

## Evidence References

Text evidence is acceptable in low-risk/default mode. For Standard profile
tasks, prefer `evidence_refs` when the evidence already exists as a local
artifact such as `.agent/runs/<timestamp>/finish-summary.json` or a gate output
file. For High-Risk profile tasks, set `evidence.strict_refs: true` and
`evidence.allow_text_only_evidence: false` when acceptance proof should be tied
to verifiable repo-local artifacts.

`evidence_refs` strengthens traceability by checking file existence, optional
content markers, and selected finish-summary fields. It does not prove semantic
correctness beyond the configured checks.

## Selection Rules

1. Start with Minimal.
2. Use Standard for behavior changes.
3. Add High-Risk gates only when they answer a named risk.
4. Do not enable evidence gates merely because they exist.
5. Record exceptions and material manual actions through existing intervention
   or handoff evidence instead of adding new gate types.
