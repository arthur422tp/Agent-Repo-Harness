# Project Map Examples

Use these examples only when output shape is uncertain. Keep the final guidance specific to evidence from the target repo.

## Minimal `agent.md`

```markdown
# Agent Guidance

## Project Overview

- Verified: Repo name: `<repo-name>`
- Verified: Purpose: `<purpose from README or code>`
- Inferred: Stack: `<stack inferred from manifests>`
- TODO: Confirm runtime version and deployment target.

## Guidance Mission

- Optimize for fast onboarding with low-token navigation.
- Prefer verified paths and commands over broad summaries.
- Do not edit generated, vendor, cache, or build output unless explicitly asked.

## Fast-Start Map

- `README.md`: project overview and setup notes.
- `package.json`: scripts and dependency evidence.
- `src/`: primary application code.
- `tests/`: test entry points.
- `.github/workflows/`: CI commands, if present.

## Repository Map

- `src/`: application source and task entry points.
- `tests/`: test coverage and examples.
- `docs/`: project docs, if present.

## Skip / Expand-Later

- `node_modules/`, `dist/`, `build/`, `.next/`, `.cache/`: generated or dependency output.
- Large generated snapshots or lockfile internals unless dependency work requires them.

## Risk Map

- TODO: Confirm auth, billing, migration, deployment, and external API boundaries.
- Inferred: Database or schema risk if migrations or ORM schema files exist.

## Package & Dependency TODO

- Verified: Checked `<manifest files>`.
- TODO: Confirm install command if no lockfile or package manager evidence is clear.

## Tooling & Commands

- TODO: Verify install command.
- TODO: Verify test command.
- TODO: Verify lint/build commands.

## Known Gaps / TODO

- TODO: Confirm production entry point.
- TODO: Confirm generated-file boundaries.
```

## Module Guidance Pointer

Create module guidance only when local risk or complexity justifies it:

```markdown
# `<module-path>` Agent Guidance

## Module Purpose

- Verified: `<what this module owns>`

## Read First

- `<module-path>/README.md`
- `<module-path>/<entrypoint>`

## Local Risks

- TODO: Confirm external contracts, schemas, migrations, auth, or deploy coupling.

## Local Commands

- TODO: Verify module-specific test/build command.
```
