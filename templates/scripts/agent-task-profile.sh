#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-task-profile.sh PROFILE [options]

Profiles:
  minimal
  standard
  high-risk

Options:
  --goal TEXT
  --current-task TEXT
  --source-plan PATH_OR_TEXT
  --allowed GLOB
  --forbidden GLOB
  --max-changed-files N
  --max-diff-lines N
  --architecture
  --review
  --command-ledger
  --sandbox
  --subagent
  --failure-attribution
  --intervention-record
  --status STATUS
  --output PATH
  --dry-run
  -h, --help
EOF
}

quote_yaml() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

require_option_value() {
  local option="$1"
  local value="${2:-}"

  if [ -z "$value" ]; then
    echo "ERROR: $option requires a value"
    exit 2
  fi
}

profile="${1:-}"
case "$profile" in
  -h|--help)
    usage
    exit 0
    ;;
  minimal|standard|high-risk)
    shift
    ;;
  "")
    usage
    exit 2
    ;;
  *)
    echo "ERROR: unsupported profile: $profile"
    usage
    exit 2
    ;;
esac

goal=""
current_task=""
source_plan=""
status="in_progress"
output=".agent/task.yml"
max_changed_files=""
max_diff_lines=""
dry_run="false"
allowed_paths=()
forbidden_paths=()
requires_review_evidence="false"
requires_architecture_evidence="false"
requires_failure_attribution="false"
requires_intervention_record="false"
requires_command_ledger="false"
requires_sandbox_verification="false"
requires_subagent_evidence="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --goal)
      require_option_value "$1" "${2:-}"
      goal="$2"
      shift 2
      ;;
    --current-task)
      require_option_value "$1" "${2:-}"
      current_task="$2"
      shift 2
      ;;
    --source-plan)
      require_option_value "$1" "${2:-}"
      source_plan="$2"
      shift 2
      ;;
    --allowed)
      require_option_value "$1" "${2:-}"
      allowed_paths+=("$2")
      shift 2
      ;;
    --forbidden)
      require_option_value "$1" "${2:-}"
      forbidden_paths+=("$2")
      shift 2
      ;;
    --max-changed-files)
      require_option_value "$1" "${2:-}"
      max_changed_files="$2"
      shift 2
      ;;
    --max-diff-lines)
      require_option_value "$1" "${2:-}"
      max_diff_lines="$2"
      shift 2
      ;;
    --architecture)
      requires_architecture_evidence="true"
      shift
      ;;
    --review)
      requires_review_evidence="true"
      shift
      ;;
    --command-ledger)
      requires_command_ledger="true"
      shift
      ;;
    --sandbox)
      requires_sandbox_verification="true"
      shift
      ;;
    --subagent)
      requires_subagent_evidence="true"
      shift
      ;;
    --failure-attribution)
      requires_failure_attribution="true"
      shift
      ;;
    --intervention-record)
      requires_intervention_record="true"
      shift
      ;;
    --status)
      require_option_value "$1" "${2:-}"
      status="$2"
      shift 2
      ;;
    --output)
      require_option_value "$1" "${2:-}"
      output="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unsupported option: $1"
      usage
      exit 2
      ;;
  esac
done

case "$status" in
  not_started|in_progress|blocked|ready_for_review|complete) ;;
  *)
    echo "ERROR: unsupported status: $status"
    exit 2
    ;;
esac

case "$profile" in
  minimal)
    requires_tdd_evidence="false"
    requires_acceptance_check="false"
    ;;
  standard|high-risk)
    requires_tdd_evidence="true"
    requires_acceptance_check="true"
    ;;
esac

if [ -z "$goal" ]; then
  echo "ERROR: --goal is required"
  exit 2
fi

render_yaml_list() {
  if [ "$#" -eq 0 ]; then
    printf ' []\n'
    return 0
  fi

  printf '\n'
  local item
  for item in "$@"; do
    printf '    - %s\n' "$(quote_yaml "$item")"
  done
}

render_task() {
  printf 'task:\n'
  printf '  status: %s\n' "$(quote_yaml "$status")"
  printf '  goal: %s\n' "$(quote_yaml "$goal")"
  if [ -n "$source_plan" ]; then
    printf '  source_plan: %s\n' "$(quote_yaml "$source_plan")"
  fi
  if [ -n "$current_task" ]; then
    printf '  current_task: %s\n' "$(quote_yaml "$current_task")"
  fi
  printf '  allowed_paths:'
  if [ "${#allowed_paths[@]}" -eq 0 ]; then
    render_yaml_list
  else
    render_yaml_list "${allowed_paths[@]}"
  fi
  printf '  forbidden_paths:'
  if [ "${#forbidden_paths[@]}" -eq 0 ]; then
    render_yaml_list
  else
    render_yaml_list "${forbidden_paths[@]}"
  fi
  if [ -n "$max_changed_files" ]; then
    printf '  max_changed_files: %s\n' "$max_changed_files"
  fi
  if [ -n "$max_diff_lines" ]; then
    printf '  max_diff_lines: %s\n' "$max_diff_lines"
  fi
  printf '  completion:\n'
  printf '    requires_scope_check: true\n'
  printf '    requires_policy_check: true\n'
  printf '    requires_verification: true\n'
  printf '    expects_handoff_update: true\n'
  printf '    requires_tdd_evidence: %s\n' "$requires_tdd_evidence"
  printf '    requires_acceptance_check: %s\n' "$requires_acceptance_check"
  printf '    requires_review_evidence: %s\n' "$requires_review_evidence"
  printf '    requires_architecture_evidence: %s\n' "$requires_architecture_evidence"
  printf '    requires_failure_attribution: %s\n' "$requires_failure_attribution"
  printf '    requires_intervention_record: %s\n' "$requires_intervention_record"
  printf '    requires_command_ledger: %s\n' "$requires_command_ledger"
  printf '    requires_sandbox_verification: %s\n' "$requires_sandbox_verification"
  printf '    requires_subagent_evidence: %s\n' "$requires_subagent_evidence"
}

echo "Profile: $profile" >&2
echo "Output: $output" >&2
echo "Enabled high-risk gates:" >&2
echo "- review: $requires_review_evidence" >&2
echo "- architecture: $requires_architecture_evidence" >&2
echo "- command_ledger: $requires_command_ledger" >&2
echo "- sandbox: $requires_sandbox_verification" >&2
echo "- subagent: $requires_subagent_evidence" >&2
echo "- failure_attribution: $requires_failure_attribution" >&2
echo "- intervention_record: $requires_intervention_record" >&2

if [ "$dry_run" = "true" ]; then
  render_task
else
  mkdir -p "$(dirname "$output")"
  render_task > "$output"
fi

echo "AGENT_TASK_PROFILE_RESULT=pass"
