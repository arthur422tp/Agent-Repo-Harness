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
