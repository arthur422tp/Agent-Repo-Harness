#!/usr/bin/env python3
"""Read values from dependency-light harness-owned YAML files.

This intentionally supports only the YAML subset used by Agent-Repo-Harness:
maps, lists, scalar values, comments, quoted strings, and simple literal or
folded multiline strings. It is not a general YAML parser.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from pathlib import Path
from typing import Any


class YamlSubsetError(ValueError):
    pass


def strip_comment(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False

    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_double:
            escaped = True
            continue
        if char == "'" and not in_double:
            in_single = not in_single
            continue
        if char == '"' and not in_single:
            in_double = not in_double
            continue
        if char == "#" and not in_single and not in_double:
            if index == 0 or line[index - 1].isspace():
                return line[:index].rstrip()

    return line.rstrip()


def leading_spaces(line: str) -> int:
    if "\t" in line[: len(line) - len(line.lstrip(" \t"))]:
        raise YamlSubsetError("tabs are not supported for indentation")
    return len(line) - len(line.lstrip(" "))


def preprocess(text: str) -> list[tuple[int, str, int]]:
    rows: list[tuple[int, str, int]] = []
    for line_number, raw in enumerate(text.splitlines(), 1):
        stripped = strip_comment(raw)
        if not stripped.strip():
            continue
        rows.append((leading_spaces(stripped), stripped.lstrip(" "), line_number))
    return rows


def parse_scalar(raw: str) -> Any:
    value = raw.strip()
    if value == "":
        return ""
    if value in {"[]", "[ ]"}:
        return []
    if value in {"{}", "{ }"}:
        return {}
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered in {"null", "none", "~"}:
        return None
    if re.fullmatch(r"-?[0-9]+", value):
        return int(value)
    if (
        (value.startswith('"') and value.endswith('"'))
        or (value.startswith("'") and value.endswith("'"))
    ):
        try:
            return ast.literal_eval(value)
        except (SyntaxError, ValueError) as exc:
            raise YamlSubsetError(f"invalid quoted scalar: {value}") from exc
    return value


def split_key_value(text: str, line_number: int) -> tuple[str, str]:
    if ":" not in text:
        raise YamlSubsetError(f"line {line_number}: expected key: value")
    key, value = text.split(":", 1)
    key = key.strip()
    if not key:
        raise YamlSubsetError(f"line {line_number}: empty keys are not supported")
    return key, value.strip()


def collect_multiline(
    rows: list[tuple[int, str, int]], index: int, parent_indent: int, style: str
) -> tuple[str, int]:
    parts: list[str] = []
    while index < len(rows):
        indent, text, _line_number = rows[index]
        if indent <= parent_indent:
            break
        parts.append(text)
        index += 1

    if style.startswith("|"):
        return "\n".join(parts), index
    return " ".join(part.strip() for part in parts), index


def parse_value(
    raw: str, rows: list[tuple[int, str, int]], index: int, parent_indent: int
) -> tuple[Any, int]:
    if raw in {">", ">-", ">+", "|", "|-", "|+"}:
        return collect_multiline(rows, index, parent_indent, raw)
    if raw == "":
        if index >= len(rows) or rows[index][0] <= parent_indent:
            return {}, index
        return parse_block(rows, index, rows[index][0])
    return parse_scalar(raw), index


def parse_list(
    rows: list[tuple[int, str, int]], index: int, indent: int
) -> tuple[list[Any], int]:
    result: list[Any] = []

    while index < len(rows):
        row_indent, text, line_number = rows[index]
        if row_indent < indent:
            break
        if row_indent != indent or not text.startswith("-"):
            break

        rest = text[1:].strip()
        index += 1

        if rest == "":
            if index < len(rows) and rows[index][0] > indent:
                value, index = parse_block(rows, index, rows[index][0])
            else:
                value = None
            result.append(value)
            continue

        if rest in {">", ">-", ">+", "|", "|-", "|+"}:
            value, index = collect_multiline(rows, index, indent, rest)
            result.append(value)
            continue

        if ":" in rest and not rest.startswith(("'", '"')):
            key, raw_value = split_key_value(rest, line_number)
            item: dict[str, Any] = {}
            value, index = parse_value(raw_value, rows, index, indent)
            item[key] = value

            if index < len(rows) and rows[index][0] > indent:
                extra, index = parse_block(rows, index, rows[index][0])
                if not isinstance(extra, dict):
                    raise YamlSubsetError(
                        f"line {line_number}: list item continuation must be a map"
                    )
                item.update(extra)
            result.append(item)
            continue

        value = parse_scalar(rest)
        if isinstance(value, str) and index < len(rows) and rows[index][0] > indent:
            continuation, index = collect_multiline(rows, index, indent, ">")
            value = f"{value} {continuation}".strip()
        result.append(value)

    return result, index


def parse_map(
    rows: list[tuple[int, str, int]], index: int, indent: int
) -> tuple[dict[str, Any], int]:
    result: dict[str, Any] = {}

    while index < len(rows):
        row_indent, text, line_number = rows[index]
        if row_indent < indent:
            break
        if row_indent != indent:
            raise YamlSubsetError(
                f"line {line_number}: unexpected indentation level {row_indent}"
            )
        if text.startswith("-"):
            break

        key, raw_value = split_key_value(text, line_number)
        index += 1
        value, index = parse_value(raw_value, rows, index, indent)
        result[key] = value

    return result, index


def parse_block(
    rows: list[tuple[int, str, int]], index: int, indent: int
) -> tuple[Any, int]:
    if index >= len(rows):
        return {}, index
    row_indent, text, _line_number = rows[index]
    if row_indent != indent:
        raise YamlSubsetError(f"expected indentation level {indent}, got {row_indent}")
    if text.startswith("-"):
        return parse_list(rows, index, indent)
    return parse_map(rows, index, indent)


def load_yaml_subset(path: Path) -> Any:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise YamlSubsetError(str(exc)) from exc

    stripped = text.lstrip()
    if stripped.startswith("{") or stripped.startswith("["):
        try:
            return json.loads(text)
        except json.JSONDecodeError as exc:
            raise YamlSubsetError(f"invalid JSON-compatible config: {exc}") from exc

    rows = preprocess(text)
    if not rows:
        return {}
    data, index = parse_block(rows, 0, rows[0][0])
    if index != len(rows):
        _indent, _text, line_number = rows[index]
        raise YamlSubsetError(f"line {line_number}: unsupported YAML structure")
    return data


def read_path(data: Any, dotted_path: str) -> Any:
    current = data
    if dotted_path == "":
        return current
    for part in dotted_path.split("."):
        if isinstance(current, dict) and part in current:
            current = current[part]
            continue
        raise KeyError(dotted_path)
    return current


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Read values from Agent-Repo-Harness YAML subset files."
    )
    parser.add_argument("file")
    parser.add_argument("path", nargs="?", default="")
    parser.add_argument(
        "--list-fields",
        nargs="+",
        metavar="FIELD",
        help="print selected fields from each list item as tab-separated rows",
    )
    parser.add_argument(
        "--require-key",
        action="append",
        default=[],
        metavar="PATH",
        help="require an additional dotted path to exist",
    )
    parser.add_argument(
        "--optional",
        action="store_true",
        help="exit successfully with no output when the requested path is missing",
    )
    args = parser.parse_args()

    try:
        data = load_yaml_subset(Path(args.file))
        for required_path in args.require_key:
            read_path(data, required_path)
        value = read_path(data, args.path)
    except KeyError as exc:
        path = exc.args[0] if exc.args else args.path
        if args.optional and path == args.path:
            return 0
        print(f"ERROR: missing path: {path}", file=sys.stderr)
        return 1
    except YamlSubsetError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.list_fields:
        if not isinstance(value, list):
            print(f"ERROR: path is not a list: {args.path}", file=sys.stderr)
            return 1
        for item in value:
            if not isinstance(item, dict):
                print("ERROR: list item is not a map", file=sys.stderr)
                return 1
            fields = []
            for field in args.list_fields:
                if field not in item:
                    print(f"ERROR: list item missing field: {field}", file=sys.stderr)
                    return 1
                fields.append("" if item[field] is None else str(item[field]))
            print("\t".join(fields))
        return 0

    if isinstance(value, (dict, list)):
        print(json.dumps(value, indent=2, sort_keys=True))
    elif value is None:
        print("null")
    elif isinstance(value, bool):
        print("true" if value else "false")
    else:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
