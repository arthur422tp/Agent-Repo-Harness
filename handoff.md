# handoff.md

## Current State

Command ledger evidence has been designed and implemented. Installed projects
can run important commands through the command runner, store
`.agent/command-runs/<timestamp>/command-summary.json`, and optionally require
command ledger evidence during finish.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- Installed target command ledger smoke: PASS in `/private/tmp/agent-harness-command-ledger-target`
- `bash templates/scripts/agent-audit.sh`: PASS

## Evidence

- Latest installed command run: `/private/tmp/agent-harness-command-ledger-target/.agent/command-runs/20260620-033521/`
- Latest installed finish run: `/private/tmp/agent-harness-command-ledger-target/.agent/runs/20260620-033521/`
- Latest source audit run: `.agent/audits/20260620-033527/`

## Next Action

Decide whether command ledger evidence should become required for selected
high-risk or release tasks by setting `completion.requires_command_ledger:
true` in those task files.
