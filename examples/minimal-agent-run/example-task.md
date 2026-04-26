# Minimal Agent Run

## Task

Fix a retry bug in `src/retry/worker.js`.

## Boundaries

- Keep changes inside retry-related source and tests.
- Do not touch authentication, billing, or deployment files.
- Run the harness gates before claiming completion.

## Expected Finish Checks

```bash
bash scripts/check-policy.sh
bash scripts/check-scope.sh
bash scripts/agent-verify.sh --best-effort
```
