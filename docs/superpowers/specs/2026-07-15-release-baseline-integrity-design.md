# Release Baseline Integrity Design

**Date:** 2026-07-15

**Status:** Approved design, pending implementation planning

## Goal

Make the existing Agent-Repo-Harness release baseline mechanically
reproducible without expanding the product beyond its documented repo-local
completion-harness boundary.

The work must prove that repository version metadata agrees, that a real prior
release can be upgraded with the public installer, and that release readiness
uses the same canonical validation already trusted by the project.

## Context

The packaging-contract repair was completed on
`codex/2026-07-12-packaging-contract-repair`, verified, fast-forwarded into
`main`, verified again on the merged result, and the completed branch was
removed before this design was written.

The resulting source checkout passes `bash validate-harness.sh`, but release
state is not yet closed:

- `VERSION` is `0.2.0`;
- `CHANGELOG.md` has a `v0.2.0` section plus later `Unreleased` entries;
- the repository has no local `v0.2.0` tag;
- `docs/public-packaging.md` still records unverified default-branch and
  publishing actions;
- current install tests prove fresh installation and same-version reinstall
  behavior, but do not execute an upgrade from a real prior release tag.

A green source validation therefore proves the current checkout is internally
consistent; it does not by itself prove that versioned release metadata or the
cross-release installer lifecycle is ready.

## Approaches Considered

### Release Baseline Closure

Add repository-only version integrity, real prior-release upgrade proof, and a
release-readiness orchestrator. This is the selected approach because it
strengthens the existing public promises without adding another target-repo
gate or agent-facing interface.

### Deeper Runtime Refactoring First

Continue decomposing shell runtime internals. The first maintainability phase
has already extracted shared finish helpers, summary rendering, gate ordering,
and runner behavior. More refactoring may be useful later, but it does not
resolve the current release-state and cross-version proof gaps.

### Expand Harness Capabilities First

Add new gates, adapters, or runtime integrations. This would increase the
unstable public surface before the current release baseline is reproducible and
would move away from the immediate stability objective.

## Boundary And Compatibility

This phase adds repository-maintenance tooling only. New scripts under `ci/`
and new test suites are not installed into target repositories.

The phase must not change:

- `scripts/agent-finish.sh` public CLI or exit semantics;
- strict versus best-effort behavior;
- finish gate order;
- result filenames or finish-summary JSON fields;
- installed task, policy, acceptance, review, or evidence contracts;
- the documented boundary that this project is not a sandbox, full runtime,
  provider-native tracing layer, or semantic correctness guarantee.

The installer remains the sole install and upgrade entrypoint. Existing
default-skip, `--force`, `--backup`, dry-run, and target-owned-file behavior
remain authoritative.

## Architecture

### Repository Integrity Checker

Create `ci/check-release-integrity.sh` as a repository-only checker.

It validates:

1. `VERSION` contains one stable `MAJOR.MINOR.PATCH` value;
2. `CHANGELOG.md` contains a matching `## vMAJOR.MINOR.PATCH` release heading;
3. `docs/public-packaging.md` contains a matching versioned release-checklist
   heading;
4. development mode permits HEAD to have no release tag;
5. if HEAD has a stable `vMAJOR.MINOR.PATCH` tag, the tag equals `VERSION`;
6. strict tag mode requires exactly the requested release tag at HEAD;
7. strict tag mode rejects release-note entries left under `Unreleased`, so a
   tag cannot silently omit user-visible changes from its version section.

The checker emits exactly one final
`RELEASE_INTEGRITY_RESULT=pass|fail` marker and exits nonzero on failure.

The checker does not infer that an unchecked external publishing action has
occurred. GitHub description, topics, remote CI status, tags, and releases stay
unchecked until verified from the corresponding external state.

### Prior-Release Upgrade Smoke

Create `ci/release-upgrade-smoke.sh` as a repository-only lifecycle proof.

The script accepts an explicit stable `--from-tag vMAJOR.MINOR.PATCH`. The
release-readiness orchestrator may discover a default by selecting the newest
stable repository tag that differs from the current `VERSION`; prerelease tags
are excluded. Explicit selection remains available for deterministic local and
CI runs.

