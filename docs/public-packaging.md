# Public Packaging

Use this checklist when presenting Agent-Repo-Harness as an adoptable public
repository and when preparing its initial public release.

## Recommended GitHub Repository Description

Repo-local completion gate for AI coding agents.

## Recommended GitHub Topics

- `ai-agents`
- `coding-agents`
- `codex`
- `claude-code`
- `agentic-coding`
- `developer-tools`
- `repo-automation`
- `shell`

## v0.2.0 release checklist

### Locally Verifiable Readiness

- [x] `VERSION` is `0.2.0`.
- [x] `CHANGELOG.md` has a `v0.2.0` entry.
- [x] `README.md` has a CI badge, Quick Start, What It Is Not, Platform Support, Verification Strategy, Evidence vs Handoff, and Guardrails section.
- [x] `install-agent-harness.sh` prints the short 3-step next path.
- [x] The default TDD evidence is opt-in.
- [x] `bash validate-harness.sh` passes locally.
- [x] Public schema installation matches the current source schema set.
- [x] Runtime boundaries and intended-stable interfaces are documented.
- [x] Sandbox smoke is wired into CI and reports `SANDBOX_CI_SMOKE_RESULT=pass|skip|fail`.
- [x] Repository-only release integrity and prior-release upgrade checks are wired into canonical validation.
- [x] `bash ci/release-readiness.sh --from-tag v0.1.1` emits `RELEASE_READINESS_RESULT=pass`; preserve its explicit sandbox pass or skip marker in handoff evidence.

### External Publishing Actions

- [ ] CI is passing on the published default branch.
- [ ] Set the GitHub description.
- [ ] Set the GitHub topics.
- [ ] Create the GitHub release tag `v0.2.0`.
  Only create it from a strict-tag-ready commit.
- [ ] Verify the README renders correctly on GitHub.
- [ ] Verify the CI badge points to `.github/workflows/ci.yml`.
- [ ] Create GitHub release notes from the matching `CHANGELOG.md` section.

## Production-harness follow-up checklist

- [x] `finish-summary.json` is documented and validated by `validate-harness.sh`.
- [x] Resource-envelope limits are documented as local shell limits, not token-cost controls.
- [x] Architecture evidence is documented as an optional semantic/design-risk gate.
- [x] `docs/runtime-boundaries.md` clearly separates implemented guardrails from sandbox/runtime features that are not implemented.
- [x] Public wording avoids claiming filesystem isolation, network isolation, secret isolation, model-cost enforcement, or semantic correctness guarantees.
- [x] Episode package, failure attribution, intervention records, and entropy audit evidence are documented as local harness contracts.

## H3-style harness follow-up checklist

- [x] Episode metadata, generated episode summaries, and finish evidence are covered by `validate-harness.sh`.
- [x] Failure attribution and intervention records are opt-in completion gates.
- [x] Entropy audit reports are available through `scripts/agent-audit.sh` for maintenance checks.
- [x] H3-style workflows are documented without claiming provider-native tracing, sandboxing, or runtime enforcement.
- [x] Latest Task 6 validation evidence is recorded in `handoff.md`.
