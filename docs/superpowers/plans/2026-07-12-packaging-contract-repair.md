# Packaging Contract Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every direct root `schemas/*.schema.json` file a reliably installed public artifact, with contract tests that prevent the source and fresh-target schema sets from drifting again.

**Architecture:** Keep `schemas/` as the single public inventory. Validate and collect its direct `*.schema.json` children before any installation writes, then pass each sorted path through the existing `copy_path` policy so dry-run, skip, force, and backup semantics remain centralized.

**Tech Stack:** Bash 3.2-compatible shell, portable Unix utilities already used by the repository, existing `tests/harness/*.sh` validation suites

## Global Constraints

- Treat every direct source file matching `schemas/*.schema.json` as a public install artifact; do not recurse into schema subdirectories.
- Preserve the existing installer CLI, completion trailer, template installation, executable-bit handling, `.gitignore` behavior, and `copy_path` dry-run, skip, force, and backup semantics.
- Validate the source schema directory and non-empty public schema set before copying templates or schemas, so a malformed source package fails before making target writes.
- Do not introduce a manifest, a second schema inventory, `jq`, `yq`, GNU-only `find -maxdepth`, or a new runtime dependency.
- Never delete or overwrite a target-only custom schema unless its basename later becomes a source public schema and the caller explicitly uses `--force`.
- Do not change schema contents, README onboarding, finish-run collision behavior, runner error semantics, gate registry policy, or validation-suite orchestration.
- Keep generated `.agent/` state untracked.
- Follow test-driven development: observe the contract tests fail against the current installer before changing installer code.
- Run `bash validate-harness.sh` after each green implementation task and commit each task independently.

## File Structure

- `tests/harness/static-install.sh`: source/fresh-target set equality, dry-run completeness, existing-file behavior, custom-schema preservation, and malformed-package coverage.
- `install-agent-harness.sh`: fail-fast public schema discovery and automatic installation through `copy_path`.
- `docs/stability-contract.md`: public packaging boundary and versioning promises.
- `tests/harness/productization-examples.sh`: executable documentation-contract assertions.
- `docs/superpowers/plans/2026-07-12-packaging-contract-repair.md`: task checklist and observed verification evidence.

---

### Task 1: Define The Public Schema Packaging Contract In Tests

**Files:**
- Modify: `tests/harness/static-install.sh`
- Modify: `docs/superpowers/plans/2026-07-12-packaging-contract-repair.md`

**Interfaces:**
- Consumes: source `schemas/*.schema.json`, installer output, and existing `assert_contains`, `assert_not_contains`, `assert_exists`, and `assert_not_exists` helpers.
- Produces: a derived basename-set comparison and coverage for fresh install, dry-run, reinstall, and malformed source packages.

- [x] **Step 1: Add a direct-root schema inventory helper**

Add this helper immediately after `assert_installer_completion_block` in
`tests/harness/static-install.sh`:

```bash
write_public_schema_basenames() {
  local schema_dir="$1"
  local output_file="$2"

  find "$schema_dir" \
    -type f \
    -name "*.schema.json" \
    ! -path "$schema_dir/*/*" \
    -exec basename {} \; | LC_ALL=C sort >"$output_file"
}

assert_schema_sets_equal() {
  local expected_file="$1"
  local actual_file="$2"

  if ! cmp -s "$expected_file" "$actual_file"; then
    echo "ERROR: installed public schema set does not match source"
    diff -u "$expected_file" "$actual_file" || true
    exit 1
  fi
}
```

The `! -path "$schema_dir/*/*"` condition excludes nested files without the
GNU-only `-maxdepth` option. Basenames are sufficient because the public set is
flat by contract.

- [x] **Step 2: Assert dry-run completeness without writes**

Immediately before invoking the dry-run installer, derive the expected set:

```bash
source_schema_names="$tmp_root/source-schema-names.txt"
write_public_schema_basenames "$repo_root/schemas" "$source_schema_names"
```

Immediately after the existing dry-run completion-block assertion, add:

```bash
while IFS= read -r schema_name; do
  assert_contains "$dry_run_log" \
    "DRY-RUN copy: $repo_root/schemas/$schema_name -> $target_root/schemas/$schema_name"
  assert_not_exists "$target_root/schemas/$schema_name"
done <"$source_schema_names"
```

This loop must cover all source basenames rather than repeat a hand-maintained
list.

Also create a copied source package with
`schemas/internal/private.schema.json`, then assert its dry-run and real
install output omit that nested path and the target does not contain it. This
prevents both source and target inventories from silently excluding a recursive
installer regression.

- [x] **Step 3: Assert exact fresh-install set equality**

