# Git Hook Adapters

These hooks are optional examples for running existing Agent-Repo-Harness gates
from standard Git hook points. They are not installed automatically and they do
not add new gates or change core harness behavior.

## Install

Copy the hook you want into your repository's `.git/hooks/` directory and make
it executable:

```sh
cp adapters/hooks/git/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

```sh
cp adapters/hooks/git/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

Run these commands from the repository root that contains the harness `scripts/`
directory.

## Which Hook To Use

Use `pre-commit` when you want lightweight feedback before a commit is created.
It runs the existing gates below:

```sh
bash scripts/validate-config.sh
bash scripts/validate-task.sh
bash scripts/check-doc-links.sh
bash scripts/check-policy.sh --warn
bash scripts/check-scope.sh --strict
```

If `scripts/check-doc-links.sh` is not present in a harness install, the hook
prints a clear skip message for that command instead of adding a replacement
gate.

Use `pre-push` when you want the full completion gate before refs are pushed. It
runs:

```sh
bash scripts/agent-finish.sh --strict
```

The hook scripts call the existing harness gates directly. They do not install
anything, introduce new gates, or replace manual harness commands.

## Bypass

Use normal Git bypass mechanisms only when necessary:

```sh
git commit --no-verify
git push --no-verify
```

Bypassing skips the local hook invocation for that Git command. It does not
change the harness gates themselves.
