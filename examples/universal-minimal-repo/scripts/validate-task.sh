#!/usr/bin/env bash
set -euo pipefail

test -f .agent/task.yml
echo "TASK_VALIDATION_RESULT=pass"
