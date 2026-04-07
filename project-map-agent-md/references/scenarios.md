# Project Map Scenario Snippets

Use one matching snippet only when the target repo shape requires it. Do not paste every scenario into the final guidance.

## Monorepo

- Call out the workspace manifest first: `pnpm-workspace.yaml`, `lerna.json`, `turbo.json`, `nx.json`, `package.json#workspaces`, `Cargo.toml#workspace`, or similar.
- Map each independently runnable app/package separately.
- List shared packages only when they are frequent task entry points or cross-cutting risk.
- Add module guidance for apps with independent runtime, deploy, schema, or external API ownership.
- Keep root guidance focused on navigation and workspace commands; put package-specific details in module guidance.

## Backend / Frontend Split

- Identify the frontend entry point, backend entry point, and API contract boundary.
- Read manifests for both sides before claiming commands or runtime versions.
- List cross-boundary files such as OpenAPI, GraphQL schema, protobufs, generated clients, or shared DTOs.
- Mark deployment and environment assumptions as `TODO:` unless confirmed by files or verified commands.
- Add module guidance if frontend and backend have separate commands, deploy paths, or risk areas.

## Infra-Heavy Repo

- Prioritize deploy and environment evidence: Terraform, Pulumi, Helm, Kubernetes, Docker, CI workflows, secrets templates, and environment docs.
- Treat stateful resources, migrations, secrets, permissions, DNS, and cloud IAM as risk areas.
- Do not summarize generated plan/output files unless they define behavior.
- Prefer `TODO:` for unverified cloud accounts, regions, state backends, and deployment targets.
- If infra modules are many, map module ownership and read-first paths instead of describing every resource.
