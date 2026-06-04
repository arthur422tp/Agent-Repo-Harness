#!/usr/bin/env bash
set -euo pipefail

episode_file="${1:-.agent/episode.yml}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
reader="$script_dir/lib/read-yaml.py"
failures=0

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_python() {
  if have_cmd python3; then
    printf '%s\n' "python3"
    return 0
  fi
  if have_cmd python; then
    printf '%s\n' "python"
    return 0
  fi
  return 1
}

if [ ! -f "$episode_file" ]; then
  echo "Episode metadata is optional and not present."
  echo "EPISODE_VALIDATION_RESULT=pass"
  exit 0
fi

if ! python_bin="$(find_python)"; then
  echo "ERROR: python is required for episode validation"
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

if [ ! -f "$reader" ]; then
  echo "ERROR: YAML reader not found: $reader"
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

echo "== Episode Metadata Validation =="
echo "Episode file: $episode_file"

EPISODE_FILE="$episode_file" \
YAML_READER="$reader" \
"$python_bin" - <<'PY' || failures=$((failures + 1))
import importlib.util
import os
from pathlib import Path

reader_path = Path(os.environ["YAML_READER"])
episode_path = Path(os.environ["EPISODE_FILE"])

spec = importlib.util.spec_from_file_location("harness_yaml_reader", reader_path)
if spec is None or spec.loader is None:
    raise SystemExit(f"ERROR: could not load YAML reader: {reader_path}")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

try:
    data = module.load_yaml_subset(episode_path)
except Exception as exc:
    print(f"ERROR: {exc}")
    raise SystemExit(1)

failures = 0


def fail(message):
    global failures
    print(f"ERROR: {message}")
    failures += 1


def require_map(value, label):
    if not isinstance(value, dict):
        fail(f"{label} must be a map")
        return None
    return value


def require_non_empty_string(container, key, label):
    if not isinstance(container, dict) or key not in container:
        fail(f"{label} must be non-empty")
        return ""
    value = container[key]
    if not isinstance(value, str):
        fail(f"{label} must be a string")
        return ""
    if value == "":
        fail(f"{label} must be non-empty")
        return ""
    print(f"OK: {label}")
    return value


episode = require_map(data.get("episode") if isinstance(data, dict) else None, "episode")
if episode is None:
    raise SystemExit(1)

require_non_empty_string(episode, "id", "episode.id")
require_non_empty_string(episode, "objective", "episode.objective")
actor = require_map(episode.get("actor"), "episode.actor")
if actor is None:
    actor = {}
actor_kind = require_non_empty_string(actor, "kind", "episode.actor.kind")
require_non_empty_string(actor, "name", "episode.actor.name")
status = require_non_empty_string(episode, "status", "episode.status")

if status in {"planned", "in_progress", "blocked", "ready_for_finish", "finished"}:
    print("OK: episode.status is valid")
else:
    fail("episode.status must be planned, in_progress, blocked, ready_for_finish, or finished")

if actor_kind in {"agent", "human", "hybrid"}:
    print("OK: episode.actor.kind is valid")
else:
    fail("episode.actor.kind must be agent, human, or hybrid")

context = episode.get("context")
if context is not None:
    if not isinstance(context, dict):
        fail("episode.context must be a map")
    else:
        for key in ("loaded_files", "external_sources"):
            value = context.get(key)
            if value is None:
                continue
            if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
                fail(f"episode.context.{key} must be a list of strings")

raise SystemExit(1 if failures else 0)
PY

if [ "$failures" -gt 0 ]; then
  echo "EPISODE_VALIDATION_RESULT=fail"
  exit 1
fi

echo "EPISODE_VALIDATION_RESULT=pass"
