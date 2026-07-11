#!/usr/bin/env bash
set -euo pipefail

FINISH_GATE_IDS=()
FINISH_GATE_KINDS=()
FINISH_GATE_GROUPS=()
FINISH_GATE_SCRIPTS=()
FINISH_GATE_COMMON_ARGS=()
FINISH_GATE_STRICT_ARGS=()
FINISH_GATE_BEST_EFFORT_ARGS=()
FINISH_GATE_RESULT_NAMES=()
FINISH_GATE_TASK_FLAGS=()
FINISH_GATE_STATUSES=()

finish_register_gate() {
  FINISH_GATE_IDS+=("$1")
  FINISH_GATE_KINDS+=("$2")
  FINISH_GATE_GROUPS+=("$3")
  FINISH_GATE_SCRIPTS+=("$4")
  FINISH_GATE_COMMON_ARGS+=("$5")
  FINISH_GATE_STRICT_ARGS+=("$6")
  FINISH_GATE_BEST_EFFORT_ARGS+=("$7")
  FINISH_GATE_RESULT_NAMES+=("$8")
  FINISH_GATE_TASK_FLAGS+=("$9")
  FINISH_GATE_STATUSES+=("")
}

finish_init_gate_registry() {
  FINISH_GATE_IDS=()
  FINISH_GATE_KINDS=()
  FINISH_GATE_GROUPS=()
  FINISH_GATE_SCRIPTS=()
  FINISH_GATE_COMMON_ARGS=()
  FINISH_GATE_STRICT_ARGS=()
  FINISH_GATE_BEST_EFFORT_ARGS=()
  FINISH_GATE_RESULT_NAMES=()
  FINISH_GATE_TASK_FLAGS=()
  FINISH_GATE_STATUSES=()

  finish_register_gate check-agent-md command 'Core Guardrails' \
    scripts/check-agent-md.sh agent.md '' '' check-agent-md-result.txt ''
  finish_register_gate check-scope command 'Core Guardrails' \
    scripts/check-scope.sh '' --strict --warn scope-result.txt \
    task.completion.requires_scope_check
  finish_register_gate check-policy command 'Core Guardrails' \
    scripts/check-policy.sh '' --strict --warn policy-result.txt \
    task.completion.requires_policy_check
  finish_register_gate check-tdd-evidence command 'Optional Evidence' \
    scripts/check-tdd-evidence.sh '' '' '' tdd-evidence-result.txt \
    task.completion.requires_tdd_evidence
  finish_register_gate check-acceptance command 'Optional Evidence' \
    scripts/check-acceptance.sh '' '' '' acceptance-result.txt \
    task.completion.requires_acceptance_check
  finish_register_gate check-review-evidence command 'Optional Evidence' \
    scripts/check-review-evidence.sh '' '' '' review-result.txt \
    task.completion.requires_review_evidence
  finish_register_gate check-architecture-evidence command 'Optional Evidence' \
    scripts/check-architecture-evidence.sh '' '' '' architecture-evidence-result.txt \
    task.completion.requires_architecture_evidence
  finish_register_gate check-failure-attribution command 'Optional Evidence' \
    scripts/check-failure-attribution.sh '' '' '' failure-attribution-result.txt \
    task.completion.requires_failure_attribution
  finish_register_gate check-interventions command 'Optional Evidence' \
    scripts/check-interventions.sh '' '' '' interventions-result.txt \
    task.completion.requires_intervention_record
  finish_register_gate check-command-ledger command 'Optional Evidence' \
    scripts/check-command-ledger.sh '' '' '' command-ledger-result.txt \
    task.completion.requires_command_ledger
  finish_register_gate check-sandbox-evidence command 'Optional Evidence' \
    scripts/check-sandbox-evidence.sh '' '' '' sandbox-evidence-result.txt \
    task.completion.requires_sandbox_verification
  finish_register_gate check-subagent-evidence command 'Optional Evidence' \
    scripts/check-subagent-evidence.sh '' '' '' subagent-evidence-result.txt \
    task.completion.requires_subagent_evidence
  finish_register_gate validate-episode command 'Verification And Limits' \
    scripts/validate-episode.sh '' '' '' episode-result.txt ''
  finish_register_gate agent-verify command 'Verification And Limits' \
    scripts/agent-verify.sh '' --strict --best-effort verify-result.txt \
    task.completion.requires_verification
  finish_register_gate resource-envelope computed 'Verification And Limits' \
    '' '' '' '' resource-envelope-result.txt ''
}

finish_gate_index() {
  local id="$1"
  local index

  for index in "${!FINISH_GATE_IDS[@]}"; do
    if [ "${FINISH_GATE_IDS[$index]}" = "$id" ]; then
      printf '%s\n' "$index"
      return 0
    fi
  done
  return 1
}

finish_set_gate_status() {
  local id="$1"
  local status="$2"
  local index

  if ! index="$(finish_gate_index "$id")"; then
    echo "ERROR: unregistered finish gate: $id" >&2
    return 1
  fi
  FINISH_GATE_STATUSES[$index]="$status"
}

finish_validate_gate_registry() {
  local expected_length="${#FINISH_GATE_IDS[@]}"
  local index
  local other_index

  for index in "${!FINISH_GATE_IDS[@]}"; do
    for other_index in "${!FINISH_GATE_IDS[@]}"; do
      if [ "$index" -lt "$other_index" ] && \
        [ "${FINISH_GATE_IDS[$index]}" = "${FINISH_GATE_IDS[$other_index]}" ]; then
        echo "ERROR: duplicate gate ID: ${FINISH_GATE_IDS[$index]}" >&2
        return 1
      fi
    done
  done

  if [ "${#FINISH_GATE_KINDS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_GROUPS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_SCRIPTS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_COMMON_ARGS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_STRICT_ARGS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_BEST_EFFORT_ARGS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_RESULT_NAMES[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_TASK_FLAGS[@]}" -ne "$expected_length" ] || \
    [ "${#FINISH_GATE_STATUSES[@]}" -ne "$expected_length" ]; then
    echo "ERROR: registry array length mismatch" >&2
    return 1
  fi

  for index in "${!FINISH_GATE_IDS[@]}"; do
    for other_index in "${!FINISH_GATE_IDS[@]}"; do
      if [ "$index" -lt "$other_index" ] && \
        [ "${FINISH_GATE_RESULT_NAMES[$index]}" = "${FINISH_GATE_RESULT_NAMES[$other_index]}" ]; then
        echo "ERROR: duplicate gate result name: ${FINISH_GATE_RESULT_NAMES[$index]}" >&2
        return 1
      fi
    done

    case "${FINISH_GATE_KINDS[$index]}" in
      command)
        if [ -z "${FINISH_GATE_SCRIPTS[$index]}" ]; then
          echo "ERROR: command gate has no script: ${FINISH_GATE_IDS[$index]}" >&2
          return 1
        fi
        ;;
      computed)
        if [ -n "${FINISH_GATE_SCRIPTS[$index]}" ]; then
          echo "ERROR: computed gate has a script: ${FINISH_GATE_IDS[$index]}" >&2
          return 1
        fi
        ;;
      *)
        echo "ERROR: unsupported gate kind: ${FINISH_GATE_KINDS[$index]}" >&2
        return 1
        ;;
    esac

    case "${FINISH_GATE_GROUPS[$index]}" in
      'Core Guardrails'|'Optional Evidence'|'Verification And Limits')
        ;;
      *)
        echo "ERROR: unsupported gate group: ${FINISH_GATE_GROUPS[$index]}" >&2
        return 1
        ;;
    esac
  done

  return 0
}
