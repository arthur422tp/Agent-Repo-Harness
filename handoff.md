# handoff.md

## Current Task
Prepare Agent-Repo-Harness for the v0.1.0 public baseline by clarifying the
handoff/evidence model.

## Current State
Completed. The task flag semantics now use `expects_handoff_update` for an
advisory workflow expectation, the docs clarify that handoff freshness is not
enforced by `scripts/agent-finish.sh`, and `README.zh-TW.md` now includes the
same Evidence Vs Handoff model.

## Changed Files
- `README.md`
- `README.zh-TW.md`
- `docs/handoff.md`
- `docs/public-packaging.md`
- `docs/plans/agent-harness-optimization-plan.md`
- `schemas/task.schema.json`
- `templates/.agent/task.yml`
- `templates/scripts/validate-task.sh`
- `examples/universal-minimal-repo/.agent/task.yml`
- `tests/harness/doc-consistency.sh`
- `tests/harness/static-install.sh`
- `tests/harness/template-sync.sh`
- `handoff.md`

## Verification
- `bash validate-harness.sh`: pass
- `bash templates/scripts/check-doc-links.sh .`: pass
- Notes: Ruby was unavailable, so the validation script skipped its optional
  Ruby YAML/JSON syntax subchecks. All runnable harness suites passed.

## GitHub Metadata Check
- Public GitHub page/API currently report no repository description and no
  topics.
- Recommended metadata remains in `docs/public-packaging.md`.

## Evidence Model
- `.agent/runs/<timestamp>/`: authoritative script-generated completion
  evidence from `scripts/agent-finish.sh`.
- `handoff.md`: human-readable continuity note.
- `.agent/handoff.yml`: optional machine-readable continuity mirror.

## Open Issues
- None known.

## Next Recommended Step
- Review the public-baseline wording and commit when ready.
