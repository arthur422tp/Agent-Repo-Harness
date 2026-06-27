# handoff.md

## Current State

The contract RAG fixture now measures a complete High-Risk Agent-Repo-Harness
adoption flow. The installed-target scenario records TDD, acceptance, review,
architecture, command-ledger, sandbox, and repository verification evidence
without adding new gates, schemas, profile engines, or runtime abstractions.

## Evidence Refs Strict Acceptance

- Added opt-in `evidence.strict_refs` and `evidence.allow_text_only_evidence`
  config for acceptance evidence.
- Added `templates/scripts/check-evidence-refs.py` to validate repo-local
  `evidence_refs` artifacts.
- Kept backward-compatible text evidence by default and did not add a new
  `agent-finish.sh` gate.
- Validation: `bash validate-harness.sh`; `bash templates/scripts/check-doc-links.sh .`;
  `bash templates/scripts/check-acceptance.sh --help`;
  `python3 templates/scripts/check-evidence-refs.py --help`.

## Verification

- `bash validate-harness.sh`: PASS
- `bash templates/scripts/check-doc-links.sh .`: PASS
- `bash templates/scripts/agent-audit.sh`: PASS
- RAG Minimal, Standard, and complete High-Risk adoption scenarios: PASS through
  the repository validation suite

## Adoption Findings

- High-Risk gates add value when each gate maps to a named risk.
- `PYTHONPATH=src` remains an explicit fixture contract because the example is
  intentionally not installed as a package.
- Failure attribution and intervention records stay disabled when no repaired
  failure or material manual override occurs.

## Environment Isolation

- No third-party runtime packages required.
- No global Python package installation performed.
- The source RAG fixture remains free of `.agent/`, `.venv/`, and
  `__pycache__/` generated state.

## Next Action

Use the measured adoption report before changing harness gate behavior. Prefer
docs or fixture configuration unless repeated validation evidence proves a
harness behavior change is needed.