After the real installer copy succeeds and before reinstalling into the same
target, add:

```bash
installed_schema_names="$tmp_root/installed-schema-names.txt"
write_public_schema_basenames \
  "$target_root/schemas" \
  "$installed_schema_names"
assert_schema_sets_equal "$source_schema_names" "$installed_schema_names"

schema_count="$(wc -l <"$installed_schema_names" | tr -d ' ')"
if [ "$schema_count" -ne 11 ]; then
  echo "ERROR: expected 11 current public schemas, got $schema_count"
  exit 1
fi
pass "fresh install public schema set matches source"
```

Replace the incomplete installed-target schema entries near the end of the
`required_path` loop with all current eleven names:

```bash
  schemas/acceptance.schema.json \
  schemas/architecture.schema.json \
  schemas/episode.schema.json \
  schemas/evidence-ref.schema.json \
  schemas/failure-attribution.schema.json \
  schemas/handoff.schema.json \
  schemas/harness.schema.json \
  schemas/interventions.schema.json \
  schemas/policy.schema.json \
  schemas/review.schema.json \
  schemas/task.schema.json
```

- [x] **Step 4: Cover skip, force, backup, and target-only preservation**

Add a separate section after the fresh installed-target assertions and before
executing scripts inside `$target_root`:

```bash
echo
echo "== Existing schema install behavior =="
existing_target="$tmp_root/existing schema target"
mkdir -p "$existing_target/schemas"
git init -q "$existing_target"
printf '%s\n' "sentinel policy" \
  >"$existing_target/schemas/policy.schema.json"
printf '%s\n' "target-owned custom schema" \
  >"$existing_target/schemas/custom.schema.json"

existing_skip_log="$tmp_root/existing-schema-skip.log"
bash "$repo_root/install-agent-harness.sh" "$existing_target" \
  >"$existing_skip_log" 2>&1
assert_contains "$existing_skip_log" \
  "SKIP existing: $existing_target/schemas/policy.schema.json"
assert_contains "$existing_target/schemas/policy.schema.json" "sentinel policy"
assert_contains "$existing_target/schemas/custom.schema.json" \
  "target-owned custom schema"

existing_force_log="$tmp_root/existing-schema-force.log"
bash "$repo_root/install-agent-harness.sh" --force --backup "$existing_target" \
  >"$existing_force_log" 2>&1
assert_contains "$existing_force_log" \
  "BACKUP: $existing_target/schemas/policy.schema.json.bak"
cmp -s \
  "$repo_root/schemas/policy.schema.json" \
  "$existing_target/schemas/policy.schema.json" || {
  echo "ERROR: --force did not install the source policy schema"
  exit 1
}
assert_contains "$existing_target/schemas/policy.schema.json.bak" \
  "sentinel policy"
assert_contains "$existing_target/schemas/custom.schema.json" \
  "target-owned custom schema"
pass "existing and target-only schema behavior"
```

- [x] **Step 5: Cover missing and empty schema source packages**

Add this section after the existing-file behavior test:

```bash
echo
echo "== Invalid schema source packages =="
for package_case in missing empty; do
  package_root="$tmp_root/$package_case schema package"
  package_target="$tmp_root/$package_case schema target"
  package_log="$tmp_root/$package_case-schema-package.log"
  mkdir -p "$package_root" "$package_target"
  git init -q "$package_target"
  cp "$repo_root/install-agent-harness.sh" "$package_root/"
  cp -R "$repo_root/templates" "$package_root/"
  if [ "$package_case" = "empty" ]; then
    mkdir -p "$package_root/schemas"
  fi

  if bash "$package_root/install-agent-harness.sh" "$package_target" \
    >"$package_log" 2>&1
  then
    echo "ERROR: installer accepted $package_case public schema source"
    exit 1
  fi
  assert_not_contains "$package_log" "Install complete."
  assert_target_has_no_writes "$package_target"
done

assert_contains "$tmp_root/missing-schema-package.log" \
  "ERROR: schema directory not found:"
assert_contains "$tmp_root/empty-schema-package.log" \
  "ERROR: no public schema files found in:"
pass "invalid schema source packages fail before target writes"
```

`assert_target_has_no_writes` must reject every path under the target except
the pre-existing `.git` directory and its contents. Checking only `AGENTS.md`
does not prove schema validation occurred before template writes.

- [x] **Step 6: Run the red phase and record the failure**

Run:

```bash
bash validate-harness.sh
```

Expected: nonzero. The first new contract failure should report that a current
source schema such as `acceptance.schema.json` is absent from dry-run output or
the installed set. Do not modify `install-agent-harness.sh` until this failure
has been observed and recorded in this plan.

