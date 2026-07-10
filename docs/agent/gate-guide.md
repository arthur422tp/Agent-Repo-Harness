# Gate Guide

Use this guide to choose existing Agent-Repo-Harness completion gates. Profiles
are rendered into `.agent/task.yml` by `scripts/agent-task-profile.sh`. The
harness enforces the generated flags rather than reading a profile name at
finish time.

`scripts/agent-task-profile.sh` rewrites the output task file. Use `--dry-run`
before applying when preserving custom task fields matters.

## Verification Profiles

The repository owns commands in `.agent/harness.yml`. A task may select one
named command set without copying commands into `.agent/task.yml`:

```bash
bash scripts/agent-task-profile.sh standard \
  --goal "Build package baseline" \
  --verification-profile bootstrap \
  --allowed "src/**"
```

When `task.verification_profile` is absent, the harness uses
`verification.required`. When present, it replaces the default list with
`verification.profiles.<name>.required`. Profile commands must reference only
artifacts that exist during that task. Repo-defined commands are authoritative;
language heuristics are fallback behavior only.

## Minimal Profile

Use for small, low-risk maintenance work.

```bash
bash scripts/agent-task-profile.sh minimal --goal "Docs cleanup" --allowed "docs/**"
```

## Standard Profile

Use for normal feature, bug-fix, refactoring, and behavior-change work.

```bash
bash scripts/agent-task-profile.sh standard --goal "Bugfix with tests" --allowed "src/**" --allowed "tests/**"
```

## High-Risk Profile

Use for security-sensitive, architectural, release-critical, delegated, or
environment-sensitive work. Start with Standard and enable only the additional
evidence that matches the actual risk.

Start with the Standard profile. Add only the applicable options from this
menu:

```bash
bash scripts/agent-task-profile.sh high-risk --goal "Policy change" --allowed ".agent/policy.yml" --review --command-ledger
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

Use the bind helper after a finish run when an existing acceptance criterion
should point at that run's gate evidence:

```bash
bash scripts/agent-evidence-bind.sh \
  --run .agent/runs/20260627-091500 \
  --acceptance .agent/acceptance.yml \
  --criterion AC-1 \
  --gate agent-verify
```

## Selection Rules

1. Start with Minimal.
2. Use Standard for behavior changes.
3. Add High-Risk gates only when they answer a named risk.
4. Do not enable evidence gates merely because they exist.
5. Record exceptions and material manual actions through existing intervention
   or handoff evidence instead of adding new gate types.
