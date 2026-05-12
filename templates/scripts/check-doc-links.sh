#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-doc-links.sh [ROOT]

Checks local Markdown links and local scripts/*.sh references under ROOT.
External links, mailto links, pure anchors, docs/plans/*.md future-plan
references, and tests/fixtures/*.md validation fixtures are ignored.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

root="${1:-.}"

if [ ! -d "$root" ]; then
  echo "ERROR: root directory does not exist: $root"
  echo "DOC_LINKS_RESULT=fail"
  exit 1
fi

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "ERROR: python is required for doc link validation"
  echo "DOC_LINKS_RESULT=fail"
  exit 1
fi

"$python_bin" - "$root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
failures = 0

link_re = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
script_re = re.compile(r"(?<![\w./-])(scripts/[A-Za-z0-9._/-]+\.sh)(?![\w./-])")


def is_external(target: str) -> bool:
    lowered = target.lower()
    return (
        "://" in lowered
        or lowered.startswith("mailto:")
        or lowered.startswith("tel:")
        or lowered.startswith("data:")
    )


def exists_with_template_fallback(path: Path, reference: str) -> bool:
    if path.exists():
        return True
    if reference.startswith("scripts/"):
        return (root / "templates" / reference).exists()
    return False


def report(message: str) -> None:
    global failures
    print(f"FAIL: {message}")
    failures += 1


markdown_files = sorted(
    path
    for path in root.rglob("*.md")
    if ".git" not in path.parts
    and ".agent/runs" not in str(path)
    and path.relative_to(root).parts[:2] != ("docs", "plans")
    and path.relative_to(root).parts[:2] != ("tests", "fixtures")
)

for markdown_file in markdown_files:
    try:
        text = markdown_file.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        report(f"could not read Markdown as UTF-8: {markdown_file.relative_to(root)}")
        continue

    for match in link_re.finditer(text):
        target = match.group(1).strip()
        if not target or target.startswith("#") or is_external(target):
            continue
        target = unquote(target.split("#", 1)[0])
        if not target:
            continue
        if target.startswith("/"):
            candidate = root / target.lstrip("/")
        else:
            candidate = markdown_file.parent / target
        resolved_candidate = candidate.resolve()
        try:
            resolved_candidate.relative_to(root)
        except ValueError:
            report(
                "local Markdown link escapes root: "
                f"{markdown_file.relative_to(root)} -> {match.group(1)}"
            )
            continue
        if not exists_with_template_fallback(candidate, target):
            report(
                "missing Markdown link target: "
                f"{markdown_file.relative_to(root)} -> {match.group(1)}"
            )

    for script_ref in script_re.findall(text):
        candidate = root / script_ref
        if not exists_with_template_fallback(candidate, script_ref):
            report(
                "missing script reference: "
                f"{markdown_file.relative_to(root)} -> {script_ref}"
            )

if failures:
    print("DOC_LINKS_RESULT=fail")
    sys.exit(1)

print("DOC_LINKS_RESULT=pass")
PY
