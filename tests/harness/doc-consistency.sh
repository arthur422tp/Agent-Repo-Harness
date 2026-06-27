#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Doc consistency =="

echo
echo "== Repository doc links =="
bash templates/scripts/check-doc-links.sh "$repo_root"
pass "repository doc links"

assert_exists "$repo_root/VERSION"
assert_exists "$repo_root/CHANGELOG.md"
assert_exists "$repo_root/docs/versioning.md"
assert_exists "$repo_root/docs/public-packaging.md"
assert_contains "$repo_root/VERSION" "0.1.1"
assert_contains "$repo_root/README.md" "CHANGELOG.md"
assert_contains "$repo_root/README.md" "docs/versioning.md"
assert_contains "$repo_root/README.md" "docs/public-packaging.md"
assert_contains "$repo_root/CHANGELOG.md" "v0.1.1"
assert_contains "$repo_root/docs/versioning.md" "Backward compatibility is best-effort before v1.0."
assert_contains "$repo_root/docs/public-packaging.md" "Repo-local completion gate for AI coding agents."
assert_contains "$repo_root/docs/public-packaging.md" "ai-agents"
assert_contains "$repo_root/docs/public-packaging.md" "v0.1.1 release checklist"
assert_contains "$repo_root/docs/public-packaging.md" "CI is passing"
assert_contains "$repo_root/docs/public-packaging.md" "default TDD evidence is opt-in"
assert_exists "$repo_root/ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "bash ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "Sandbox smoke"
assert_contains "$repo_root/docs/public-packaging.md" "Sandbox smoke"
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `VERSION` is `0.1.1`.'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `CHANGELOG.md` has a `v0.1.1` entry.'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `README.md` has a CI badge'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `install-agent-harness.sh` prints the short 3-step next path.'
assert_contains "$repo_root/docs/public-packaging.md" "- [x] Sandbox smoke is wired into CI"
assert_contains "$repo_root/docs/public-packaging.md" "- [ ] Set the GitHub description."
assert_contains "$repo_root/docs/public-packaging.md" '- [ ] Create the GitHub release tag `v0.1.1`.'
assert_contains "$repo_root/CHANGELOG.md" "Sandbox smoke readiness"
pass "release version documentation is present and referenced"

assert_contains "$repo_root/README.md" "## Context Loading Policy"
assert_contains "$repo_root/README.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/README.md" 'inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`'
assert_not_contains "$repo_root/README.md" 'the installed default task requires TDD evidence'
assert_contains "$repo_root/README.md" "## Platform Support"
assert_contains "$repo_root/README.md" "Unix-like shell environments"
assert_contains "$repo_root/README.md" "WSL"
assert_contains "$repo_root/README.md" "## Verification Strategy"
assert_contains "$repo_root/README.md" "## Choose A Gate Profile"
assert_contains "$repo_root/README.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/README.md" "Minimal"
assert_contains "$repo_root/README.md" "Standard"
assert_contains "$repo_root/README.md" "High-Risk"
assert_contains "$repo_root/README.md" "scripts/agent-task-profile.sh"
assert_not_contains "$repo_root/README.md" "## Architecture Evidence"
assert_not_contains "$repo_root/README.md" "## Episode And Audit Evidence"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇 Gate Profile"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "agent/gate-guide.md"
assert_contains "$repo_root/docs/agent-support-matrix.md" "agent/gate-guide.md"
assert_contains "$repo_root/README.md" '.agent/harness.yml'
assert_contains "$repo_root/README.md" '.agent/handoff.yml'
assert_contains "$repo_root/README.md" "## Evidence Vs Handoff"
assert_contains "$repo_root/README.md" 'completion.expects_handoff_update: true'
assert_contains "$repo_root/README.md" 'agent-finish.sh` does not enforce handoff freshness'
assert_contains "$repo_root/README.md" "docs/handoff.md"
assert_contains "$repo_root/README.md" "## Guardrails, Not A Sandbox"
assert_contains "$repo_root/README.md" "process guardrails"
assert_contains "$repo_root/README.md" "not security boundaries"
assert_contains "$repo_root/README.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.md" 'finish-summary.json'
assert_contains "$repo_root/README.md" "Resource Envelope"
assert_exists "$repo_root/docs/agent/episode-package.md"
assert_exists "$repo_root/docs/agent/failure-attribution.md"
assert_exists "$repo_root/docs/agent/interventions.md"
assert_exists "$repo_root/docs/agent/entropy-audit.md"
assert_exists "$repo_root/docs/agent/gate-guide.md"
assert_contains "$repo_root/docs/agent/gate-guide.md" "# Gate Guide"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Minimal Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Standard Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## High-Risk Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/docs/agent/gate-guide.md" "harness enforces the generated flags"