- [x] **Step 7: Commit the red contract tests**

```bash
git add tests/harness/static-install.sh \
  docs/superpowers/plans/2026-07-12-packaging-contract-repair.md
git commit -m "test: define public schema install contract"
```

Record the exact failing command, exit status, and first relevant failure under
Task 1 before committing.

---

### Task 2: Install The Automatically Discovered Public Schema Set

**Files:**
- Modify: `install-agent-harness.sh`
- Modify: `docs/superpowers/plans/2026-07-12-packaging-contract-repair.md`

**Interfaces:**
- Produces: a sorted Bash indexed array named `schema_paths`, validated before installation writes.
- Consumes: the existing `copy_path(source, destination)` function for all schema installation policy.

- [x] **Step 1: Validate and collect public schemas before defining copy behavior**

Immediately after the existing `template_root` validation block in
`install-agent-harness.sh`, add:

```bash
if [ ! -d "$schema_root" ]; then
  echo "ERROR: schema directory not found: $schema_root"
  exit 1
fi

schema_paths=()
while IFS= read -r -d '' schema_path; do
  schema_paths[${#schema_paths[@]}]="$schema_path"
done < <(
  find "$schema_root" \
    -type f \
    -name "*.schema.json" \
    ! -path "$schema_root/*/*" \
    -print0 | LC_ALL=C sort -z
)

if [ "${#schema_paths[@]}" -eq 0 ]; then
  echo "ERROR: no public schema files found in: $schema_root"
  exit 1
fi
```

This validation intentionally occurs before the installer prints its start
message or calls `copy_path`, so missing and empty schema packages cannot leave
a partially installed target.

- [x] **Step 2: Replace all manual schema copy blocks with one loop**

Delete the seven existing basename-specific schema `if` blocks, from
`architecture.schema.json` through `interventions.schema.json`. In the same
location, after the template traversal and before `ensure_runtime_ignores`, add:

```bash
for schema_path in "${schema_paths[@]}"; do
  schema_name="$(basename "$schema_path")"
  copy_path "$schema_path" "$target/schemas/$schema_name"
done
```

Do not add basename-specific exceptions. A future direct root schema must be
installed without changing this loop.

- [x] **Step 3: Verify syntax and the focused static-install contract**

Run:

```bash
bash -n install-agent-harness.sh tests/harness/static-install.sh
bash validate-harness.sh
```

Expected: both commands exit 0. The full validation must include:

- `PASS: installer dry run`;
- `PASS: fresh install public schema set matches source`;
- `PASS: existing and target-only schema behavior`;
- `PASS: invalid schema source packages fail before target writes`.

- [x] **Step 4: Commit the installer repair**

```bash
git add install-agent-harness.sh \
  docs/superpowers/plans/2026-07-12-packaging-contract-repair.md
git commit -m "fix: install complete public schema set"
```

Record the successful commands and exit statuses under Task 2 before
committing.

**Task 2 verification evidence (2026-07-12):**

- `bash -n install-agent-harness.sh tests/harness/static-install.sh` exited 0.
- `bash validate-harness.sh` exited 0; it reported `PASS: installer dry run`,
  `PASS: fresh install public schema set matches source`,
  `PASS: existing and target-only schema behavior`, and
  `PASS: invalid schema source packages fail before target writes`.

---

### Task 3: Publish The Packaging Boundary And Capture Rollout Evidence

**Files:**
- Modify: `docs/stability-contract.md`
- Modify: `tests/harness/productization-examples.sh`
- Modify: `docs/superpowers/plans/2026-07-12-packaging-contract-repair.md`

**Interfaces:**
- Produces: a documented `schemas/*.schema.json` public packaging promise.
- Consumes: the existing stability classifications for each schema's field compatibility.

- [x] **Step 1: Add executable documentation assertions first**

In the `== Stability contract ==` section of
`tests/harness/productization-examples.sh`, add:

