# Entropy Audit

`scripts/agent-audit.sh` produces a local maintenance audit for harness drift.
It is useful between tasks, before publishing, or when a repository owner wants
a quick check of documentation links, Git state, and harness config validity.

## Command

```bash
bash scripts/agent-audit.sh
```

## Outputs

The script writes an audit directory under `.agent/audits/<timestamp>/` with:

- `entropy-report.md`: human-readable audit summary.
- `entropy-report.json`: machine-readable audit summary.
- `doc-links.txt`: documentation link check output when available.
- `git-status.txt`: Git status output when available.
- `harness-config.txt`: harness config validation output when available.

The command prints `AGENT_AUDIT_RESULT=pass` or `AGENT_AUDIT_RESULT=fail`.

## Rule

Use `scripts/agent-audit.sh` for maintenance and drift checks. It does not
replace `scripts/agent-finish.sh`, does not prove task completion, and does not
provide sandboxing, secret isolation, provider trace capture, or model-cost
accounting.
