# Packaging Contract Repair Design

**Date:** 2026-07-12

**Status:** Approved design, pending implementation planning

## Goal

Repair the public installation contract so every public root schema is copied
into fresh installed targets and future root schemas cannot be silently omitted
by a second hand-maintained installer list.

## Context

The source repository currently contains eleven files matching
`schemas/*.schema.json`. `install-agent-harness.sh` explicitly copies only
seven. Fresh installed targets therefore omit:

- `acceptance.schema.json`;
- `handoff.schema.json`;
- `policy.schema.json`;
- `review.schema.json`.

The current static-install suite checks that all eleven source schemas exist,
but its installed-target required list repeats the installer's incomplete set.
As a result, the full repository validation passes while the public installed
shape is incomplete.

## Public Schema Definition

Every file matching `schemas/*.schema.json` directly under the source schema
root is a public install artifact.

This definition intentionally does not recurse into subdirectories. A future
internal-only schema must live outside the public root set rather than rely on
an installer exclusion.

The presence of a root schema file is part of the packaging contract. This does
not make every field in every schema stable. Field compatibility continues to
follow the existing Stable, Intended-Stable, Experimental, and versioning
rules in `docs/stability-contract.md`.

## Approaches Considered

### Automatic Root Schema Set

Discover every direct child matching `*.schema.json`, sort the paths, and copy
each through the existing installer `copy_path` function.

This is the selected approach. The source directory itself becomes the single
public schema inventory, so adding another public root schema does not require
an installer edit.

### Explicit Manifest

Introduce a second manifest listing public schemas. This would allow public and
internal files in one directory, but it would recreate the synchronization
burden before the repository has any internal root schemas.

### Additional Manual Copy Blocks

Add four missing `if [ -f ... ]` blocks. This is the smallest patch but retains
the architecture that caused the omission and does not protect the next schema.

## Installer Contract

The installer must:

1. require the source `schemas/` directory to exist;
2. discover only direct child files matching `*.schema.json`;
3. process schemas in deterministic basename order;
4. call the existing `copy_path` function for every schema;
5. fail when the public schema set is empty;
6. preserve current dry-run, skip, force, and backup behavior;
7. leave target-only custom schema files untouched;
8. print `Install complete.` only after schema installation succeeds.

The existing seven manual schema copy blocks will be removed. No schema content
or schema filename changes are part of this repair.

### Portability

The implementation must remain compatible with the repository's current Bash
and Unix-like platform support. It must not depend on GNU-only `find -maxdepth`
or introduce `jq`, `yq`, or another runtime dependency.

The implementation may use a shell glob guarded by `[ -f ]`, or the existing
portable null-delimited find/sort pattern, provided it processes only direct
children and detects an empty set. Paths must remain safe when the repository
or target directory contains spaces.

## Existing Target Semantics

The repair must preserve `copy_path` semantics:

- without `--force`, an existing target schema is skipped;
- `--force` replaces an existing target schema;
- `--force --backup` preserves the previous file as `.bak` before replacement;
- `--dry-run` reports planned copies without writing files;
- schemas that exist only in the target are never deleted.

Fresh-install set equality applies only to a fresh target. Reinstall tests must
not treat user-owned target-only schemas as an error.

## Error Handling

### Missing Source Directory

If the source package has no `schemas/` directory, the installer exits nonzero,
names the missing directory, and does not print `Install complete.`.

### Empty Public Schema Set

If `schemas/` exists but has no direct `*.schema.json` files, the installer
exits nonzero with an explicit empty-public-schema error. It does not claim a
successful installation.

### Individual Copy Failure

The existing `set -e` and `copy_path` behavior remain authoritative. A failed
schema copy stops installation before the completion trailer.

### Target-Only Schemas

An extra target schema is not a source error and is not removed. Exact set
equality is asserted only in the fresh-target test created by the suite.

## Test Strategy

### Fresh Install Set Equality

The static-install suite derives sorted schema basenames from the source root
and from the fresh installed target. The two sets must match exactly. The test
must report missing and unexpected basenames when they differ.

The current expected count is eleven, but completeness is proved by set
equality rather than by permanently hard-coding that count as the inventory.
The count may be asserted as an additional regression signal.

### Dry-Run Completeness

For every source schema, the dry-run log must contain its planned source and
destination. Before the real install runs, the target must contain no copied
schema files.

### Existing-File Behavior

A temporary target preloads one schema with sentinel content:

- default reinstall reports `SKIP existing` and preserves the sentinel;
- `--force --backup` replaces the target with source content and keeps the
  sentinel in the `.bak` file;
- a target-only custom schema remains present through both operations.

### Broken Source Package

Tests create temporary package roots containing the installer and templates:

- one package omits `schemas/`;
- one package contains an empty `schemas/` directory.

Both invocations must fail and must not emit the installation completion
trailer.

### Full Validation

The existing canonical commands remain:

```bash
git diff --check
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

A final temporary fresh install will list the actual installed schema set as
rollout evidence.

## Documentation Contract

`docs/stability-contract.md` will gain a Public Packaging subsection stating:

- root `schemas/*.schema.json` files are installed public artifacts;
- downstream repositories may rely on their presence after a fresh install;
- adding a new public schema is allowed in a minor version;
- individual field compatibility remains governed by the existing interface
  classifications and versioning rules.

The README pair does not change. The onboarding entrypoint already tells users
to commit `schemas/` as part of the clean baseline and should not regain detailed
packaging internals.

## Expected File Scope

Modify:

- `install-agent-harness.sh`;
- `tests/harness/static-install.sh`;
- `docs/stability-contract.md`;
- `tests/harness/productization-examples.sh`;
- the implementation plan created after this design is approved.

No new runtime script, schema, template, task flag, README section, or installer
manifest is required.

## Completion Criteria

- all eleven current root schemas appear in a fresh installed target;
- adding a twelfth root schema requires no installer code change;
- source and fresh-target schema basename sets must be equal;
- dry-run reports every schema without writing any;
- missing and empty source schema roots fail before the completion trailer;
- skip, force, backup, and target-only custom schema behavior remain compatible;
- the stability contract describes the public schema packaging boundary;
- full repository validation and final temporary-install evidence pass;
- generated `.agent/` state remains untracked.

## Non-Goals

This repair does not:

- create a general installer manifest;
- change schema contents or field stability;
- delete target-only schemas;
- add recursive schema installation;
- address finish-run collisions or runner error semantics;
- add validation-suite selection or CI parallelism;
- change README onboarding.
