#!/usr/bin/env bash
set -euo pipefail

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

timestamp="$(date -u +"%Y%m%d-%H%M%S")"
audit_dir=".agent/audits/$timestamp"
report_md="$audit_dir/entropy-report.md"
report_json="$audit_dir/entropy-report.json"
mkdir -p "$audit_dir"

failures=0
check_status=0
doc_links_status=0
git_status_status=0
harness_config_status=0

run_check() {
  local label="$1"
  local output_file="$audit_dir/$label.txt"
  local status
  shift

  set +e
  "$@" >"$output_file" 2>&1
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    failures=$((failures + 1))
  fi

  check_status="$status"
}

if [ -f scripts/check-doc-links.sh ]; then
  run_check doc-links bash scripts/check-doc-links.sh
  doc_links_status="$check_status"
else
  printf '%s\n' "SKIP: scripts/check-doc-links.sh not found" > "$audit_dir/doc-links.txt"
  doc_links_status=0
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  run_check git-status git status --short
  git_status_status="$check_status"
else
  printf '%s\n' "SKIP: not inside a git repository" > "$audit_dir/git-status.txt"
  git_status_status=0
fi

if [ -f .agent/harness.yml ] && [ -f scripts/validate-config.sh ]; then
  run_check harness-config bash scripts/validate-config.sh
  harness_config_status="$check_status"
else
  printf '%s\n' "SKIP: harness config validation unavailable" > "$audit_dir/harness-config.txt"
  harness_config_status=0
fi

overall_result="pass"
if [ "$failures" -gt 0 ]; then
  overall_result="fail"
fi

{
  echo "# Agent Entropy Audit"
  echo
  echo "- Timestamp: $timestamp"
  echo "- Overall result: $overall_result"
  echo "- Audit directory: $audit_dir"
  echo
  echo "## Audit Checks"
  echo
  echo "| Check | Exit status | Evidence |"
  echo "| --- | ---: | --- |"
  echo "| doc-links | $doc_links_status | $audit_dir/doc-links.txt |"
  echo "| git-status | $git_status_status | $audit_dir/git-status.txt |"
  echo "| harness-config | $harness_config_status | $audit_dir/harness-config.txt |"
} > "$report_md"

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for audit JSON writes"
  exit 1
fi

REPORT_JSON="$report_json" \
AUDIT_TIMESTAMP="$timestamp" \
AUDIT_RESULT="$overall_result" \
AUDIT_DIR="$audit_dir" \
DOC_LINKS_STATUS="$doc_links_status" \
GIT_STATUS_STATUS="$git_status_status" \
HARNESS_CONFIG_STATUS="$harness_config_status" \
"$python_bin" - <<'PY'
import json
import os
from pathlib import Path

audit_dir = os.environ["AUDIT_DIR"]
data = {
    "timestamp": os.environ["AUDIT_TIMESTAMP"],
    "overall_result": os.environ["AUDIT_RESULT"],
    "audit_dir": audit_dir,
    "checks": [
        {
            "name": "doc-links",
            "exit_status": int(os.environ["DOC_LINKS_STATUS"]),
            "evidence": f"{audit_dir}/doc-links.txt",
        },
        {
            "name": "git-status",
            "exit_status": int(os.environ["GIT_STATUS_STATUS"]),
            "evidence": f"{audit_dir}/git-status.txt",
        },
        {
            "name": "harness-config",
            "exit_status": int(os.environ["HARNESS_CONFIG_STATUS"]),
            "evidence": f"{audit_dir}/harness-config.txt",
        },
    ],
    "evidence": {
        "markdown_report": f"{audit_dir}/entropy-report.md",
    },
}
Path(os.environ["REPORT_JSON"]).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

echo "AGENT_AUDIT_RESULT=$overall_result"
echo "Audit directory: $audit_dir"

if [ "$overall_result" = "fail" ]; then
  exit 1
fi
