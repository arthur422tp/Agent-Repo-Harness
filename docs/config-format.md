# Configuration Format

Harness configuration files such as `.agent/task.yml`, `.agent/policy.yml`,
and `.agent/harness.yml` are read by `scripts/lib/read-yaml.py`.

The reader supports the YAML subset used by Agent-Repo-Harness:

- maps
- lists
- scalar strings, integers, booleans, and nulls
- comments
- quoted strings
- simple literal and folded multiline strings

Use spaces for indentation. Tabs are not supported for indentation.

This reader is not a general YAML parser. Keep harness config files simple and
within the subset above so validators and gates read the same values.

## Evidence References YAML Subset

`acceptance.criteria[*].evidence_refs` uses the existing harness YAML subset:
maps, lists, strings, integers, and booleans. It does not require a new parser
or external YAML dependency.

Supported MVP reference types are `command_output`, `gate_result`,
`finish_summary_json`, `changed_files`, and `diff_stat`. Paths must be
repo-relative files and must not point outside the repository or under `.git/`.
