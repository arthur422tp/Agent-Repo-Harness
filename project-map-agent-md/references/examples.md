# Project Map Examples

Use these examples only when output shape is uncertain. Keep the final guidance tied to evidence from the target repo.

## Minimal `agent.md`

````markdown
# Agent Guidance

## Project Overview

- Verified: Repo name: `<repo-name>`
- Verified: Purpose: `<purpose from README or code>`
- Inferred: Stack: `<stack inferred from manifests>`
- TODO: Confirm runtime version and deployment target.

## Fast-Start Map

- `README.md`: overview and setup notes
- `<manifest>`: dependency and script evidence
- `<entrypoint>`: runtime bootstrap
- `<main module dir>`: primary code entry
- `<tests dir>`: test entry points

## Repository Tree

- `<app-or-src>/`
  - `<feature-a>/`
  - `<feature-b>/`
- `<tests>/`
- `<infra-or-config>/`
- `<schema-or-migrations>/`

## Module Index

- `<ModuleName>`
  - role: `<responsibility>`
  - path: `<path>`
  - owns: `<main files, contracts, or behavior>`
  - depends_on: `<dependencies or None>`
  - used_by: `<dependents or entrypoints>`
  - risk: `<low/medium/high + why>`

## Pseudo-DSL

- `App -> Router`
- `Router -> AuthModule`
- `AuthModule -> AuthService`
- `AuthService -> UserRepo`

## Adjacency List

- `App: Router`
- `Router: AuthModule, UserModule`
- `AuthService: JWTProvider, UserRepo`

## Risk Map

- TODO: Confirm auth, billing, migration, deployment, and external API boundaries.
- Inferred: Schema or migration risk if contract files exist.

## Tooling & Commands

- Verified: Install: `<command if proven>`
- TODO: Verify dev command.
- TODO: Verify test command.
- TODO: Verify lint/build commands.

## Known Gaps / TODO

- TODO: Confirm generated-file boundaries.
- TODO: Confirm production startup path.
````

## Module Guidance Pointer

Create module guidance only when local complexity or risk justifies it:

````markdown
# `<module-path>` Agent Guidance

## Module Overview

- Verified: role: `<responsibility>`
- Verified: path: `<module-path>`
- TODO: Confirm local contracts and runtime boundaries.

## Read First

- `<module-path>/README.md`
- `<module-path>/<entrypoint>`

## Local Dependencies

- depends_on: `<deps or None>`
- used_by: `<dependents or entrypoints>`

## Local Risk

- TODO: Confirm schema, migration, auth, billing, deploy, or external API coupling.
````

## Low-Evidence Fallback Example

When repo evidence is partial, keep the map smaller:

````markdown
# Agent Guidance

## Project Overview

- Verified: Repo name: `sample-repo`
- Inferred: Stack: Node.js service
- TODO: Confirm production startup path.

## Fast-Start Map

- `README.md`: current project intent and setup notes
- `package.json`: script and dependency evidence
- `src/index.ts`: likely runtime entrypoint
- `tests/`: behavior coverage and missing boundary hints

## Module Index

- `App`
  - role: Inferred: main service entry
  - path: `src/`
  - owns: TODO: confirm API or worker ownership
  - depends_on: TODO
  - used_by: TODO
  - risk: Inferred: medium until startup and contract boundaries are confirmed

## Known Gaps / TODO

- TODO: Confirm whether this repo exposes HTTP routes, a worker, or both.
- TODO: Confirm deployment target and environment boundary.
````

Why this is good:

- it stays navigational without pretending to know the full architecture
- it points to the best evidence for resolving uncertainty
