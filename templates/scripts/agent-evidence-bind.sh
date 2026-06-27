#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agent-evidence-bind.sh [options]

Options:
  --run PATH
  --acceptance PATH
  --criterion ID
  --gate GATE_NAME
  --type TYPE
  --path PATH
  --overall-result pass|fail|warn
  --expected-exit-status N
  --must-contain TEXT
  --must-not-contain TEXT
  --replace
  --append
  --dry-run
  -h, --help

Defaults:
  --acceptance .agent/acceptance.yml
  --type finish_summary_json
  --overall-result pass
  --expected-exit-status from finish-summary.json gate when --run and --gate are provided, otherwise 0
  --append
EOF
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return 0
  fi
  echo "ERROR: python is required for evidence binding" >&2
  exit 1
}

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
run_path=""
acceptance_file=".agent/acceptance.yml"
criterion_id=""
gate_name=""
ref_type="finish_summary_json"
ref_path=""
overall_result="pass"
expected_exit_status=""
mode="append"
dry_run="false"
must_contain_args=()
must_not_contain_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run) run_path="${2:-}"; shift 2 ;;
    --acceptance) acceptance_file="${2:-}"; shift 2 ;;
    --criterion) criterion_id="${2:-}"; shift 2 ;;
    --gate) gate_name="${2:-}"; shift 2 ;;
    --type) ref_type="${2:-}"; shift 2 ;;
    --path) ref_path="${2:-}"; shift 2 ;;
    --overall-result) overall_result="${2:-}"; shift 2 ;;
    --expected-exit-status) expected_exit_status="${2:-}"; shift 2 ;;
    --must-contain) must_contain_args+=("${2:-}"); shift 2 ;;
    --must-not-contain) must_not_contain_args+=("${2:-}"); shift 2 ;;
    --replace) mode="replace"; shift ;;
    --append) mode="append"; shift ;;
    --dry-run) dry_run="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unsupported option: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$criterion_id" ]; then
  echo "FAIL: --criterion is required"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ ! -f "$acceptance_file" ]; then
  echo "FAIL: acceptance file not found: $acceptance_file"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ -n "$run_path" ]; then
  if [ ! -d "$run_path" ]; then
    echo "FAIL: run directory not found: $run_path"
    echo "AGENT_EVIDENCE_BIND_RESULT=fail"
    exit 1
  fi
  if [ -z "$ref_path" ]; then
    ref_path="$run_path/finish-summary.json"
  fi
fi
if [ -z "$ref_path" ]; then
  echo "FAIL: --path or --run is required"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi
if [ ! -f "$ref_path" ]; then
  echo "FAIL: evidence path not found: $ref_path"
  echo "AGENT_EVIDENCE_BIND_RESULT=fail"
  exit 1
fi

python_bin="$(find_python)"
tmp_file="${acceptance_file}.tmp.$$"
python_args=(
  "$acceptance_file"
  "$tmp_file"
  "$criterion_id"
  "$gate_name"
  "$ref_type"
  "$ref_path"
  "$overall_result"
  "$expected_exit_status"
  "$mode"
  "$dry_run"
)
if [ "${#must_contain_args[@]}" -gt 0 ]; then
  python_args+=("${must_contain_args[@]}")
fi
python_args+=("--")
if [ "${#must_not_contain_args[@]}" -gt 0 ]; then
  python_args+=("${must_not_contain_args[@]}")
fi

set +e
"$python_bin" - "${python_args[@]}" <<'PY'
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

acceptance_path = Path(sys.argv[1])
tmp_path = Path(sys.argv[2])
criterion_id = sys.argv[3]
gate_name = sys.argv[4]
ref_type = sys.argv[5]
ref_path = sys.argv[6]
overall_result = sys.argv[7]
expected_exit_status_arg = sys.argv[8]
mode = sys.argv[9]
dry_run = sys.argv[10] == "true"
rest = sys.argv[11:]
separator = rest.index("--")
must_contain = rest[:separator]
must_not_contain = rest[separator + 1 :]


def fail(message):
    print(f"FAIL: {message}")
    print("AGENT_EVIDENCE_BIND_RESULT=fail")
    sys.exit(1)


def parse_scalar(value):
    value = value.strip()
    if value == "true":
        return True
    if value == "false":
        return False
    if value == "null":
        return None
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def leading_spaces(line):
    return len(line) - len(line.lstrip(" "))


def criterion_id_from_block(block):
    if not block:
        return None
    first = block[0].strip()
    if first.startswith("- "):
        key, _, value = first[2:].partition(":")
        if key.strip() == "id":
            return parse_scalar(value)
    for raw in block[1:]:
        if raw.startswith("      id:"):
            _, _, value = raw.strip().partition(":")
            return parse_scalar(value)
        if raw.startswith("    - "):
            return None
    return None


def find_criterion_block(lines, target_id):
    for index, raw in enumerate(lines):
        if not raw.startswith("    - "):
            continue
        end = index + 1
        while end < len(lines) and not lines[end].startswith("    - "):
            end += 1
        if criterion_id_from_block(lines[index:end]) == target_id:
            return index, end
    return None, None


