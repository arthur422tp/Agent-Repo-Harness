# Bad Output Examples

Use these examples to avoid polished but low-signal `agent.md` output.

## Bad Example 1: Template-Looking Map

````markdown
## Fast-Start Map

- `src/`
- `docs/`
- `tests/`

## Module Index

- App
  - role: handles business logic
  - path: `src/`
  - owns: application logic
  - depends_on: internal modules
  - used_by: the app
  - risk: medium
````

Why this is bad:

- `Fast-Start Map` names folders but does not tell the next model what to read first.
- `Module Index` is generic enough to fit almost any repo.
- ownership and dependency claims are not tied to evidence.

## Bad Example 2: Directory Tree Disguised As Runtime Edges

````markdown
## Pseudo-DSL

- `src -> components`
- `src -> utils`
- `src -> tests`

## Adjacency List

- `src: components, utils, tests`
````

Why this is bad:

- these are filesystem relationships, not runtime, ownership, or contract edges
- it adds structure without navigational value

## Bad Example 3: Overconfident Commands

````markdown
## Tooling & Commands

- Verified: `npm run dev`
- Verified: `npm test`
````

Why this is bad:

- commands are marked `Verified` without package scripts, CI evidence, task config, or direct execution
- docs mention alone is only `Inferred`
