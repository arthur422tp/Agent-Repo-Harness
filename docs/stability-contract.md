# Stability Contract

This document defines which Agent-Repo-Harness interfaces external users and
agents may rely on.

## Stable Interfaces

- `scripts/agent-finish.sh --strict`
- `scripts/agent-finish.sh --best-effort`
- `scripts/agent-preflight.sh`
- `.agent/runs/<timestamp>/`
- `AGENT_FINISH_RESULT=pass|fail`
- `HARNESS_VERIFY_RESULT=pass|warn|fail`
- `.agent/task.yml` core fields: `task.status`, `task.goal`,
  `task.allowed_paths`, `task.forbidden_paths`, and `task.completion`
- `.agent/harness.yml` `verification.required`
- `.agent/policy.yml` `risk_files.high`

## Intended-Stable Interfaces

- `scripts/agent-task-profile.sh` CLI
- `scripts/agent-evidence-bind.sh` CLI
- `scripts/check-evidence-refs.py` CLI
- `task.verification_profile`
- `.agent/harness.yml` `verification.profiles`
- `finish-summary.json` core fields: `overall_result`, `mode`, `run_dir`,
  `gates`, `changed_files`, `diff_stat`, and `elapsed_seconds`
- `evidence_refs` MVP fields: `type`, `path`, `command`, `gate`,
  `expected_exit_status`, `overall_result`, `must_contain`, and
  `must_not_contain`

## Internal Implementation Details

Files under `scripts/lib/` are internal implementation details. Downstream
repositories should invoke public scripts rather than source internal libraries.
Internal library functions may change within a minor release when the stable and
intended-stable public contracts remain compatible.

## Experimental Interfaces

- Entropy audit reports
- Subagent packet format
- Sandbox evidence format
- Architecture evidence schema
- Adapter-specific prompts
- Repair skills and repair prompt wording
- Architecture sensor examples

## Compatibility Rules

Patch versions do not intentionally break stable scripts or core JSON fields.

Minor versions may add optional fields, optional gates, helper scripts, and new
`evidence_refs` types.

Agent-facing helper scripts are intended-stable in v0.x. Patch versions should
not intentionally break their basic invocation forms. Minor versions may add
options. Breaking changes require deprecation warnings before removal when
feasible.

Major versions may remove deprecated fields, change default strictness, or
remove legacy approval behavior.

## Deprecation Policy

Deprecated fields or behaviors should remain for at least one minor version
unless they are unsafe. Warnings should be emitted before removal when a script
can detect the deprecated behavior. Legacy approval paths should be explicitly
marked deprecated before stricter defaults are introduced.

## Boundary

This stability contract does not turn Agent-Repo-Harness into a sandbox, full
runtime, provider-native tracing layer, or semantic correctness framework.
