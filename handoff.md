# handoff.md

## Current Task
Prepare Agent-Repo-Harness for the v0.1.0 public baseline by clarifying the
handoff/evidence model.

## Current State
Completed. The task flag semantics now use `expects_handoff_update` for an
advisory workflow expectation, and the docs clarify that handoff freshness is
not enforced by `scripts/agent-finish.sh`.

## Changed Files
- `README.md`
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
- Notes: Ruby was unavailable, so the validation script skipped its optional
  Ruby YAML/JSON syntax subchecks. All runnable harness suites passed.

## Evidence Model
- `.agent/runs/<timestamp>/`: authoritative script-generated completion
  evidence from `scripts/agent-finish.sh`.
- `handoff.md`: human-readable continuity note.
- `.agent/handoff.yml`: optional machine-readable continuity mirror.

## Open Issues
- None known.

## Next Recommended Step
- Review the public-baseline wording and commit when ready.
