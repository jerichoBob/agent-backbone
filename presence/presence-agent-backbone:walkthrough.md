---
agent_name: agent-backbone:walkthrough
repo: agent-backbone
status: active
joined: 2026-06-06T15:17:05Z
updated: 2026-06-06T15:17:05Z
ttl_hours: 4
capabilities:
  - backbone-development
  - message-bus-testing
  - spec-implementation
subscriptions: []
---

# Current Task

Running a manual walkthrough of the v3 generic message bus. Testing the full publish → inbox → claim → complete lifecycle to validate the backbone works end-to-end before marking the final spec task done.

# Architectural Knowledge

- v3 message bus: type registry in messages/types/, generic state machine (pending → claimed → complete), routing modes (direct to agent-name, topic for pub/sub)
- All backbone commands use ../agent-backbone/ relative paths — works from any sibling repo
- Archive pattern: /backbone-complete moves files to messages/archive/, keeping active scan path clean
- Test coverage: 124/124 passing (cr-workflow 39, message-bus 47, presence-lifecycle 38)
- Subscriptions stored in presence records (no separate store) — /backbone-inbox reads them to filter topic messages

# Learned

<!-- To be filled in by /backbone-leave -->
