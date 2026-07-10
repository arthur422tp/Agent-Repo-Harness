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
assert_contains "$repo_root/VERSION" "0.2.0"
assert_contains "$repo_root/README.md" "CHANGELOG.md"
assert_contains "$repo_root/README.md" "docs/versioning.md"
assert_contains "$repo_root/README.md" "docs/public-packaging.md"
assert_contains "$repo_root/CHANGELOG.md" "v0.2.0"
assert_contains "$repo_root/docs/versioning.md" "Backward compatibility is best-effort before v1.0."
assert_contains "$repo_root/docs/public-packaging.md" "Repo-local completion gate for AI coding agents."
assert_contains "$repo_root/docs/public-packaging.md" "ai-agents"
assert_contains "$repo_root/docs/public-packaging.md" "v0.2.0 release checklist"
assert_contains "$repo_root/docs/public-packaging.md" "CI is passing"
assert_contains "$repo_root/docs/public-packaging.md" "default TDD evidence is opt-in"
assert_exists "$repo_root/ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "bash ci/sandbox-smoke.sh"
assert_contains "$repo_root/.github/workflows/ci.yml" "Sandbox smoke"
assert_contains "$repo_root/docs/public-packaging.md" "Sandbox smoke"
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `VERSION` is `0.2.0`.'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `CHANGELOG.md` has a `v0.2.0` entry.'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `README.md` has a CI badge'
assert_contains "$repo_root/docs/public-packaging.md" '- [x] `install-agent-harness.sh` prints the short 3-step next path.'
assert_contains "$repo_root/docs/public-packaging.md" "- [x] Sandbox smoke is wired into CI"
assert_contains "$repo_root/docs/public-packaging.md" "- [ ] Set the GitHub description."
assert_contains "$repo_root/docs/public-packaging.md" '- [ ] Create the GitHub release tag `v0.2.0`.'
assert_contains "$repo_root/CHANGELOG.md" "Sandbox smoke readiness"
pass "release version documentation is present and referenced"

assert_contains "$repo_root/README.md" "## Quick Start"
assert_contains "$repo_root/README.md" "## Configure The Repository"
assert_contains "$repo_root/README.md" "## Run The First Task"
assert_contains "$repo_root/README.md" "## When Finish Fails"
assert_contains "$repo_root/README.md" "## Choose An Adoption Path"
assert_contains "$repo_root/README.md" "## Choose Verification And Gates"
assert_contains "$repo_root/README.md" "## Architecture And Boundaries"
assert_contains "$repo_root/README.md" "## Examples And References"
assert_contains "$repo_root/README.zh-TW.md" "## 快速開始"
assert_contains "$repo_root/README.zh-TW.md" "## 設定 Repository"
assert_contains "$repo_root/README.zh-TW.md" "## 執行第一個任務"
assert_contains "$repo_root/README.zh-TW.md" "## Finish 失敗時"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇導入路徑"
assert_contains "$repo_root/README.zh-TW.md" "## 選擇 Verification 與 Gates"
assert_contains "$repo_root/README.zh-TW.md" "## 架構與邊界"
assert_contains "$repo_root/README.zh-TW.md" "## 範例與參考資料"
assert_contains "$repo_root/README.md" 'applicable `.agent/policy.yml` entries'
assert_not_contains "$repo_root/README.md" 'inspect `agent.md`, `handoff.md`, `.agent/policy.yml`, and `.agent/task.yml`'
assert_not_contains "$repo_root/README.md" 'the installed default task requires TDD evidence'
assert_contains "$repo_root/README.md" "Platform Support"
assert_contains "$repo_root/README.md" "Unix-like shell environments"
assert_contains "$repo_root/README.md" "WSL"
assert_contains "$repo_root/README.md" "repo-defined commands are authoritative"
assert_contains "$repo_root/README.md" "task.verification_profile"
assert_contains "$repo_root/README.md" "heuristic fallback"
assert_contains "$repo_root/README.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/README.md" "Minimal"
assert_contains "$repo_root/README.md" "Standard"
assert_contains "$repo_root/README.md" "High-Risk"
assert_contains "$repo_root/README.md" "scripts/agent-task-profile.sh"
assert_not_contains "$repo_root/README.md" "## Architecture Evidence"
assert_not_contains "$repo_root/README.md" "## Episode And Audit Evidence"
assert_contains "$repo_root/README.zh-TW.md" "task.verification_profile"
assert_contains "$repo_root/README.zh-TW.md" "repo-defined commands 是具權威性的驗證來源"
assert_contains "$repo_root/README.zh-TW.md" "Minimal"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/gate-guide.md"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "agent/gate-guide.md"
assert_contains "$repo_root/docs/USAGE_WITH_AGENTS.md" "verification.profiles"
assert_contains "$repo_root/docs/agent-support-matrix.md" "agent/gate-guide.md"
assert_contains "$repo_root/README.md" '.agent/harness.yml'
assert_contains "$repo_root/README.md" '.agent/handoff.yml'
assert_contains "$repo_root/README.md" "Evidence Vs Handoff"
assert_contains "$repo_root/README.md" 'completion.expects_handoff_update: true'
assert_contains "$repo_root/README.md" 'agent-finish.sh` does not enforce handoff freshness'
assert_contains "$repo_root/README.md" "docs/handoff.md"
assert_contains "$repo_root/README.md" "Guardrails, Not A Sandbox"
assert_contains "$repo_root/README.md" "process guardrails"
assert_contains "$repo_root/README.md" "not security boundaries"
assert_contains "$repo_root/README.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.md" 'finish-summary.json'
assert_contains "$repo_root/README.md" "Resource Envelope"
assert_contains "$repo_root/README.md" "docs/agent/architecture-sensors.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/architecture-sensors.md"
assert_contains "$repo_root/README.zh-TW.md" "Platform Support"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-preflight.sh"
assert_contains "$repo_root/README.zh-TW.md" "scripts/agent-finish.sh"
assert_contains "$repo_root/README.zh-TW.md" "docs/agent/repair-failed-run.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/USAGE_WITH_AGENTS.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/runtime-boundaries.md"
assert_contains "$repo_root/README.zh-TW.md" "docs/stability-contract.md"

