#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
fixture_root="$repo_root/tests/fixtures/validate-harness"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-validate.XXXXXX")"
target_root="$tmp_root/target"
warnings_root="$tmp_root/warnings"
failure_root="$tmp_root/failure"
scope_skip_root="$tmp_root/scope-skip"
scope_pass_root="$tmp_root/scope-pass"
scope_max_files_root="$tmp_root/scope-max-files"
scope_outside_root="$tmp_root/scope-outside"
scope_forbidden_root="$tmp_root/scope-forbidden"
scope_malformed_root="$tmp_root/scope-malformed"
policy_strict_root="$tmp_root/policy-strict"
policy_warn_root="$tmp_root/policy-warn"
policy_file_approval_root="$tmp_root/policy-file-approval"
policy_legacy_root="$tmp_root/policy-legacy"
policy_malformed_root="$tmp_root/policy-malformed"
verify_config_root="$tmp_root/verify-config"
verify_bad_config_root="$tmp_root/verify-bad-config"
finish_acceptance_review_root="$tmp_root/finish-acceptance-review"
finish_strict_root="$tmp_root/finish-strict"
finish_nongit_root="$tmp_root/finish-nongit"
tdd_required_failure_root="$tmp_root/tdd-required-failure"
doc_links_failure_root="$tmp_root/doc-links-failure"
yaml_reader_root="$tmp_root/yaml-reader"
task_config_root="$tmp_root/task-config"
task_bad_config_root="$tmp_root/task-bad-config"
task_missing_nested_root="$tmp_root/task-missing-nested"
task_invalid_types_root="$tmp_root/task-invalid-types"
acceptance_skip_root="$tmp_root/acceptance-skip"
acceptance_pass_root="$tmp_root/acceptance-pass"
acceptance_unmet_root="$tmp_root/acceptance-unmet"
acceptance_missing_evidence_root="$tmp_root/acceptance-missing-evidence"
review_skip_root="$tmp_root/review-skip"
review_pass_root="$tmp_root/review-pass"
review_blocked_root="$tmp_root/review-blocked"
review_required_false_root="$tmp_root/review-required-false"
review_required_missing_root="$tmp_root/review-required-missing"
review_missing_concerns_root="$tmp_root/review-missing-concerns"
review_null_concerns_root="$tmp_root/review-null-concerns"
review_scalar_concerns_root="$tmp_root/review-scalar-concerns"

cleanup() {
  rm -rf "$tmp_root"
}

trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "ERROR: expected output to contain: $expected"
    echo "File: $file"
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    echo "ERROR: expected output not to contain: $unexpected"
    echo "File: $file"
    exit 1
  fi
}

assert_exists() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "ERROR: expected path to exist: $path"
    exit 1
  fi
}

assert_not_exists() {
  local path="$1"

  if [ -e "$path" ]; then
    echo "ERROR: expected path not to exist: $path"
    exit 1
  fi
}

copy_fixture() {
  local name="$1"
  local target="$2"

  cp "$fixture_root/$name" "$target"
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  echo "ERROR: python is required for validation"
  exit 1
}

assert_file_contains() {
  local root="$1"
  local name="$2"
  local expected="$3"
  local file

  file="$(find "$root/.agent/runs" -type f -name "$name" | head -n 1)"
  if [ -z "$file" ]; then
    echo "ERROR: expected run evidence file named: $name"
    exit 1
  fi

  assert_contains "$file" "$expected"
}

assert_file_not_contains() {
  local root="$1"
  local name="$2"
  local unexpected="$3"
  local file

  file="$(find "$root/.agent/runs" -type f -name "$name" | head -n 1)"
  if [ -z "$file" ]; then
    echo "ERROR: expected run evidence file named: $name"
    exit 1
  fi

  assert_not_contains "$file" "$unexpected"
}

assert_run_evidence_files() {
  local root="$1"
  local file

  for file in \
    finish-summary.md \
    check-agent-md-result.txt \
    scope-result.txt \
    policy-result.txt \
    tdd-evidence-result.txt \
    acceptance-result.txt \
    review-result.txt \
    subagent-evidence-result.txt \
    verify-result.txt \
    changed-files.txt \
    git-diff-stat.txt
  do
    if ! find "$root/.agent/runs" -type f -name "$file" | grep -q .; then
      echo "ERROR: expected run evidence file named: $file"
      exit 1
    fi
  done
}

