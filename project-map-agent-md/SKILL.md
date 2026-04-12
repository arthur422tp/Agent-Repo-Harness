---
name: project-map-agent-md
description: Use when initializing canonical repo guidance from concrete repository evidence.
---

# Project Map Agent.md

Create the stable project map. Do not record session state or detailed plans here.

## Core Principle

- `agent.md` is the map.
- Planning docs are navigation.
- Handoff is the current position.

## Readiness Gate

Before creating the first full canonical `agent.md`, confirm the repo has enough concrete evidence. Useful evidence includes:

- README, product notes, design notes, or existing docs
- package manifests, lockfiles, build configs, or workspace configs
- source directories, scaffolded modules, or entry points
- tests, CI, infra, schema, migration, or integration files

If the repo is only a bare folder or an idea with little concrete evidence, do not invent a full architecture map.

- Report that the repo is not ready for full mapping.
- Ask for or wait for concrete repo evidence.
- If the user explicitly insists, create only a minimal TODO-only skeleton.

## Scope

Use this skill for:

- first creation of canonical root guidance
- rebuilding the canonical map only when the current one is missing, broken, or too incomplete to trust
- optional module guidance only when it prevents root-document bloat

Do not use this skill for:

- session logs
- current-task tracking
- implementation plans
- chronological discovery notes

## Workflow

1. Run the readiness gate.
2. Scan only enough repo evidence to identify the stable architecture.
3. Select one canonical root filename from `agent.md`, `AGENT.md`, `AGENTS.md`, `claude.md`, `CLAUDE.md`: preserve an existing full canonical file when valid; otherwise use `agent.md`.
4. Keep only one full-content root guidance file. Any secondary filename should be a short pointer.
5. Build the root map first.
6. Create module guidance only when a module has enough local complexity or risk to justify it.
7. Keep facts evidence-labeled as `Verified:`, `Inferred:`, or `TODO:`.

## Scan Heuristics

Scan in this order and stop when you have enough evidence:

1. Root docs and existing guidance: `README*`, existing `agent.md` or equivalent, contribution docs.
2. Manifests and lockfiles: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, workspace configs, lockfiles.
3. Entry points and apps: `src/`, `app/`, `pages/`, `cmd/`, `main.*`, server/bootstrap files, CLI entry points.
4. Tests and quality gates: `test/`, `tests/`, `spec/`, `e2e/`, CI configs, lint/format configs.
5. Infra and deploy: `Dockerfile`, `docker-compose*`, `infra/`, `terraform/`, `k8s/`, `.github/workflows/`, deployment configs.
6. Schemas and migrations: `schema/`, `prisma/`, `migrations/`, `db/`, OpenAPI, GraphQL, protobuf, shared contracts.
7. Risk areas: auth, billing, secrets, permissions, migrations, external integrations, generated code boundaries.

## Canonical agent.md Schema

The root file should stay compact and structured. Prefer tree form, bullets, pseudo-DSL, and adjacency lists over prose.

- `Project Overview`
- `Fast-Start Map`
- `Repository Tree`
- `Module Index`
- `Pseudo-DSL`
- `Adjacency List`
- `Risk Map`
- `Tooling & Commands`
- `Known Gaps / TODO`

### Required Shape

`Repository Tree`

- Show only the main directories, apps, packages, schemas, tests, infra, and other meaningful structure.

`Module Index`

- Represent each meaningful module with these fields when evidence exists:
  - `role`
  - `path`
  - `owns`
  - `depends_on`
  - `used_by`
  - `risk`

`Pseudo-DSL`

- Show the main runtime or data-flow path in short edges, for example:
  - `App -> Router`
  - `Router -> AuthModule`
  - `AuthModule -> AuthService`
  - `AuthService -> UserRepo`

`Adjacency List`

- Show dependency edges in compact form, for example:
  - `Router: AuthModule, UserModule`
  - `AuthService: JWTProvider, UserRepo`

## Structure Rules

- Keep `agent.md` focused on stable repo knowledge.
- Do not absorb planning details.
- Do not absorb handoff state into the main architecture sections.
- Prefer path references, trees, lists, and compact field blocks over prose paragraphs.
- Mark unknown or uncertain facts explicitly.
- Avoid full-repo narration.

## Module Threshold

Create module guidance only when a directory has one or more of these:

- an independent runtime or entry point
- external contract or schema ownership
- migration, deploy, auth, billing, or security risk
- frequent task-entry importance
- enough local complexity that keeping it in the root map would cause bloat

Do not create module guidance for obvious helpers, thin wrappers, generated/vendor/build output, or low-risk folders.

## Evidence Labels

- `Verified:` confirmed by files or command output
- `Inferred:` likely from names, conventions, manifests, or framework patterns
- `TODO:` still unknown and worth confirming

Never promote `Inferred:` or `TODO:` to `Verified:` without proof.

## Quality Checklist

Before finishing, verify:

- there is only one full canonical root guidance file
- any secondary root filename is a short pointer only
- the root file follows the stable schema above
- the root file is mostly structured data, not long prose
- `Verified:`, `Inferred:`, and `TODO:` are kept distinct
- the map points to major modules, entry points, dependencies, risks, and commands when evidence exists
- handoff/session state is omitted
- planning details are omitted or linked out
