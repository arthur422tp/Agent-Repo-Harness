# handoff.md

## Current State

Verification profiles, authoritative configured commands, and runtime artifact
hygiene are implemented and validated.

## Verification

- `bash tests/harness/verification-lifecycle.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: `DOC_LINKS_RESULT=pass`
- `bash validate-harness.sh`: PASS
- `git diff --check`: PASS

## Compatibility

- Existing `verification.required` remains the default command set.
- Configured projects no longer receive implicit language heuristics.
- Projects without configured commands retain heuristic fallback behavior.

## Next Action

Dogfood bootstrap and release profiles in a second non-Python repository before
expanding profile semantics.
