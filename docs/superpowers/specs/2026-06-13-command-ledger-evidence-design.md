# Command Ledger Evidence Design

## Goal

Add an explicit command ledger evidence path so agents can record important
local commands, outputs, exit statuses, and replay metadata without claiming
provider-native tracing or automatic tool-call interception.

## Scope

This phase adds a repo-local command runner wrapper and an optional finish gate.
It does not automatically capture all agent tool calls, intercept provider
runtime activity, import hosted trace data, enforce token or model cost budgets,
or guarantee semantic correctness.

## Architecture

Command ledger evidence is explicit. Agents record important commands by
running them through the installed agent-run command in a target repository.
The wrapper writes a
durable command run directory under `.agent/command-runs/<timestamp>/` and
returns the wrapped command's exit status.

The finish gate remains opt-in. A task can set
`task.completion.requires_command_ledger: true` to require valid command
ledger evidence before completion. When the flag is missing or false,
the installed command-ledger check reports pass without requiring evidence.

This feature complements `finish-summary.json`; it does not replace existing
gate evidence. The installed finish command should include the command ledger gate
status and evidence path in both the Markdown and JSON finish summaries.

## Components

### Command Runner Wrapper

The proposed template script `templates/scripts/agent-run.sh` records a single
command invocation. Installed target repositories should support this usage:

```text
agent-run -- npm test
agent-run -- bash validate-harness.sh
```

For each invocation, it writes:

- `.agent/command-runs/<timestamp>/command.txt`
- `.agent/command-runs/<timestamp>/cwd.txt`
- `.agent/command-runs/<timestamp>/stdout.txt`
- `.agent/command-runs/<timestamp>/stderr.txt`
- `.agent/command-runs/<timestamp>/exit-status.txt`
- `.agent/command-runs/<timestamp>/command-summary.json`

If a timestamp directory already exists, the runner should create a suffixed
directory such as `<timestamp>-01`. The wrapper should not include environment
variable values in `command-summary.json`.

### Command Ledger Gate

The proposed template script `templates/scripts/check-command-ledger.sh`
validates command ledger evidence when required by `.agent/task.yml`.

When command ledger evidence is not required, the gate reports:

```text
COMMAND_LEDGER_RESULT=pass
```

When evidence is required, the gate requires at least one
`.agent/command-runs/*/command-summary.json` file. Each inspected summary must
be valid JSON and must include:

- `timestamp`
- `command`
- `cwd`
- `exit_status`
- `overall_result`
- `evidence.command`
- `evidence.cwd`
- `evidence.stdout`
- `evidence.stderr`
- `evidence.exit_status`

The gate must verify that referenced evidence files exist. `overall_result`
must be either `pass` or `fail`. A failed command run is still valid ledger
evidence because TDD red phases and diagnostic commands may intentionally fail.

### Task Contract

Add this completion flag:

```yaml
completion:
  requires_command_ledger: false
```

The flag belongs in:

- `templates/.agent/task.yml`
- `schemas/task.schema.json`
- `templates/scripts/validate-task.sh`
- task-validation tests
- installed example task files if they mirror the template

### Finish Integration

The installed finish command should run `check-command-ledger.sh` with the other
optional evidence gates and write:

- `.agent/runs/<timestamp>/command-ledger-result.txt`
- a `check-command-ledger` row in `finish-summary.md`
- a `check-command-ledger` gate entry in `finish-summary.json`

The command ledger gate should fit the existing optional gate pattern:
malformed task configuration fails with an explicit marker, missing evidence
fails only when the task requires it, and successful validation reports a
machine-readable result marker.

### Documentation

README and usage docs should explain that command ledger evidence is explicit:
agents should use the installed `agent-run.sh` command for important commands
when a task or team wants replayable local evidence.

`docs/runtime-boundaries.md` should add explicit command ledger evidence to the
implemented local contracts while preserving the not-implemented boundary for
provider-native trace capture and full automatic tool-call replay.

## Data Flow

```text
agent/user command
  -> installed agent-run command
  -> .agent/command-runs/<timestamp>/command-summary.json
  -> .agent/task.yml completion.requires_command_ledger
  -> installed command-ledger check
  -> installed finish command
  -> .agent/runs/<timestamp>/finish-summary.json
```

## Error Handling

`agent-run.sh` should:

- write complete evidence before exiting
- print `COMMAND_RUN_RESULT=pass` when the wrapped command exits 0
- print `COMMAND_RUN_RESULT=fail` when the wrapped command exits nonzero
- return the wrapped command's exit status
- fail before command execution if invoked without `--` or without a command

`check-command-ledger.sh` should:

- pass when command ledger evidence is not required
- fail with `COMMAND_LEDGER_RESULT=fail` when task YAML is malformed
- fail when evidence is required but no command summaries exist
- fail when a summary is malformed JSON
- fail when required summary fields are missing
- fail when referenced evidence files do not exist
- pass when required evidence exists and command summaries are structurally
  valid, even if some command summaries recorded `overall_result: fail`

## Testing Strategy

Implementation should use TDD and follow the existing shell suite pattern under
`tests/harness/`.

Required coverage:

- command runner pass writes evidence and exits 0
- command runner failure writes evidence and exits with the wrapped command's
  status
- command runner avoids same-second evidence collisions
- command runner summary does not leak environment variable values
- command ledger gate skips when not required
- command ledger gate passes for valid pass summaries
- command ledger gate passes for valid fail summaries
- command ledger gate fails for required missing evidence
- command ledger gate fails for malformed summary JSON
- command ledger gate fails for missing referenced evidence files
- command ledger gate fails for malformed task YAML and prints
  `COMMAND_LEDGER_RESULT=fail`
- finish summaries include command ledger evidence paths
- installed-target smoke can run the installed agent-run command around
  `bash scripts/agent-verify.sh --best-effort` before the installed finish
  command

Final verification should include:

- `bash validate-harness.sh`
- `bash templates/scripts/check-doc-links.sh .`
- installed-target smoke using `install-agent-harness.sh --force <target>`

## Acceptance Criteria

- The command runner creates durable, machine-readable command evidence.
- The optional command ledger gate is controlled by
  `completion.requires_command_ledger`.
- Failed wrapped commands still produce valid evidence.
- Finish Markdown and JSON summaries include command ledger gate status.
- Docs describe the feature as explicit command evidence, not automatic
  provider trace capture.
- Runtime boundary documentation remains truthful.
- Full validation passes.