assert_finish_summary_contract() {
  local root="$1"
  local expected_result="$2"

  assert_file_contains "$root" "finish-summary.md" "Timestamp:"
  assert_file_contains "$root" "finish-summary.md" "Mode:"
  assert_file_contains "$root" "finish-summary.md" "Run directory: .agent/runs/"
  assert_file_contains "$root" "finish-summary.md" "Overall result: $expected_result"
  assert_file_contains "$root" "finish-summary.md" "| check-agent-md |"
  assert_file_contains "$root" "finish-summary.md" "| check-scope |"
  assert_file_contains "$root" "finish-summary.md" "| check-policy |"
  assert_file_contains "$root" "finish-summary.md" "| check-tdd-evidence |"
  assert_file_contains "$root" "finish-summary.md" "| check-acceptance |"
  assert_file_contains "$root" "finish-summary.md" "| check-review-evidence |"
  assert_file_contains "$root" "finish-summary.md" "| check-subagent-evidence |"
  assert_file_contains "$root" "finish-summary.md" "| agent-verify |"
  assert_file_contains "$root" "finish-summary.md" "check-agent-md-result.txt"
  assert_file_contains "$root" "finish-summary.md" "scope-result.txt"
  assert_file_contains "$root" "finish-summary.md" "policy-result.txt"
  assert_file_contains "$root" "finish-summary.md" "tdd-evidence-result.txt"
  assert_file_contains "$root" "finish-summary.md" "acceptance-result.txt"
  assert_file_contains "$root" "finish-summary.md" "review-result.txt"
  assert_file_contains "$root" "finish-summary.md" "subagent-evidence-result.txt"
  assert_file_contains "$root" "finish-summary.md" "verify-result.txt"
  assert_file_contains "$root" "finish-summary.md" "changed-files.txt"
  assert_file_contains "$root" "finish-summary.md" "git-diff-stat.txt"
  assert_file_contains "$root" "finish-summary.md" "## Changed Files"
  assert_file_contains "$root" "finish-summary.md" "## Git Diff Stat"
  assert_file_contains "$root" "finish-summary.md" "## Next Recommended Action"
}

assert_finish_json_contract() {
  local root="$1"
  local expected_result="$2"
  local summary_json

  summary_json="$(find "$root/.agent/runs" -type f -name "finish-summary.json" | sort | tail -n 1)"
  if [ -z "$summary_json" ]; then
    echo "ERROR: expected finish-summary.json under $root/.agent/runs"
    exit 1
  fi

  "$(find_python)" - "$summary_json" "$expected_result" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
expected_result = sys.argv[2]
data = json.loads(summary_path.read_text(encoding="utf-8"))

required_top_level = {
    "timestamp",
    "mode",
    "command",
    "run_dir",
    "overall_result",
    "gates",
    "evidence",
    "elapsed_seconds",
    "resource_envelope_status",
}
missing = sorted(required_top_level - set(data))
if missing:
    raise SystemExit(f"missing top-level keys: {missing}")

if data["overall_result"] != expected_result:
    raise SystemExit(
        f"expected overall_result {expected_result}, got {data['overall_result']}"
    )

if not isinstance(data["gates"], list) or not data["gates"]:
    raise SystemExit("gates must be a non-empty list")

expected_gate_names = [
    "check-agent-md",
    "check-scope",
    "check-policy",
    "check-tdd-evidence",
    "check-acceptance",
    "check-review-evidence",
    "check-subagent-evidence",
    "agent-verify",
    "resource-envelope",
]
actual_gate_names = [gate.get("name") for gate in data["gates"]]
if actual_gate_names != expected_gate_names:
    raise SystemExit(
        f"expected gate names {expected_gate_names}, got {actual_gate_names}"
    )

expected_gate_evidence = {
    "check-agent-md": "check-agent-md-result.txt",
    "check-scope": "scope-result.txt",
    "check-policy": "policy-result.txt",
    "check-tdd-evidence": "tdd-evidence-result.txt",
    "check-acceptance": "acceptance-result.txt",
    "check-review-evidence": "review-result.txt",
    "check-subagent-evidence": "subagent-evidence-result.txt",
    "agent-verify": "verify-result.txt",
    "resource-envelope": "resource-envelope-result.txt",
}

for gate in data["gates"]:
    for key in ("name", "exit_status", "evidence"):
        if key not in gate:
            raise SystemExit(f"gate missing {key}: {gate}")
    if not isinstance(gate["exit_status"], int):
        raise SystemExit(f"gate exit_status must be int: {gate}")
    expected_evidence = expected_gate_evidence[gate["name"]]
    if gate["evidence"] != f"{data['run_dir']}/{expected_evidence}":
        raise SystemExit(
            f"expected {gate['name']} evidence to end with "
            f"{expected_evidence}, got {gate['evidence']}"
        )

if not isinstance(data["resource_envelope_status"], int):
    raise SystemExit("resource_envelope_status must be an integer")

for key in ("changed_files", "diff_stat", "markdown_summary"):
    if key not in data["evidence"]:
        raise SystemExit(f"evidence missing {key}")

expected_evidence_paths = {
    "changed_files": "changed-files.txt",
    "diff_stat": "git-diff-stat.txt",
    "markdown_summary": "finish-summary.md",
}
for key, name in expected_evidence_paths.items():
    if data["evidence"][key] != f"{data['run_dir']}/{name}":
        raise SystemExit(
            f"expected evidence.{key} to be {data['run_dir']}/{name}, "
            f"got {data['evidence'][key]}"
        )

if not isinstance(data["elapsed_seconds"], int):
    raise SystemExit("elapsed_seconds must be an integer")
PY
}

