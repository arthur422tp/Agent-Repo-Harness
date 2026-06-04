#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Entropy audit report =="
audit_root="$tmp_root/entropy-audit"
rm -rf "$audit_root"
mkdir -p "$audit_root/.agent" "$audit_root/scripts/lib" "$audit_root/docs"
git init -q "$audit_root"
(
  cd "$audit_root"
  cp "$repo_root/templates/scripts/agent-audit.sh" scripts/agent-audit.sh
  cp "$repo_root/templates/scripts/check-doc-links.sh" scripts/check-doc-links.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/.agent/harness.yml" .agent/harness.yml
  chmod +x scripts/*.sh
  printf '%s\n' '# Audit Fixture' > README.md
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .
  git commit -q -m "Add audit fixture"
  bash scripts/agent-audit.sh > audit.log 2>&1
  assert_contains audit.log "AGENT_AUDIT_RESULT=pass"
  audit_json="$(find .agent/audits -type f -name "entropy-report.json" | sort | tail -n 1)"
  audit_md="$(find .agent/audits -type f -name "entropy-report.md" | sort | tail -n 1)"
  assert_exists "$audit_json"
  assert_exists "$audit_md"
  assert_contains "$audit_md" "## Audit Checks"
  "$(find_python)" - "$audit_json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
required = {"timestamp", "overall_result", "checks", "evidence"}
missing = required.difference(data)
if missing:
    raise SystemExit(f"missing audit keys: {sorted(missing)}")
names = {check["name"] for check in data["checks"]}
for expected in ("doc-links", "git-status", "harness-config"):
    if expected not in names:
        raise SystemExit(f"missing audit check: {expected}")
PY
)
pass "entropy audit report"

echo
echo "== Entropy audit failed check result =="
audit_failure_root="$tmp_root/entropy-audit-failure"
rm -rf "$audit_failure_root"
mkdir -p "$audit_failure_root/.agent" "$audit_failure_root/scripts/lib"
git init -q "$audit_failure_root"
(
  cd "$audit_failure_root"
  cp "$repo_root/templates/scripts/agent-audit.sh" scripts/agent-audit.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  cp "$repo_root/templates/.agent/harness.yml" .agent/harness.yml
  cat > scripts/check-doc-links.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "forced doc-link failure"
exit 7
EOF
  chmod +x scripts/*.sh
  printf '%s\n' '# Audit Failure Fixture' > README.md
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add .
  git commit -q -m "Add failing audit fixture"
  if bash scripts/agent-audit.sh > audit-failure.log 2>&1; then
    echo "ERROR: expected audit failure"
    exit 1
  fi
  assert_contains audit-failure.log "AGENT_AUDIT_RESULT=fail"
  audit_json="$(find .agent/audits -type f -name "entropy-report.json" | sort | tail -n 1)"
  assert_exists "$audit_json"
  "$(find_python)" - "$audit_json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if data.get("overall_result") != "fail":
    raise SystemExit(f"expected overall_result fail, got {data.get('overall_result')}")
checks = {check["name"]: check for check in data["checks"]}
doc_links_status = checks["doc-links"]["exit_status"]
if doc_links_status == 0:
    raise SystemExit("expected nonzero doc-links exit_status")
PY
)
pass "entropy audit failed check result"
