# Repo Guidance Regression Cases

Use these cases as a manual or semi-manual release checklist for routing stability, `agent.md` update discipline, and handoff scope control.

## How To Use

For each case, evaluate:

- which skill should be selected first
- whether the route should stay patch-first or rebuild-first
- whether `agent.md` should update
- whether handoff should update
- whether `Verified:`, `Inferred:`, and `TODO:` were applied with the intended threshold

## Release Checklist

Before release, confirm all of the following:

- every case still routes to the expected primary skill
- patch-first vs rebuild-first behavior is unchanged unless intentionally revised
- small local code changes do not trigger noisy `agent.md` updates
- shared contracts, schema, CI, workspace, infra, and bootstrap changes still trigger deeper review
- handoff output stays within the six-field schema and is removed when no useful state remains
- `Verified:`, `Inferred:`, and `TODO:` labels still follow the documented evidence thresholds
- bad-output patterns in the reference examples are still rejected by the current wording

## Case 1: Small Monolith Repo

- Input context:
  - `README.md`, `package.json`, `src/server.ts`, `src/routes/`, `tests/`
  - no existing `agent.md`
  - request: "Create canonical guidance for this repo."
- Expected route:
  - `$project-agent-docs` -> `$project-map-agent-md`
- Should `agent.md` update:
  - Yes, create the first canonical map.
- Should handoff update:
  - No, unless the request also asks for current-state capture.
- Common failure mode to avoid:
  - Producing a verbose template map with generic sections but little repo-specific navigation.

## Case 2: Frontend / Backend Split Repo

- Input context:
  - `frontend/package.json`, `frontend/src/main.tsx`
  - `backend/package.json`, `backend/src/index.ts`
  - `openapi/api.yaml`
  - existing planning doc for auth rollout
  - request: "Refresh the repo guidance and tell me what to do next."
- Expected route:
  - `$project-agent-docs` -> `$update-agent-handoff`
  - keep next-step output as a short pointer to the planning doc
- Should `agent.md` update:
  - Yes, if the API contract boundary or runtime ownership edge is stale.
- Should handoff update:
  - Yes, if current focus or blockers are part of the request.
- Common failure mode to avoid:
  - Pulling the detailed rollout plan into `agent.md` or handoff.

## Case 3: Monorepo

- Input context:
  - `pnpm-workspace.yaml`, root `package.json`
  - `apps/web`, `apps/api`, `packages/contracts`, `packages/ui`
  - no current handoff
  - request: "Map this repo for future agents."
- Expected route:
  - `$project-agent-docs` -> `$project-map-agent-md`
- Should `agent.md` update:
  - Yes, create or rebuild a workspace-aware canonical map.
- Should handoff update:
  - No.
- Common failure mode to avoid:
  - Treating every new package as equally important instead of highlighting runnable apps, shared contracts, and workspace linkage.

## Case 4: Infra-Heavy Repo

- Input context:
  - `terraform/`, `.github/workflows/deploy.yml`, `Dockerfile`, `.env.example`
  - existing `agent.md` already maps app modules but barely mentions deploy/runtime boundaries
  - changed files only in infra and CI
  - request: "Update repo guidance after these changes."
- Expected route:
  - `$project-agent-docs` -> `$update-agent-handoff`
- Should `agent.md` update:
  - Yes, if deploy, environment, or runtime boundaries changed.
- Should handoff update:
  - Only if there is meaningful current-session state to preserve.
- Common failure mode to avoid:
  - Treating infra-only diffs as local or low-impact because app directories were untouched.

## Case 5: Existing Stale `agent.md`

- Input context:
  - repo has `agent.md`
  - current repo now has `src/bootstrap.ts`, `packages/shared-schema`, and new CI commands not reflected in the map
  - request: "The existing agent.md is outdated. Refresh it."
- Expected route:
  - `$project-agent-docs` -> `$update-agent-handoff` first
  - rebuild only if the existing map is too misleading to patch safely
- Should `agent.md` update:
  - Yes, patch by default.
- Should handoff update:
  - No, unless current-state sync was also requested.
- Common failure mode to avoid:
  - Rebuilding from scratch by default when a minimal patch would preserve stable map structure.

## Case 6: Planning Doc Exists, No Canonical Map

- Input context:
  - `docs/plans/payment-rewrite.md`
  - `README.md`, `pyproject.toml`, `app/main.py`, `tests/`
  - no `agent.md`
  - request: "We have a plan already. Organize repo guidance."
- Expected route:
  - `$project-agent-docs` -> `$project-map-agent-md`
- Should `agent.md` update:
  - Yes, create the first canonical map.
- Should handoff update:
  - Optional, only if a resume-state snapshot is explicitly needed.
- Common failure mode to avoid:
  - Copying future execution steps from the planning doc into the canonical map.

## Case 7: Small Diff, Shared Contract Changed

- Input context:
  - existing `agent.md`
  - changed files: `packages/contracts/user.ts`, `frontend/src/api/client.ts`, `backend/src/routes/user.ts`
  - request: "Just update the handoff for this small change."
- Expected route:
  - `$project-agent-docs` -> `$update-agent-handoff`
  - force architecture-sensitive review because a shared contract changed
- Should `agent.md` update:
  - Yes, if the shared contract edge, ownership, or generated client/runtime usage changed.
- Should handoff update:
  - Yes, if current status matters.
- Common failure mode to avoid:
  - Deciding by touched-file count or touched directory only, then skipping a needed canonical patch.

## Expected Labeling Checks

Use these checks across all cases:

- A command mentioned only in docs should stay `Inferred:` until backed by executable repo evidence or direct execution.
- Imports alone should not become `Verified` dependency edges.
- Router registration, bootstrap wiring, manifest linkage, schema ownership, and CI invocation can justify `Verified` edges or commands.
- New tests should not force `agent.md` updates unless they expose a new boundary or previously unknown structure.
- Handoff should never expand into a history log or mini plan.
