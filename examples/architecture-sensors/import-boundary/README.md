# Import Boundary Architecture Sensor

## Scenario

Application code under `src/app` must not import test fixtures from
`tests.fixtures`.

## Harness Command

```bash
python3 scripts/check-import-boundaries.py \
  --source src/app \
  --forbidden-import tests.fixtures
```

Expected marker:

```text
IMPORT_BOUNDARY_RESULT=pass
```

## Architecture Evidence

`.agent/architecture.yml` references the command output with `evidence_refs`.
This proves the sensor command emitted the expected marker for the captured run.
It does not prove semantic correctness beyond that invariant.