def parse_refs(block):
    refs = []
    in_refs = False
    current_ref = None
    current_list_key = None
    for raw in block:
        if raw.startswith("      evidence_refs:"):
            in_refs = True
            current_ref = None
            current_list_key = None
            continue
        if not in_refs:
            continue
        if leading_spaces(raw) <= 6 and raw.strip():
            break
        stripped = raw.strip()
        if raw.startswith("        - "):
            current_ref = {}
            refs.append(current_ref)
            current_list_key = None
            key, _, value = stripped[2:].partition(":")
            current_ref[key.strip()] = parse_scalar(value)
            continue
        if raw.startswith("          ") and current_ref is not None:
            key, sep, value = stripped.partition(":")
            if sep and value.strip() == "":
                current_ref[key.strip()] = []
                current_list_key = key.strip()
                continue
            if sep:
                current_ref[key.strip()] = parse_scalar(value)
                current_list_key = None
                continue
        if raw.startswith("            - ") and current_ref is not None and current_list_key:
            current_ref[current_list_key].append(parse_scalar(stripped[2:]))
    return refs


def find_refs_range(block):
    for index, raw in enumerate(block):
        if raw.startswith("      evidence_refs:"):
            end = index + 1
            while end < len(block):
                if block[end].startswith("    - "):
                    break
                if leading_spaces(block[end]) <= 6 and block[end].strip():
                    break
                end += 1
            return index, end
    return None, None


lines = acceptance_path.read_text(encoding="utf-8").splitlines()
criterion_start, criterion_end = find_criterion_block(lines, criterion_id)
if criterion_start is None:
    fail(f"criterion not found: {criterion_id}")
criterion_block = lines[criterion_start:criterion_end]

expected_exit_status = 0 if expected_exit_status_arg == "" else int(expected_exit_status_arg)
if gate_name and ref_type == "finish_summary_json":
    try:
        summary = json.loads(Path(ref_path).read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"could not parse finish summary: {exc}")
    gates = summary.get("gates", {})
    gate = None
    if isinstance(gates, list):
        gate = next((item for item in gates if isinstance(item, dict) and item.get("name") == gate_name), None)
    elif isinstance(gates, dict):
        candidate = gates.get(gate_name)
        if isinstance(candidate, dict):
            gate = candidate
    if not isinstance(gate, dict):
        fail(f"gate not found: {gate_name}")
    expected_exit_status = int(gate.get("exit_status", expected_exit_status))

new_ref = {
    "type": ref_type,
    "path": ref_path,
}
if gate_name:
    new_ref["gate"] = gate_name
new_ref["overall_result"] = overall_result
new_ref["expected_exit_status"] = expected_exit_status
if must_contain:
    new_ref["must_contain"] = must_contain
if must_not_contain:
    new_ref["must_not_contain"] = must_not_contain

existing_refs = parse_refs(criterion_block)
if mode == "replace":
    refs = [new_ref]
else:
    refs = list(existing_refs)
    if new_ref not in refs:
        refs.append(new_ref)


def quote(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if value is None:
        return "null"
    text = str(value)
    if text == "" or text.startswith("{") or text.startswith("[") or ": " in text:
        return json.dumps(text)
    return text


def render_refs(refs):
    out = ["      evidence_refs:"]
    for ref in refs:
        out.append(f"        - type: {quote(ref['type'])}")
        for key in ["path", "gate", "overall_result", "expected_exit_status"]:
            if key in ref:
                out.append(f"          {key}: {quote(ref[key])}")
        for key in ["must_contain", "must_not_contain"]:
            values = ref.get(key)
            if values:
                out.append(f"          {key}:")
                for value in values:
                    out.append(f"            - {quote(value)}")
    return out


refs_start, refs_end = find_refs_range(criterion_block)
new_ref_lines = render_refs(refs)
if refs_start is None:
    updated_block = criterion_block + new_ref_lines
else:
    updated_block = criterion_block[:refs_start] + new_ref_lines + criterion_block[refs_end:]

rendered_lines = lines[:criterion_start] + updated_block + lines[criterion_end:]
rendered = "\n".join(rendered_lines) + "\n"
if dry_run:
    print(rendered, end="")
else:
    tmp_path.write_text(rendered, encoding="utf-8")
PY
status=$?
set -e

if [ "$status" -ne 0 ]; then
  rm -f "$tmp_file"
  exit "$status"
fi

if [ "$dry_run" = "false" ]; then
  if [ -f "$script_dir/check-evidence-refs.py" ]; then
    if ! "$python_bin" "$script_dir/check-evidence-refs.py" "$tmp_file"; then
      rm -f "$tmp_file"
      echo "AGENT_EVIDENCE_BIND_RESULT=fail"
      exit 1
    fi
  fi
  mv "$tmp_file" "$acceptance_file"
  echo "AGENT_EVIDENCE_BIND_RESULT=pass"
else
  rm -f "$tmp_file"
  echo "AGENT_EVIDENCE_BIND_RESULT=pass"
fi
