#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

# Keep this entrypoint stable. The individual suites live under tests/harness/
# so subsystem checks can grow without turning this file into a monolith again.
source "$repo_root/tests/harness/lib.sh"
source "$repo_root/tests/harness/static-install.sh"
source "$repo_root/tests/harness/verification-modes.sh"
source "$repo_root/tests/harness/scope.sh"
source "$repo_root/tests/harness/policy.sh"
source "$repo_root/tests/harness/task-validation.sh"
source "$repo_root/tests/harness/acceptance-review.sh"
source "$repo_root/tests/harness/repo-verification.sh"
source "$repo_root/tests/harness/finish-examples.sh"
