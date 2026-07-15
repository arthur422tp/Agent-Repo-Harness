# Versioning And Upgrades

`VERSION` is the stable version represented by the current source package.
`CHANGELOG.md` records user-visible changes between released versions.

Development branches may contain entries under `Unreleased` without carrying
a release tag. A strict release-tag check requires `vMAJOR.MINOR.PATCH` to
match `VERSION`, point at HEAD, and have no remaining release entries under
`Unreleased`.

Run local release readiness against an explicit prior stable release:

```bash
bash ci/release-readiness.sh --from-tag v0.1.1
```

Installed repositories should review `CHANGELOG.md`, commit their current
harness baseline, preview the update, and then use the public installer:

```bash
bash install-agent-harness.sh --dry-run /path/to/target-repo
bash install-agent-harness.sh --force --backup /path/to/target-repo
```

The default installer preserves existing files. `--force --backup` replaces
harness-managed paths while retaining their previous contents as `.bak` files.
Target-owned files are not deleted. Review the resulting diff and rerun the
installed preflight, verification, and finish commands before committing the
upgrade.

Releases in the `v0.x` series may still change templates and workflow
conventions as the harness matures. Backward compatibility is best-effort before v1.0.
The detailed compatibility policy follows `docs/stability-contract.md`.
