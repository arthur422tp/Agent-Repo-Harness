---
name: project-map-agent-md
description: Initialize canonical low-token repo guidance maps only.
---

# Project Map Agent.md

Create initial canonical repo guidance for fast onboarding. Do not maintain session state.

## Workflow

1. Scan only enough structure to identify entry points, manifests, configs, tests, docs, risky areas, and skip zones.
2. Select one canonical root filename from `agent.md`, `AGENT.md`, `AGENTS.md`, `claude.md`, `CLAUDE.md`: preserve an existing full-content file; otherwise use `agent.md`.
3. Do not maintain multiple full-content root guidance files. If another filename is needed, make it a short pointer to the canonical file.
4. Create or update the root map first; if module docs are needed, use the same filename style as the canonical root file rather than mixing styles.
5. Add module guidance only when it prevents root bloat or risky rediscovery.
6. Do not install or update packages unless the user asks.

## Evidence Labels

- `Verified:` confirmed by files or command output.
- `Inferred:` likely from conventions, names, lockfiles, or framework patterns.
- `TODO:` unknown, with what to confirm.

Never write inferred or unknown facts as verified.

## Root Section Schema

- `Project Overview`: name, purpose, stack, phase.
- `Guidance Mission`: optimize for, expected tasks, must-avoid items.
- `Fast-Start Map`: smallest useful read-first path list, usually 3-7 paths; task entry points for backend/frontend/schema/infra/migrations as relevant.
- `Repository Map`: key dirs, module boundaries, integrations.
- `Skip / Expand-Later`: vendor, generated, build, cache, large outputs, or low-signal paths to avoid on first pass.
- `Risk Map`: auth, billing, security, infra, migrations, deploy, schemas, external contracts, secrets.
- `Package & Dependency TODO`: manifests checked, package-manager evidence, missing/unclear/risky deps, unverified setup.
- `Tooling & Commands`: install, dev, build, test, lint, format, with TODO for unverified commands.
- `Known Gaps / TODO`: missing docs/scripts, unclear architecture, assumptions.

## Compression Rules

- Root doc stays compact: path lists and bullets over narrative.
- Store navigation, not a full repo explanation.
- Prefer path references over repeating file contents.
- Do not summarize obvious boilerplate or standard framework files unless they change behavior.
- Do not include reasoning history or chronological discovery notes.
- Module docs must be shorter than root docs.

## Module Threshold

Create module guidance only for directories with one or more triggers: independent runtime/entrypoint, external contract or schema ownership, migrations/deploy risk, auth/billing/security/infra risk, frequent task entrypoint, or local complexity that would make the root doc noisy.

Do not create module guidance for simple helpers, thin wrappers, small folders with obvious names, generated/vendor/build output, or rarely edited code with no local risk.