```bash
assert_contains "$repo_root/docs/stability-contract.md" "## Public Packaging"
assert_contains "$repo_root/docs/stability-contract.md" \
  'Every direct `schemas/*.schema.json` file is a public install artifact.'
assert_contains "$repo_root/docs/stability-contract.md" \
  "Downstream repositories may rely on those files being present after a fresh install."
assert_contains "$repo_root/docs/stability-contract.md" \
  "A minor version may add a new public schema."
```

Run:

```bash
bash validate-harness.sh
```

Expected: nonzero because `docs/stability-contract.md` does not yet contain the
`Public Packaging` section.

- [x] **Step 2: Document the public packaging boundary**

Insert this section after `## Intended-Stable Interfaces` and before
`## Internal Implementation Details` in `docs/stability-contract.md`:

```markdown
## Public Packaging

Every direct `schemas/*.schema.json` file is a public install artifact.
Downstream repositories may rely on those files being present after a fresh
install. A minor version may add a new public schema.

This packaging promise covers file presence. Compatibility of fields within a
schema remains governed by the Stable, Intended-Stable, Experimental, and
versioning rules in this document. Internal-only schemas must live outside the
root public schema set.
```

Do not add these packaging internals to either README.

- [x] **Step 3: Run canonical repository verification**

Run each command independently and record its exit status:

```bash
git diff --check
bash templates/scripts/check-doc-links.sh .
bash validate-harness.sh
```

Expected: all exit 0, including `DOC_LINKS_RESULT=pass` and the complete harness
validation trailer.

- [x] **Step 4: Capture a real fresh-install schema inventory**

Run:

```bash
rollout_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-harness-packaging.XXXXXX")"
git init -q "$rollout_root"
bash install-agent-harness.sh "$rollout_root"
find "$rollout_root/schemas" \
  -type f \
  -name "*.schema.json" \
  ! -path "$rollout_root/schemas/*/*" \
  -exec basename {} \; | LC_ALL=C sort
rm -rf "$rollout_root"
```

Expected inventory:

```text
acceptance.schema.json
architecture.schema.json
episode.schema.json
evidence-ref.schema.json
failure-attribution.schema.json
handoff.schema.json
harness.schema.json
interventions.schema.json
policy.schema.json
review.schema.json
task.schema.json
```

Record this exact observed inventory under Task 3. The temporary directory may
be removed only after the listing succeeds.

- [x] **Step 5: Review scope and repository status**

Run:

```bash
git diff --stat HEAD~2
git status --short --branch
```

Expected: only the four implementation files and this plan differ across the
cycle; `.agent/` remains untracked and unstaged. Confirm that neither README,
any schema content, nor unrelated runtime code changed.

- [x] **Step 6: Commit documentation and final evidence**

```bash
git add docs/stability-contract.md \
  tests/harness/productization-examples.sh \
  docs/superpowers/plans/2026-07-12-packaging-contract-repair.md
git commit -m "docs: define public schema packaging contract"
```

Before declaring completion, invoke `superpowers:verification-before-completion`
and rerun any verification it requires. Do not amend earlier task commits merely
to update their evidence checkboxes.

## Completion Evidence

Fill this section during implementation; do not mark the plan complete from
expected output alone.

- Red phase command, exit status, and first relevant failure: `bash validate-harness.sh` exited `1`; first relevant failure was `ERROR: expected output to contain: DRY-RUN copy: /Users/arthuryu/Desktop/Agent-Repo-Harness/schemas/acceptance.schema.json -> /var/folders/b5/cv7z2j955pl498ymk8khz0880000gn/T//agent-harness-validate.ggnuN1/install target/schemas/acceptance.schema.json`.
- Task 2 focused/full verification and exit statuses: `bash -n install-agent-harness.sh tests/harness/static-install.sh` exited `0`; `bash validate-harness.sh` exited `0`, including the four Task 2 schema-install pass markers recorded above.
- Documentation red phase and first relevant failure: `bash validate-harness.sh` exited `1`; first relevant failure was `ERROR: expected output to contain: ## Public Packaging` for `docs/stability-contract.md`.
- Final `git diff --check` result: exited `0`.
- Final doc-link result: `bash templates/scripts/check-doc-links.sh .` exited `0` with `DOC_LINKS_RESULT=pass`.
- Final full validation result: `bash validate-harness.sh` exited `0` with the complete harness suite passing, including `PASS: productization examples and stability contract`.
- Fresh-install schema inventory: `acceptance.schema.json`, `architecture.schema.json`, `episode.schema.json`, `evidence-ref.schema.json`, `failure-attribution.schema.json`, `handoff.schema.json`, `harness.schema.json`, `interventions.schema.json`, `policy.schema.json`, `review.schema.json`, `task.schema.json`.
- Scope review: `git diff --stat HEAD~2` exited `0` and listed only `install-agent-harness.sh`, `tests/harness/static-install.sh`, `docs/stability-contract.md`, `tests/harness/productization-examples.sh`, and this plan; `git status --short --branch` exited `0`, with only the Task 3 files modified and `.agent/` untracked. Neither README, schema contents, nor unrelated runtime code changed.
- Final commit hashes: Task 1 `f03a08e`, `ab19300`; Task 2 `7e564e9`; Task 3 initial commit `aadf785`; corrective commit records the assertion-formatting fix.
