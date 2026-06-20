# handoff.md

## Current State

Harness ergonomics and simplification are complete. Gate-selection detail now
lives in `docs/agent/gate-guide.md`, Minimal/Standard/High-Risk profiles remain
documentation-only recommendations, public and installed entrypoints use
concise navigation, and the human-readable finish summary groups existing
checks without changing the JSON contract.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- Installed-target finish smoke: PASS in `/private/tmp/agent-harness-ergonomics-target`
- `bash templates/scripts/agent-audit.sh`: PASS

## Evidence

- Latest installed finish run: `/private/tmp/agent-harness-ergonomics-target/.agent/runs/20260620-125802/`
- Latest source audit run: `.agent/audits/20260620-125815/`

## Compatibility

- No completion flags, schemas, or gates added or removed.
- Gate execution order and strict/best-effort semantics unchanged.
- `finish-summary.json` contract unchanged.

## Next Action

Use the simplified profile guidance in real repositories and collect adoption
feedback before considering additional runtime or evidence capabilities.