run_yaml_syntax_checks() {
  local yaml_files=()
  local file

  while IFS= read -r -d '' file; do
    yaml_files+=("$file")
  done < <(find templates/.agent examples -type f -name "*.yml" -print0)

  if [ "${#yaml_files[@]}" -eq 0 ]; then
    echo "ERROR: no YAML files found for validation"
    exit 1
  fi

  ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }' "${yaml_files[@]}"
}

run_json_syntax_checks() {
  local json_files=()
  local file

  while IFS= read -r -d '' file; do
    json_files+=("$file")
  done < <(find schemas -type f -name "*.json" -print0)

  if [ "${#json_files[@]}" -eq 0 ]; then
    echo "ERROR: no JSON schema files found for validation"
    exit 1
  fi

  ruby -rjson -e 'ARGV.each { |f| JSON.parse(File.read(f)) }' "${json_files[@]}"
}

run_shell_format_checks() {
  local file
  local first_line
  local second_line
  local line_count
  local max_line_length

  while IFS= read -r file; do
    bash -n "$file"

    first_line="$(sed -n '1p' "$file")"
    second_line="$(sed -n '2p' "$file")"
    line_count="$(wc -l < "$file" | tr -d '[:space:]')"
    max_line_length="$(awk 'BEGIN { max = 0 } length($0) > max { max = length($0) } END { print max }' "$file")"

    if [ "$first_line" != "#!/usr/bin/env bash" ]; then
      echo "ERROR: missing bash shebang in $file"
      exit 1
    fi

    if printf '%s\n' "$first_line" | grep -Fq "set -euo pipefail"; then
      echo "ERROR: set -euo pipefail must not appear on the shebang line in $file"
      exit 1
    fi

    if [ "$second_line" != "set -euo pipefail" ]; then
      echo "ERROR: missing set -euo pipefail in $file"
      exit 1
    fi

    if [ "$line_count" -lt 3 ]; then
      echo "ERROR: shell script appears compressed or malformed: $file"
      exit 1
    fi

    case "$file" in
      ./install-agent-harness.sh|./validate-harness.sh|./templates/scripts/*.sh)
        if [ "$line_count" -lt 10 ]; then
          echo "ERROR: shell script appears compressed or malformed: $file"
          exit 1
        fi
        ;;
    esac

    if [ "$max_line_length" -gt 180 ]; then
      echo "ERROR: shell script has an overlong line; possible compressed formatting: $file"
      exit 1
    fi
  done < <(find . -type f -name "*.sh" -not -path "./.git/*" | sort)
}
