# Verification Lifecycle And Runtime Hygiene Design

## Goal

Let a task pass the completion gate using only verification that is valid for
its explicitly selected delivery stage, while preventing untracked
harness-generated runtime evidence from polluting later scope checks.

## Problem

`agent-verify.sh` currently runs `verification.required` commands and then
always runs detected language heuristics. A Python task can therefore fail on
global `pytest` or `ruff` checks even when the repository supplied a narrower
verification command. The same configuration cannot express that a bootstrap
task should prove a package import before tests and CLI commands exist.

`check-scope.sh` includes all untracked, non-ignored files. Finish, audit,
command-ledger, and sandbox runs create durable `.agent/` evidence that can
therefore be reported as outside a later task's allowed paths.

## Scope

This design changes verification selection and harness-owned runtime artifact
hygiene only. It does not add a completion gate, infer task phases from plan
checkboxes, make Python packaging decisions for adopters, or change policy
semantics.

## Configuration Model

Keep `verification.required` as the backwards-compatible default command set.
Add optional named profiles beneath `verification.profiles` in
`.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "full suite"
      command: "uv run pytest"
  profiles:
    bootstrap:
      required:
        - name: "package import"
          command: "uv run python -c 'import ops_rulekit'"
    feature:
      required:
        - name: "unit tests"
          command: "uv run pytest tests/unit"
```

Add optional `task.verification_profile` to `.agent/task.yml`.

- When absent, verification uses `verification.required`.
- When present, it must match `[A-Za-z0-9][A-Za-z0-9_-]*` and name an entry in
  `verification.profiles`.
- The selected profile's `required` list replaces the default list; commands
  are not merged.
- An unknown profile is a task-validation error. A selected profile without a
  valid `required` list is a harness-configuration error.

This keeps commands owned centrally by the repository and makes phase choice
an explicit task contract. It deliberately does not use `task.status`,
`source_plan`, or plan checkboxes to infer what should run.

`agent-task-profile.sh` must accept `--verification-profile NAME` and render
`task.verification_profile` when provided. Omitting the option must preserve
the current generated task shape, apart from other changes explicitly made by
the caller.

## Verification Execution

`agent-verify.sh` resolves one repo-defined command set before executing
checks.

1. Resolve a selected profile when `task.verification_profile` is set;
   otherwise resolve `verification.required`.
2. Run each resolved command and continue to record its individual result.
3. Always run local `bash -n` checking for top-level `scripts/*.sh`, preserving
   a cheap harness-script safety check.
4. If any repo-defined command was resolved, emit a clear heuristic-skip
   message and do not run detected Node, Go, Python, or Docker Compose
   heuristics.
5. If no repo-defined command exists, retain the current heuristics as the
   compatibility fallback.

A failed configured command remains a failed verification in both strict and
best-effort modes. Best-effort only changes missing-tool handling, not command
exit failures.

## Runtime Artifact Hygiene

The installer must add a narrowly scoped ignore file or managed ignore block
for only these generated directories:

- `.agent/runs/`
- `.agent/audits/`
- `.agent/command-runs/`
- `.agent/sandbox-runs/`

The installer must preserve existing target `.gitignore` content and avoid
duplicating the managed entries. It must not ignore all of `.agent/`, because
task, policy, config, and optional evidence inputs remain repository-owned.

As defence in depth, `check-scope.sh` must remove the same paths only when they
are untracked. It must print a section naming the ignored runtime files. A
tracked change under those directories remains in `changed_files` and is still
subject to scope and policy rules. `.agent/subagent-runs/` remains outside this
automatic exclusion because it may contain intentional delegated-work evidence.

The framework does not automatically ignore `.python-version`, `__pycache__/`,
or `*.egg-info`. An adopter must choose whether those files are baseline source
files or project-local generated output.

## Validation Contract

Add deterministic temporary-repository coverage for:

1. default `verification.required` commands remain supported;
2. a bootstrap profile runs only its profile commands, not default commands;
3. unknown `task.verification_profile` fails task validation with the profile
   name in the error;
4. configured verification skips Python heuristics even when `pytest` and
   `ruff` are available on PATH;
5. no configured commands retains current heuristic execution;
6. a second scope or finish run passes with untracked harness runtime outputs
   from an earlier run, and reports which paths were ignored;
7. a tracked file under `.agent/runs/` is not filtered and still triggers an
   allowed-path violation;
8. installer output preserves an existing `.gitignore` and is idempotent on a
   second install.

`bash validate-harness.sh` remains the repository-level proof command. The
installed-target smoke and template-sync suite must cover every changed copied
script and template.

## Documentation

Update the English and Traditional Chinese README verification sections and the
canonical gate guide. Explain that profile commands must exist at the selected
task stage, that profiles are optional, and that repo-defined commands suppress
language heuristics. Document runtime directories as generated local evidence,
not task output to be added to `allowed_paths`.

## Compatibility And Rollout

Existing adopters that have only `verification.required` keep their current
configured command behavior, except that unwanted language heuristics no
longer run after configured commands. Repositories without configured commands
keep heuristic fallback behavior.

The change is appropriate for a v0.x minor release because it adds optional
configuration but alters verification behavior for configured projects. The
CHANGELOG must call out the heuristic change and advise adopters to explicitly
place every required check in `verification.required` or a selected profile.
