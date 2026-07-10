# Usage With Agents

Agent-Repo-Harness is designed so users do not need to paste a long workflow
prompt every time. Keep live prompts short and move reusable rules into repo
files, scripts, skills, and adapters.

## Shared Pattern

Choose completion evidence with the [Gate Guide](agent/gate-guide.md): start
with Minimal, use Standard for behavior changes, and add High-Risk evidence
only for named risks. These profiles are documentation guidance, not runtime
configuration; the existing `.agent/task.yml` flags remain authoritative.

Use repo files for durable context:

- `agent.md`: stable repo map and operating rules
- `handoff.md`: concise human-readable current task state
- `.agent/handoff.yml`: optional machine-readable handoff state
- `.agent/policy.yml`: high-risk files and approval rules
- `.agent/task.yml`: current task scope and completion requirements
- `.agent/tdd-evidence.yml`: red/green/refactor evidence for tasks that
  explicitly require TDD evidence
- `.agent/episode.yml`: optional episode package metadata for the current
  work episode
- `.agent/failure-attribution.yml`: optional Failure attribution evidence for
  repaired or failure-prone tasks
- `.agent/interventions.yml`: optional intervention records for material
  human, tool, or runtime actions
- `.agent/subagent-packet.yml`: optional controller-agent to subagent handoff
  context for delegated work
- `.agent/subagent-runs/`: optional controller-agent evidence from delegated
  subagent runs
- `.agent/sandbox-runs/`: optional sandbox verification evidence from
  `scripts/agent-sandbox-run.sh`

Use scripts for gates:

```bash
scripts/agent-preflight.sh
scripts/validate-handoff.sh
scripts/validate-subagent-packet.sh
scripts/validate-subagent-run.sh
scripts/check-policy.sh
scripts/check-scope.sh
scripts/check-tdd-evidence.sh
scripts/check-failure-attribution.sh
scripts/check-interventions.sh
scripts/agent-run.sh
scripts/agent-sandbox-run.sh
scripts/agent-verify.sh
scripts/agent-finish.sh
scripts/agent-audit.sh
```

Scope checks compare current changes against the repository's git state. After
a fresh harness install, review and customize the scaffold files, then commit a
clean baseline before starting feature work:

```bash
git add .
git commit -m "Initialize project with Agent-Repo-Harness baseline"
```

If the baseline is not committed, `scripts/check-scope.sh` may count unrelated
Agent-Repo-Harness scaffold files as changed and make scope warnings look like
feature-work drift.

`agent-finish.sh` records evidence under `.agent/runs/<timestamp>/`, including
`finish-summary.md`, per-gate result files, `tdd-evidence-result.txt`,
`episode-summary.json`, `changed-files.txt`, and `git-diff-stat.txt`.

Use the [Gate Guide](agent/gate-guide.md) for TDD, Command ledger, and sandbox
gate selection and evidence paths. Enable each only when its named task risk
requires it.

Keep `handoff.md` concise for humans and future agents. Agents may mirror
structured current task state in `.agent/handoff.yml` for validators, CI,
controller agents, and future automation.

## Episode, Failure, And Intervention Evidence

`.agent/episode.yml` supplies optional episode metadata, and finish runs write
`episode-summary.json`. Select Failure attribution and intervention gates with
the [Gate Guide](agent/gate-guide.md), and record only concrete evidence.

Use `scripts/agent-audit.sh` for maintenance entropy checks. It writes
`.agent/audits/<timestamp>/entropy-report.json` and a Markdown report, but it
does not replace `scripts/agent-finish.sh`.

See [agent/episode-package.md](agent/episode-package.md),
[agent/failure-attribution.md](agent/failure-attribution.md),
[agent/interventions.md](agent/interventions.md), and
[agent/entropy-audit.md](agent/entropy-audit.md).

## Operational Boundaries

The harness targets Unix-like shell environments, primarily Linux, macOS, WSL,
and Git Bash. Native PowerShell support is not currently a goal.

`scripts/agent-verify.sh` provides convenience heuristics for common project
shapes. When a repository declares project-specific verification commands in
`.agent/harness.yml`, those commands are the source of truth.

Use `verification.profiles` to centralize commands for bootstrap, feature, or
release stages, then select one with `task.verification_profile`. The selected
profile replaces `verification.required`. Repo-defined commands are
authoritative; language heuristics run only when no configured command set
exists.

`.agent/runs/`, `.agent/audits/`, `.agent/command-runs/`, and
`.agent/sandbox-runs/` are generated local evidence. Do not add them to task
`allowed_paths` merely to satisfy scope. Tracked files in those directories
remain scope-controlled.

Scope and policy gates are process guardrails, not security boundaries. They
inspect Git changes and repo-local policy patterns; they do not isolate the
filesystem, network, secrets, or command side effects, and do not guarantee
semantic correctness.

## Context Loading Policy

Use staged context loading to keep agent runs token-efficient:

