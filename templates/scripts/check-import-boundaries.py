#!/usr/bin/env python3
"""Check that Python files under source paths do not import forbidden modules."""

from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", action="append", required=True)
    parser.add_argument("--forbidden-import", action="append", required=True)
    return parser.parse_args()


def imported_names(path: Path) -> list[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    names: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.append(node.module)
    return names


def is_forbidden(name: str, forbidden: str) -> bool:
    return name == forbidden or name.startswith(f"{forbidden}.")


def main() -> int:
    args = parse_args()
    failures = 0
    forbidden = args.forbidden_import
    for source in args.source:
        root = Path(source)
        if not root.exists():
            print(f"FAIL: source path not found: {source}")
            failures += 1
            continue
        for path in sorted(root.rglob("*.py")):
            try:
                names = imported_names(path)
            except SyntaxError as exc:
                print(f"FAIL: could not parse {path}: {exc}")
                failures += 1
                continue
            for name in names:
                for blocked in forbidden:
                    if is_forbidden(name, blocked):
                        print(f"FAIL: {path} imports forbidden module {blocked}")
                        failures += 1
    if failures:
        print("IMPORT_BOUNDARY_RESULT=fail")
        return 1
    print("IMPORT_BOUNDARY_RESULT=pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