completion_flags="$(
  awk '
    /^  completion:/ { in_completion = 1; next }
    in_completion && /^[^ ]/ { in_completion = 0 }
    in_completion && $1 ~ /^(requires_|expects_)/ {
      flag = $1
      sub(/:$/, "", flag)
      print flag
    }
  ' "$repo_root/templates/.agent/task.yml"
)"

while IFS= read -r flag; do
  [ -n "$flag" ] || continue
  assert_contains "$repo_root/docs/agent/gate-guide.md" "$flag"
done <<EOF
$completion_flags
EOF
assert_contains "$repo_root/docs/runtime-boundaries.md" "episode package"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Sandbox verification"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Failure attribution"
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/episode-package.md"
assert_contains "$repo_root/templates/AGENTS.md" "scripts/agent-audit.sh"
assert_contains "$repo_root/templates/AGENTS.md" "sandbox verification"
assert_contains "$repo_root/README.zh-TW.md" "Resource Envelope"
assert_exists "$repo_root/docs/runtime-boundaries.md"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Implemented"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Not Implemented"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Agent-provider token accounting"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Filesystem sandboxing"
assert_contains "$repo_root/docs/public-packaging.md" "Production-harness follow-up checklist"
assert_exists "$repo_root/docs/handoff.md"
assert_contains "$repo_root/docs/handoff.md" '.agent/runs/<timestamp>/'
assert_contains "$repo_root/docs/handoff.md" 'handoff.md'
assert_contains "$repo_root/docs/handoff.md" '.agent/handoff.yml'
assert_contains "$repo_root/docs/handoff.md" 'expects_handoff_update'
assert_contains "$repo_root/docs/handoff.md" 'not part of `scripts/agent-finish.sh`'
assert_contains "$repo_root/schemas/task.schema.json" 'expects_handoff_update'
assert_not_contains "$repo_root/schemas/task.schema.json" 'requires_handoff_update'
assert_not_contains "$repo_root/schemas/task.schema.json" 'requires_doc_freshness_check'
assert_contains "$repo_root/templates/.agent/task.yml" 'expects_handoff_update: true'
assert_not_contains "$repo_root/templates/.agent/task.yml" 'requires_handoff_update'
assert_exists "$repo_root/templates/handoff.md"
assert_exists "$repo_root/templates/.agent/handoff.yml"
assert_exists "$repo_root/schemas/handoff.schema.json"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "## Context Loading Policy"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'Before editing, inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.'
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'Inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`.'
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Packets are not mandatory for all tasks and are not part"
assert_not_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'This evidence is optional and is not part of `scripts/agent-finish.sh` yet.'
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'completion.requires_subagent_evidence: true'
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" 'finish-summary.json'
assert_contains "$repo_root/docs/codex-usage.md" "staged context loading"
assert_contains "$repo_root/docs/codex-usage.md" "repair outcome"
assert_contains "$repo_root/docs/superpowers-integration.md" "staged context loading"
assert_contains "$repo_root/docs/superpowers-integration.md" "Sandbox verification"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "agent-sandbox-run.sh"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "Command ledger"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Explicit command ledger evidence"
assert_contains "$repo_root/docs/runtime-boundaries.md" "Full tool-call replay"
assert_contains "$repo_root/docs/superpowers-integration.md" "Command ledger"
assert_contains "$repo_root/templates/AGENTS.md" "agent-run"
assert_contains "$repo_root/templates/CLAUDE.md" "agent-run"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "agent-run"
assert_contains "$repo_root/templates/AGENTS.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/templates/CLAUDE.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/skills/verification-gate/SKILL.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/examples/rag-contract-system/README.md" "PYTHONPATH=src"
assert_contains "$repo_root/examples/rag-contract-system/README.md" "Never use global"
assert_contains "$repo_root/examples/rag-contract-system/adoption/report.md" "Harness files edited"

assert_contains "$target_root/docs/agent/context-loading.md" "# Context Loading Policy"
assert_contains "$target_root/docs/agent/context-loading.md" "Start compact."
assert_contains "$target_root/docs/agent/context-loading.md" "Expand only to files directly relevant to the current task."
assert_contains "$target_root/agent.md" "## Context Loading"
assert_contains "$target_root/agent.md" "Keep this file compact enough to read at task start."
pass "documentation stays aligned with staged context loading"
