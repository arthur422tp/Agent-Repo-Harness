# Episode Package

An episode package is the local evidence bundle for one agent work episode. It
connects task intent, enabled evidence contracts, finish-run outputs, and
machine-readable summaries without claiming to capture a provider-native trace.

## Inputs

- `.agent/episode.yml`: episode id, objective, actor, status, and context.
- `.agent/task.yml`: task scope and enabled completion gates.
- `.agent/policy.yml`: local policy rules for high-risk paths and protected
  changes.
- `.agent/harness.yml`: configured scripts, verification commands, resource
  limits, and audit command.
- Optional evidence files such as `.agent/failure-attribution.yml`,
  `.agent/interventions.yml`, `.agent/acceptance.yml`, `.agent/review.yml`,
  `.agent/architecture.yml`, and `.agent/subagent-runs/`.

## Outputs

- `.agent/runs/<timestamp>/finish-summary.md`: human-readable finish evidence.
- `.agent/runs/<timestamp>/finish-summary.json`: machine-readable finish
  summary.
- `.agent/runs/<timestamp>/episode-summary.json`: machine-readable episode
  package summary.
- `.agent/runs/<timestamp>/changed-files.txt`: changed-file evidence captured
  from the local Git state.
- `.agent/runs/<timestamp>/git-diff-stat.txt`: local Git diff-stat evidence.
- Gate result files in `.agent/runs/<timestamp>/`, including
  `episode-result.txt` and any enabled evidence gate outputs.

## Rule

Keep `.agent/episode.yml` status and objective aligned with the current task.
Run `scripts/agent-finish.sh` to produce episode package outputs. Use
`finish-summary.json` for completion status automation. Use
`episode-summary.json` to find the contracts and evidence files that belong to
the episode. Do not treat the episode package as sandboxing, secret isolation,
model-cost accounting, or a full tool-call replay.
