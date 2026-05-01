---
name: subagent-context-packet
description: Create a compact Agent-Repo-Harness context packet for delegated Claude Code work.
---

# Subagent Context Packet

Use this skill before delegating coding or review work.

Include only the context the subagent needs:

- task goal
- relevant `agent.md` facts
- current `handoff.md` state
- `.agent/task.yml` allowed and forbidden paths
- `.agent/policy.yml` high-risk areas
- verification command expected before completion
- exact files or modules owned by the subagent

Tell the subagent not to edit outside its ownership area and not to overwrite
other agents' changes.
