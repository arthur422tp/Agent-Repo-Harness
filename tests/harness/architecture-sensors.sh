#!/usr/bin/env bash
set -euo pipefail

if [ -z "${repo_root:-}" ]; then
  source "$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)/tests/harness/lib.sh"
fi

echo
echo "== Import boundary sensor pass =="
rm -rf "$architecture_sensor_pass_root"
mkdir -p "$architecture_sensor_pass_root/src/app" "$architecture_sensor_pass_root/tests/fixtures" "$architecture_sensor_pass_root/scripts"
(
  cd "$architecture_sensor_pass_root"
  cp "$repo_root/templates/scripts/check-import-boundaries.py" scripts/check-import-boundaries.py
  cat > src/app/cli.py <<'PY'
from app.service import run
PY
  cat > src/app/service.py <<'PY'
def run():
    return "ok"
PY
  cat > tests/fixtures/sample.py <<'PY'
VALUE = "fixture"
PY
  python_bin="$(find_python)"
  "$python_bin" scripts/check-import-boundaries.py \
    --source src/app \
    --forbidden-import tests.fixtures \
    > sensor.log 2>&1
  assert_contains sensor.log "IMPORT_BOUNDARY_RESULT=pass"
)
pass "import boundary sensor pass"

echo
echo "== Import boundary sensor fail =="
rm -rf "$architecture_sensor_fail_root"
mkdir -p "$architecture_sensor_fail_root/src/app" "$architecture_sensor_fail_root/tests/fixtures" "$architecture_sensor_fail_root/scripts"
(
  cd "$architecture_sensor_fail_root"
  cp "$repo_root/templates/scripts/check-import-boundaries.py" scripts/check-import-boundaries.py
  cat > src/app/cli.py <<'PY'
from tests.fixtures.sample import VALUE
PY
  cat > tests/fixtures/sample.py <<'PY'
VALUE = "fixture"
PY
  python_bin="$(find_python)"
  if "$python_bin" scripts/check-import-boundaries.py --source src/app --forbidden-import tests.fixtures > sensor.log 2>&1; then
    echo "ERROR: expected import boundary failure"
    exit 1
  fi
  assert_contains sensor.log "FAIL: src/app/cli.py imports forbidden module tests.fixtures"
  assert_contains sensor.log "IMPORT_BOUNDARY_RESULT=fail"
)
pass "import boundary sensor fail"

echo
echo "== Architecture sensor example files =="
assert_exists "$repo_root/examples/architecture-sensors/import-boundary/README.md"
assert_exists "$repo_root/examples/architecture-sensors/import-boundary/.agent/harness.yml"
assert_exists "$repo_root/examples/architecture-sensors/import-boundary/.agent/architecture.yml"
assert_contains "$repo_root/examples/architecture-sensors/import-boundary/README.md" "IMPORT_BOUNDARY_RESULT=pass"
assert_contains "$repo_root/examples/architecture-sensors/import-boundary/.agent/architecture.yml" "evidence_refs:"
pass "architecture sensor example files"
