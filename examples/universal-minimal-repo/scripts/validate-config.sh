#!/usr/bin/env bash
set -euo pipefail

test -f .agent/harness.yml
test -f .agent/policy.yml
echo "CONFIG_VALIDATION_RESULT=pass"