1. Start with durable context: `AGENTS.md`, `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries.
2. Run `scripts/collect-context.sh` when available instead of pasting long prompt context.
3. Expand to raw source only for files directly relevant to the current task.
4. Prefer `rg`, file lists, symbol search, and targeted file ranges over reading whole directories.
5. Save repeated discoveries in `docs/agent/discoveries.md` or compact stable facts in `agent.md`.

Short prompt:

```text
Use staged context loading.
Read the installed agent entrypoint, stable repo memory, handoff, task scope, and applicable policy first.
Use `scripts/collect-context.sh` if available.
Expand only into files relevant to this task.
```

Subagent packets are intended for controller-agent to subagent handoffs. A
controller can fill `.agent/subagent-packet.yml` and validate it before
delegation. Use the [Gate Guide](agent/gate-guide.md) to decide whether the task
also needs subagent completion evidence.

## Subagent Run Evidence

When a controller delegates work, it can copy the packet into a new directory
before or after the delegated run:

```text
.agent/subagent-runs/<timestamp>-<role>-<task_id>/
  packet.yml
  result.md
  status.txt
```

`result.md` records what the subagent did, including files inspected, files
changed, verification run, findings, concerns, and recommended next action.
`status.txt` records the final status as exactly one of `DONE`,
`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.

Validate the evidence with:

```bash
bash scripts/validate-subagent-run.sh .agent/subagent-runs/<timestamp>-<role>-<task_id>
```

The [Gate Guide](agent/gate-guide.md) explains when
`completion.requires_subagent_evidence: true` should require one of these run
directories; otherwise they remain optional continuity artifacts.

`agent-finish.sh` writes both human-readable and machine-readable evidence:

- `finish-summary.md`: concise Markdown summary for humans and future agents
- `finish-summary.json`: structured run summary for tools, CI, and controller agents
- `*-result.txt`: per-gate command output
- `changed-files.txt`: changed-file evidence
- `git-diff-stat.txt`: diff-size evidence

Treat `finish-summary.json` as the stable machine-readable run envelope. Treat
the text files as the source for detailed command output.

## Codex

Install `AGENTS.md` in the repository root. A reusable template is available at
`templates/AGENTS.md`, and a Codex-specific adapter is available at
`adapters/codex/AGENTS.md`.

Recommended start prompt:

```text
You are working in this repository using Agent-Repo-Harness.
First read `AGENTS.md`, then follow its instructions.
Use staged context loading: inspect `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries before expanding to raw source.
For delegated work, fill `.agent/subagent-packet.yml` and run `scripts/validate-subagent-packet.sh`.
Respect task boundaries.
Before claiming completion, run `scripts/agent-finish.sh`.
If verification cannot be run, explain exactly why and update `handoff.md`; optionally mirror structured state in `.agent/handoff.yml`.
```

See [codex-usage.md](codex-usage.md).

## Claude Code

Install `CLAUDE.md` in the repository root. A reusable template is available at
`templates/CLAUDE.md`, and a Claude Code adapter is available at
`adapters/claude-code/CLAUDE.md`.

For Claude Code project skills, copy or install:

```text
adapters/claude-code/.claude/skills/harness-entrypoint/SKILL.md
adapters/claude-code/.claude/skills/policy-gate/SKILL.md
adapters/claude-code/.claude/skills/verification-gate/SKILL.md
adapters/claude-code/.claude/skills/handoff-update/SKILL.md
adapters/claude-code/.claude/skills/subagent-context-packet/SKILL.md
```

Use those skills for repeated workflow instead of putting a long instruction
block in every prompt.

## Superpowers

Existing Superpowers-compatible skills remain supported:

- `harness-entrypoint`
- `repo-context-bootstrap`
- `repo-map-maintenance`
- `handoff-update`
- `subagent-context-packet`
- `policy-gate`
- `verification-gate`
- `discoveries-memory`
- `domain-risk-review`

Superpowers remains the workflow discipline layer for planning, TDD,
subagent-driven development, review, and finishing branches. Agent-Repo-Harness
adds repo-local context, task boundaries, policy gates, and verification gates.
Agents using Superpowers should also consult
[superpowers-integration.md](superpowers-integration.md) for the mapping between
Superpowers skills and harness contracts.

Subagent packets remain optional. Use `.agent/subagent-packet.yml` and
`scripts/validate-subagent-packet.sh` when delegating precise work to a fresh
subagent; packet validation is not part of `scripts/agent-finish.sh` yet.
Pair packets with `.agent/subagent-runs/<timestamp>-<role>-<task_id>/` when
you want durable trace evidence for what the subagent did.

Short prompt:

```text
Use $harness-entrypoint for this task.
Use $policy-gate if you touch high-risk files.
Use $verification-gate before completion.
Use $handoff-update if task state changes.

Task:
[task here]
```

## Generic Agents

Generic coding agents can use the harness without adapter-specific skill
support:

1. Read `AGENTS.md`.
2. Inspect `agent.md`, `handoff.md`, `.agent/task.yml`, and applicable `.agent/policy.yml` entries.
3. Fill `.agent/subagent-packet.yml` only when handing work to a subagent.
4. Run `scripts/agent-preflight.sh`.
5. Modify only files allowed by `.agent/task.yml`.
6. Run `scripts/agent-finish.sh` before reporting completion.
7. Update `handoff.md` and optionally mirror structured state in `.agent/handoff.yml`.

## Avoid This

Do not repeat the full harness workflow in every task prompt. Do not put a
current implementation plan in `agent.md`. Do not treat the harness as a
runtime orchestrator or MCP server; see [Operational Boundaries](#operational-boundaries)
for its guardrail and verification limits.