The smoke test:

1. verifies the requested tag exists locally;
2. exports that tag into a temporary source package with `git archive`;
3. creates a temporary Git target repository;
4. installs the prior tagged harness into the target;
5. commits that installed baseline;
6. adds a target-owned schema and sentinel modifications to harness-managed
   files;
7. runs the current installer without `--force` and proves existing content is
   skipped and preserved;
8. runs the current installer with `--force --backup` and proves managed files
   update, prior sentinel content is retained in `.bak`, and target-owned files
   remain untouched;
9. proves the current direct-root public schema set is installed;
10. configures only the minimal deterministic target state needed for smoke
    execution;
11. runs installed preflight, verification, and finish commands;
12. checks their public result markers and exits nonzero on any mismatch.

All temporary files live below `${TMPDIR:-/tmp}` and are removed on exit unless
an explicit keep-debug flag is enabled. Generated evidence never becomes
tracked `.agent/` state in the source repository.

`git`, `tar`, and full tag history are release-maintenance dependencies only.
They are not added to installed target runtime requirements.

### Release Readiness Orchestrator

Create `ci/release-readiness.sh` as the canonical release-maintenance entrypoint.

It runs, in order:

1. repository integrity checking;
2. `bash validate-harness.sh`;
3. real prior-release upgrade smoke;
4. `bash ci/sandbox-smoke.sh`;
5. a concise final readiness summary.

Development mode checks repository metadata without requiring a current tag.
Strict tag mode requires the supplied tag to match both HEAD and `VERSION`.
Both modes require the requested prior-release tag and fail if the checkout is
shallow or missing required history.

The orchestrator emits exactly one final
`RELEASE_READINESS_RESULT=pass|fail` marker. Existing child-script result
markers remain unchanged.

## Data Flow

```text
VERSION + CHANGELOG + public checklist + Git tag state
  -> check-release-integrity.sh
  -> release-integrity result

prior release tag
  -> git archive
  -> prior installer
  -> temporary installed target
  -> current installer default reinstall
  -> current installer --force --backup upgrade
  -> installed preflight / verify / finish
  -> upgrade-smoke result

integrity result + canonical validation + upgrade result + sandbox result
  -> release-readiness.sh
  -> release-readiness result
```

Each component owns one result and can be executed independently. The
orchestrator composes exit statuses; it does not reimplement child checks.

## CI Integration

The existing ordinary `push` and `pull_request` validation remains the fast
source-contract path and continues to run `bash validate-harness.sh` plus the
existing sandbox smoke.

Add an explicit release-readiness path for stable version tags and manual
workflow dispatch. That job uses `actions/checkout` with full history and tags,
then runs `bash ci/release-readiness.sh` in strict or development mode as
appropriate.

The canonical validation suite includes hermetic tests of the new scripts by
creating temporary fixture repositories and synthetic tags. Pull requests can
therefore catch checker and orchestration regressions without depending on the
real repository's release history. The separate release-readiness job proves
the real tagged history.

CI artifacts may retain the textual readiness logs. The repository does not
commit generated release evidence.

## Error Handling

The following conditions are blocking and must exit nonzero:

- malformed or multi-line `VERSION`;
- missing matching changelog or release-checklist heading;
- multiple stable release tags at HEAD;
- requested tag absent from HEAD in strict tag mode;
- tag and `VERSION` mismatch;
- non-empty `Unreleased` release notes in strict tag mode;
- missing prior-release tag or incomplete Git history;
- failure to export the prior release package;
- overwrite during default reinstall;
- missing or incorrect backup during forced upgrade;
- removal or mutation of target-owned files;
- incomplete public schema installation;
- installed preflight, verification, or finish failure;
- canonical validation failure;
- sandbox smoke failure.

The existing explicit sandbox `skip` result remains acceptable when no
compatible external runner is available. A skip is reported as a skip and is
never relabeled as sandbox isolation passing.

Failure messages name the failed contract and relevant file, tag, or target
path. Successful completion trailers are printed only after all required work
has succeeded.

