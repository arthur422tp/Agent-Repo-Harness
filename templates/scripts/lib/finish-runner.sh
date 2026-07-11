#!/usr/bin/env bash
set -euo pipefail

finish_run_registered_gates() {
  local mode="$1"
  local run_dir="$2"
  local index
  local output_file
  local result_file
  local result_temp_file
  local status
  local command
  local output_temp_created=0

  for index in "${!FINISH_GATE_IDS[@]}"; do
    [ "${FINISH_GATE_KINDS[$index]}" = command ] || continue

    command=(bash "${FINISH_GATE_SCRIPTS[$index]}")
    [ -n "${FINISH_GATE_COMMON_ARGS[$index]}" ] && \
      command+=("${FINISH_GATE_COMMON_ARGS[$index]}")
    if [ "$mode" = strict ] && [ -n "${FINISH_GATE_STRICT_ARGS[$index]}" ]; then
      command+=("${FINISH_GATE_STRICT_ARGS[$index]}")
    fi
    if [ "$mode" = best-effort ] && \
      [ -n "${FINISH_GATE_BEST_EFFORT_ARGS[$index]}" ]; then
      command+=("${FINISH_GATE_BEST_EFFORT_ARGS[$index]}")
    fi

    echo
    echo "RUN: ${FINISH_GATE_IDS[$index]}"
    output_file="$(harness_make_temp_file "$run_dir" finish-gate-output)"
    output_temp_created=1
    if "${command[@]}" >"$output_file" 2>&1; then
      status=0
    else
      status=$?
    fi

    cat "$output_file"
    result_file="$run_dir/${FINISH_GATE_RESULT_NAMES[$index]}"
    result_temp_file="$(harness_make_temp_file "$run_dir" finish-gate-result)"
    {
      echo "Check: ${FINISH_GATE_IDS[$index]}"
      echo "Command: ${command[*]}"
      echo "Exit status: $status"
      echo
      echo "Output:"
      cat "$output_file"
    } >"$result_temp_file"
    if ! harness_atomic_replace "$result_temp_file" "$result_file"; then
      status=1
    fi
    rm -f "$output_file"
    output_temp_created=0

    finish_set_gate_status "${FINISH_GATE_IDS[$index]}" "$status"
    if [ "$status" -ne 0 ]; then
      failures=$((failures + 1))
    fi
  done

  [ "$failures" -eq 0 ]
}
