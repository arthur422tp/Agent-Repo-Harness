# Architecture Sensors

Architecture sensors are repo-owned commands that check narrow architecture
invariants and emit stable result markers. They strengthen architecture
evidence by tying an invariant to command output, but they do not guarantee
semantic correctness.

Use sensors for invariants that can be checked deterministically, such as:

- a package must not import test fixtures
- generated files must not be committed
- a public API file must keep expected exported names

## Harness Integration

Add the sensor command to `.agent/harness.yml`:

```yaml
verification:
  required:
    - name: "import boundary"
      command: "python3 scripts/check-import-boundaries.py --source src/app --forbidden-import tests.fixtures"
```

Then reference the output from `.agent/architecture.yml`:

```yaml
architecture:
  status: upheld
  reviewer: "agent"
  invariants:
    - id: ARCH-IMPORT-1
      description: "Application code must not import test fixtures."
      status: upheld
      evidence_refs:
        - type: command_output
          path: ".agent/runs/20260627-091500/import-boundary.txt"
          must_contain:
            - "IMPORT_BOUNDARY_RESULT=pass"
```

## Boundary

Sensors are opt-in local checks. They do not provide sandboxing, provider-native
tracing, runtime enforcement, or semantic correctness guarantees.
