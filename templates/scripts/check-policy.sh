#!/usr/bin/env bash
set -euo pipefail

policy_file="${1:-.agent/policy.yml}"

if [ ! -f "$policy_file" ]; then
  echo "SKIP: policy file not found at $policy_file"
  exit 0
fi

list_changed_files() {
  {
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | awk 'NF' | sort -u
}

extract_patterns() {
  awk '
    /^high_risk_patterns:/ { in_list=1; next }
    /^risk_files:/ { in_risk=1; next }
    in_risk && /^[[:space:]]*high:/ { in_list=1; next }
    in_list && /^[^[:space:]-]/ { in_list=0 }
    in_risk && /^[^[:space:]]/ && $0 !~ /^risk_files:/ { in_risk=0 }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/"/, "", line)
      print line
    }
  ' "$policy_file"
}

changed_files="$(list_changed_files)"

if [ -z "$changed_files" ]; then
  echo "No changed files detected."
  exit 0
fi

echo "== Policy Gate =="
echo "Policy file: $policy_file"

matched=0
while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [[ "$file" == $pattern ]]; then
      if [ "$matched" -eq 0 ]; then
        echo
        echo "Warnings:"
      fi
      matched=1
      echo "- $file matches policy pattern $pattern"
    fi
  done <<EOF
$changed_files
EOF
done <<EOF
$(extract_patterns)
EOF

if [ "$matched" -eq 0 ]; then
  echo "No policy warnings."
else
  echo
  echo "Review recommended before claiming completion."
fi