readme_lines="$(wc -l < "$repo_root/README.md" | tr -d ' ')"
readme_zh_lines="$(wc -l < "$repo_root/README.zh-TW.md" | tr -d ' ')"
[ "$readme_lines" -le 320 ] || fail "README.md exceeds the 320-line onboarding entrypoint ceiling"
[ "$readme_zh_lines" -le 320 ] || fail "README.zh-TW.md exceeds the 320-line onboarding entrypoint ceiling"
pass "README onboarding entrypoints stay concise"
assert_exists "$repo_root/docs/agent/episode-package.md"
assert_exists "$repo_root/docs/agent/failure-attribution.md"
assert_exists "$repo_root/docs/agent/interventions.md"
assert_exists "$repo_root/docs/agent/entropy-audit.md"
assert_exists "$repo_root/docs/agent/gate-guide.md"
assert_exists "$repo_root/docs/agent/repair-failed-run.md"
assert_exists "$repo_root/docs/agent/architecture-sensors.md"
cmp "$repo_root/docs/agent/repair-failed-run.md" "$repo_root/templates/docs/agent/repair-failed-run.md"
cmp "$repo_root/docs/agent/architecture-sensors.md" "$repo_root/templates/docs/agent/architecture-sensors.md"
assert_contains "$repo_root/docs/agent/gate-guide.md" "# Gate Guide"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Verification Profiles"
assert_contains "$repo_root/docs/agent/gate-guide.md" "--verification-profile"
assert_contains "$repo_root/docs/agent/repair-failed-run.md" "# Repair Failed Finish Runs"
assert_contains "$repo_root/docs/agent/architecture-sensors.md" "# Architecture Sensors"
assert_contains "$repo_root/docs/agent/repair-failed-run.md" "scope-result.txt"
assert_contains "$repo_root/docs/agent/repair-failed-run.md" "policy-result.txt"
assert_contains "$repo_root/docs/agent/repair-failed-run.md" "verify-result.txt"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Minimal Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## Standard Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "## High-Risk Profile"
assert_contains "$repo_root/docs/agent/gate-guide.md" "scripts/agent-task-profile.sh"
assert_contains "$repo_root/docs/agent/gate-guide.md" "harness enforces the generated flags"
assert_contains "$repo_root/docs/stability-contract.md" "task.verification_profile"
assert_contains "$repo_root/CHANGELOG.md" "configured verification commands now suppress language heuristics"
assert_not_contains "$repo_root/examples/rag-contract-system/adoption/report.md" "heuristic discovery runs in addition to configured commands"

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
