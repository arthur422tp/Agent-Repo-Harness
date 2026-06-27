#!/usr/bin/env python3
"""Validate Agent-Repo-Harness acceptance evidence references."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

SUPPORTED_TYPES = {
    "command_output",
    "gate_result",
    "finish_summary_json",
    "changed_files",
    "diff_stat",
}


def load_yaml_reader(script_path: Path):
    reader_path = script_path.parent / "lib" / "read-yaml.py"
    if not reader_path.is_file():
        raise RuntimeError(f"YAML reader not found: {reader_path}")
    spec = importlib.util.spec_from_file_location("harness_read_yaml", reader_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def fail(failures: list[str], message: str) -> None:
    print(f"FAIL: {message}")
    failures.append(message)


def ensure_string_list(value: Any, label: str, failures: list[str]) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        fail(failures, f"{label} must be a list of strings")
        return []
    return value


def resolve_ref_path(repo_root: Path, raw_path: Any, label: str, failures: list[str]) -> Path | None:
    if not isinstance(raw_path, str) or raw_path.strip() == "":
        fail(failures, f"evidence ref {label} path must be non-empty")
        return None

    candidate = Path(raw_path)
    if candidate.is_absolute():
        fail(failures, f"evidence ref {label} path must be repo-relative: {raw_path}")
        return None
    if any(part == ".." for part in candidate.parts):
        fail(failures, f"evidence ref {label} path must not contain path traversal: {raw_path}")
        return None
    if candidate.parts and candidate.parts[0] == ".git":
        fail(failures, f"evidence ref {label} path must not point under .git: {raw_path}")
        return None

    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError:
        fail(failures, f"evidence ref {label} path escapes repo root: {raw_path}")
        return None

    if not resolved.exists():
        fail(failures, f"evidence ref {label} path does not exist: {raw_path}")
        return None
    if resolved.is_dir():
        fail(failures, f"evidence ref {label} path must be a file: {raw_path}")
        return None

    print(f"OK: evidence ref {label} path exists")
    return resolved


def validate_text_content(ref: dict[str, Any], path: Path, ref_type: str, failures: list[str]) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    for needle in ensure_string_list(ref.get("must_contain"), "must_contain", failures):
        if needle not in text:
            fail(failures, f"{ref_type} missing required content: {needle}")
        else:
            print(f"OK: {ref_type} contains {needle}")
    for needle in ensure_string_list(ref.get("must_not_contain"), "must_not_contain", failures):
        if needle in text:
            fail(failures, f"{ref_type} contains forbidden content: {needle}")
        else:
            print(f"OK: {ref_type} does not contain {needle}")


def validate_finish_summary(ref: dict[str, Any], path: Path, failures: list[str]) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except json.JSONDecodeError as exc:
        fail(failures, f"finish_summary_json is malformed JSON: {exc}")
        return

    expected_result = ref.get("overall_result")
    if expected_result is not None:
        actual_result = data.get("overall_result") if isinstance(data, dict) else None
        if actual_result != expected_result:
            fail(failures, f"finish_summary_json overall_result expected {expected_result} got {actual_result}")
        else:
            print(f"OK: finish_summary_json overall_result is {expected_result}")

    gate = ref.get("gate")
    expected_exit_status = ref.get("expected_exit_status")
    if gate is None and expected_exit_status is None:
        return
    if not isinstance(gate, str) or gate.strip() == "":
        fail(failures, "finish_summary_json gate must be non-empty when expected_exit_status is set")
        return
    if not isinstance(expected_exit_status, int):
        fail(failures, f"finish_summary_json expected_exit_status for gate {gate} must be an integer")
        return

    gates = data.get("gates") if isinstance(data, dict) else None
    if not isinstance(gates, list):
        fail(failures, "finish_summary_json gates must be a list")
        return

    for entry in gates:
        if isinstance(entry, dict) and entry.get("name") == gate:
            actual_status = entry.get("exit_status")
            if actual_status != expected_exit_status:
                fail(failures, f"finish_summary_json gate {gate} exit_status expected {expected_exit_status} got {actual_status}")
            else:
                print(f"OK: gate {gate} exit_status is {expected_exit_status}")
            return

    fail(failures, f"finish_summary_json gate {gate} is missing")


def iter_refs(data: Any):
    acceptance = data.get("acceptance") if isinstance(data, dict) else None
    criteria = acceptance.get("criteria") if isinstance(acceptance, dict) else None
    if not isinstance(criteria, list):
        return
    for criterion_index, criterion in enumerate(criteria, 1):
        if not isinstance(criterion, dict):
            continue
        refs = criterion.get("evidence_refs")
        if not isinstance(refs, list):
            continue
        for ref_index, ref in enumerate(refs, 1):
            yield f"acceptance.criteria[{criterion_index}].evidence_refs[{ref_index}]", ref


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate acceptance evidence_refs.")
    parser.add_argument("acceptance_file", nargs="?", default=".agent/acceptance.yml")
    args = parser.parse_args()

    sys.dont_write_bytecode = True
    script_path = Path(__file__).resolve()
    acceptance_path = Path(args.acceptance_file)
    repo_root = Path.cwd().resolve()
    failures: list[str] = []

    print("== Evidence Refs Gate ==")
    print(f"File: {acceptance_path}")

    try:
        reader = load_yaml_reader(script_path)
        data = reader.load_yaml_subset(acceptance_path)
    except Exception as exc:
        print(f"FAIL: could not parse {acceptance_path}: {exc}")
        print("EVIDENCE_REFS_RESULT=fail")
        return 1

    found = False
    for label, ref in iter_refs(data):
        found = True
        if not isinstance(ref, dict):
            fail(failures, f"evidence ref {label} must be a map")
            continue
        ref_type = ref.get("type")
        if ref_type not in SUPPORTED_TYPES:
            fail(failures, f"evidence ref {label} type is unsupported: {ref_type}")
            continue
        path = resolve_ref_path(repo_root, ref.get("path"), label, failures)
        if path is None:
            continue
        if ref_type == "finish_summary_json":
            validate_finish_summary(ref, path, failures)
        validate_text_content(ref, path, ref_type, failures)

    if not found:
        fail(failures, "no evidence_refs entries found")

    if failures:
        print("EVIDENCE_REFS_RESULT=fail")
        return 1

    print("EVIDENCE_REFS_RESULT=pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
