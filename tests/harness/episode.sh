#!/usr/bin/env bash
set -euo pipefail

echo
echo "== Episode metadata validation =="
episode_root="$tmp_root/episode"
rm -rf "$episode_root"
mkdir -p "$episode_root/.agent" "$episode_root/scripts/lib"
(
  cd "$episode_root"
  cp "$repo_root/templates/.agent/episode.yml" .agent/episode.yml
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  bash scripts/validate-episode.sh > episode.log 2>&1
  assert_contains episode.log "EPISODE_VALIDATION_RESULT=pass"
)
pass "episode metadata validation"

echo
echo "== Episode metadata source checkout invocation =="
episode_source_log="$tmp_root/episode-source.log"
bash "$repo_root/templates/scripts/validate-episode.sh" \
  "$repo_root/templates/.agent/episode.yml" >"$episode_source_log" 2>&1
assert_contains "$episode_source_log" "EPISODE_VALIDATION_RESULT=pass"
pass "episode metadata source checkout invocation"

echo
echo "== Episode metadata missing required value =="
episode_bad_root="$tmp_root/episode-bad"
rm -rf "$episode_bad_root"
mkdir -p "$episode_bad_root/.agent" "$episode_bad_root/scripts/lib"
(
  cd "$episode_bad_root"
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'episode:' \
    '  id: ""' \
    '  objective: ""' \
    > .agent/episode.yml
  if bash scripts/validate-episode.sh > episode-bad.log 2>&1; then
    echo "ERROR: expected episode validation failure"
    exit 1
  fi
  assert_contains episode-bad.log "episode.id must be non-empty"
  assert_contains episode-bad.log "EPISODE_VALIDATION_RESULT=fail"
)
pass "episode metadata missing required value"

echo
echo "== Episode metadata invalid types =="
episode_type_bad_root="$tmp_root/episode-type-bad"
rm -rf "$episode_type_bad_root"
mkdir -p "$episode_type_bad_root/.agent" "$episode_type_bad_root/scripts/lib"
(
  cd "$episode_type_bad_root"
  cp "$repo_root/templates/scripts/validate-episode.sh" scripts/validate-episode.sh
  cp "$repo_root/templates/scripts/lib/read-yaml.py" scripts/lib/read-yaml.py
  chmod +x scripts/*.sh
  printf '%s\n' \
    'episode:' \
    '  id: 123' \
    '  objective: "Validate type checks."' \
    '  actor:' \
    '    kind: "agent"' \
    '    name: {}' \
    '  status: "planned"' \
    '  context:' \
    '    loaded_files: "AGENTS.md"' \
    > .agent/episode.yml
  if bash scripts/validate-episode.sh > episode-type-bad.log 2>&1; then
    echo "ERROR: expected episode validation type failure"
    exit 1
  fi
  assert_contains episode-type-bad.log "episode.id must be a string"
  assert_contains episode-type-bad.log "episode.actor.name must be a string"
  assert_contains episode-type-bad.log "episode.context.loaded_files must be a list of strings"
  assert_contains episode-type-bad.log "EPISODE_VALIDATION_RESULT=fail"
)
pass "episode metadata invalid types"
