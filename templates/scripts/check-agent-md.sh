#!/usr/bin/env bash
set -euo pipefail

file="${1:-agent.md}"

if [ ! -f "$file" ]; then
  echo "ERROR: $file not found"
  exit 1
fi

required=(
  "Project Overview"
  "Architecture Map"
  "Common Commands"
  "Verification"
  "Risk Areas"
  "Agent Rules"
)

for heading in "${required[@]}"; do
  if ! grep -q "$heading" "$file"; then
    echo "ERROR: missing heading: $heading"
    exit 1
  fi
done

if grep -q "Current Task" "$file"; then
  echo "ERROR: agent.md appears to contain handoff content"
  exit 1
fi

echo "$file basic checks passed."