## Test Strategy

### Release Integrity Contract

Create a hermetic suite covering:

- valid and invalid semantic versions;
- missing matching changelog section;
- missing matching public-checklist heading;
- untagged development HEAD;
- matching stable tag;
- mismatched and multiple stable tags;
- strict mode without the requested tag;
- strict mode with non-empty `Unreleased` notes;
- exactly one final pass or fail marker.

### Upgrade Lifecycle Contract

Cover:

- prior tag discovery and explicit override;
- absent-tag and shallow-history failures;
- previous-release installation;
- default reinstall preserving sentinel content;
- `--force --backup` replacement and backup contents;
- target-only files preserved through both operations;
- current public schema set completeness;
- installed preflight, verification, and finish success;
- temporary-directory cleanup and optional debug retention.

The hermetic test builds a temporary Git fixture with synthetic stable tags.
Final rollout evidence additionally runs against the repository's real
`v0.1.1` tag.

### Canonical Verification

Before completion, run:

```bash
bash tests/harness/release-integrity.sh
bash tests/harness/release-upgrade.sh
bash templates/scripts/check-doc-links.sh .
git diff --check
bash validate-harness.sh
bash ci/release-readiness.sh --from-tag v0.1.1
```

If sandbox smoke reports its documented no-runner skip, record that state
verbatim rather than claiming an external sandbox passed.

## Documentation And Evidence

Update `docs/versioning.md` to explain development versus strict tag checks and
the supported `--force --backup` upgrade workflow.

Update `docs/public-packaging.md` to separate locally provable readiness from
external publishing actions. Local boxes may be checked only from command
evidence. Remote CI, description, topics, tag, rendering, and GitHub Release
boxes remain external actions and are not completed by local scripts.

Update `CHANGELOG.md` under `Unreleased` for the new repository-maintenance
checks. Do not create or move a release section during implementation.

Update `handoff.md` with exact commands, exit results, selected prior tag, and
sandbox pass/skip state. Keep generated `.agent/` runtime evidence untracked.

## Expected File Scope

Create:

- `ci/check-release-integrity.sh`;
- `ci/release-upgrade-smoke.sh`;
- `ci/release-readiness.sh`;
- `tests/harness/release-integrity.sh`;
- `tests/harness/release-upgrade.sh`.

Modify:

- `.github/workflows/ci.yml`;
- `validate-harness.sh`;
- `docs/versioning.md`;
- `docs/public-packaging.md`;
- `CHANGELOG.md`;
- `handoff.md`;
- the implementation plan created after this design is approved in writing.

The implementation may make narrow test-helper changes in
`tests/harness/lib.sh` when duplication would otherwise obscure the release
contracts. It must not modify installed templates, schemas, public runtime
scripts, or README onboarding unless implementation evidence exposes a direct
contradiction requiring a separately approved design change.

## Completion Criteria

- the completed packaging repair is present on `main` and verified after
  merge;
- release metadata inconsistencies fail mechanically with explicit markers;
- untagged development and strict tag modes are distinct and tested;
- a real `v0.1.1` installed target upgrades successfully with documented
  preservation behavior;
- target-owned files and backups are verified, not assumed;
- the current public schema set is complete after upgrade;
- installed preflight, verification, and finish run successfully after upgrade;
- ordinary CI remains fast while tag/manual release readiness uses full Git
  history;
- local readiness and external publishing state are reported separately;
- canonical verification and real-history release readiness pass;
- no generated `.agent/` evidence is tracked;
- no new target-repo capability or public runtime contract is introduced.

## Non-Goals

This phase does not:

- create or push `v0.2.0` or any other tag;
- create a GitHub Release or change GitHub repository metadata;
- publish an archive, package, or container image;
- define a general migration engine or automatic three-way merge;
- delete target-owned files;
- auto-upgrade installed repositories;
- add target-repo gates, schemas, adapters, or runtime dependencies;
- claim filesystem, network, secret, or provider isolation;
- claim semantic correctness;
- continue unrelated runtime refactoring.
