# Specs — agent-backbone

> Single source of truth for all specifications. Parsed by `specs-parse.sh`.

---

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1 | A2A Coordination Backbone | 22/23 | 🔄 In Progress | robert.w.seaton.jr@gmail.com |
| v2 | Agent Presence & Discovery | 17/18 | 🔄 In Progress | robert.w.seaton.jr@gmail.com |
| v3 | Generic Message Bus | 22/23 | 🔄 In Progress | robert.w.seaton.jr@gmail.com |
| v4 | HCI/UX Observability Layer | 0/0 | 💡 Idea | robert.w.seaton.jr@gmail.com |

---

## Architecture

> Document key architecture decisions and constraints here.

---

## v1: A2A Coordination Backbone

**Spec**: [spec-v1-a2a-coordination-backbone.md](spec-v1-a2a-coordination-backbone.md)

### Phase 1: Message Schema & Storage

- [x] Define the CR markdown file schema (YAML frontmatter + prose sections)
- [x] Define frontmatter fields: id, status, created, updated, source_repo, title, affected_endpoints, affected_tables
- [x] Define prose sections: Problem Statement, Solution Recommendation, Platform Implementation Notes, Mobile Implementation Notes
- [x] Define filename convention: cr-{id}-{status}.md with status lifecycle
- [x] Create agent-backbone/messages/ directory with README.md explaining schema and lifecycle
- [x] Write example CR file (cr-000-example.md) as documentation

### Phase 2: /cr-send Slash Command (stak-app)

- [x] Create .claude/commands/cr-send.md in the stak-app repo
- [x] Implement draft behavior: Claude drafts CR from context, writes to ../agent-backbone/messages/
- [x] Add pre-flight check that ../agent-backbone/messages/ is accessible
- [x] Output human-readable summary of what was written
- [x] Test the command end-to-end from the stak-app directory

### Phase 3: /cr-inbox and /cr-ready Slash Commands (grostak-v2)

- [x] Create .claude/commands/cr-inbox.md in the grostak-v2 repo (shows draft CRs, claim/rename to platform-in-progress)
- [x] Create .claude/commands/cr-ready.md in the grostak-v2 repo (fills Platform Implementation Notes, renames to awaiting-mobile)
- [x] Ensure cr-inbox prompt includes endpoint signatures, request/response shapes, auth changes
- [x] Test cr-inbox claim flow (file rename + frontmatter update)
- [x] Test cr-ready flow (notes written, file renamed to awaiting-mobile)

### Phase 4: /cr-inbox Slash Command (stak-app)

- [x] Create .claude/commands/cr-inbox.md in the stak-app repo (shows awaiting-mobile CRs, displays Platform Implementation Notes)
- [x] Implement claim flow (renames to mobile-in-progress)
- [x] Create .claude/commands/cr-done.md in stak-app (marks complete, writes Mobile Implementation Notes, renames to complete)
- [x] Test full handoff: platform-ready → mobile picks up → done
- [x] Verify complete CR file contains full audit trail (both sides' notes)

### Phase 5: Tests & Validation

- [x] Add tests/test-cr-workflow.sh covering CR lifecycle (create, parse, status transitions, filename/frontmatter consistency)
- [ ] Manual end-to-end walkthrough with a real stak-app ↔ grostak-v2 change as the first live CR

---

## v3: Generic Message Bus

**Spec**: [spec-v3-generic-message-bus.md](spec-v3-generic-message-bus.md)

### Phase 1: Message Type Registry

- [x] Create messages/types/ directory with README.md explaining type schema format
- [x] Migrate CR schema into messages/types/cr.md
- [x] Define messages/types/task.md (task assignment schema)
- [x] Update messages/README.md to describe the generic base frontmatter

### Phase 2: Generic Message Frontmatter

- [x] Define shared base frontmatter (id, type, status, routing, from, to, topic, created, updated)
- [x] Update messages/README.md with generic schema and routing modes
- [x] Document backward compat: cr-* files treated as type: cr

### Phase 3: /backbone-publish Command

- [x] Create .claude/commands/backbone-publish.md
- [x] Implement type selection from messages/types/ registry
- [x] Implement direct routing (--to agent-name)
- [x] Implement topic routing (--topic topic-name)
- [x] Read type schema to drive content prompting
- [x] Write to messages/{type}-{id}-pending.md

### Phase 4: /backbone-inbox Command

- [x] Create .claude/commands/backbone-inbox.md
- [x] Scan messages/ (not archive/) for pending files addressed to this agent (direct + topic subscriptions)
- [x] Group results by type in display
- [x] Implement claim flow (rename to claimed, update status)

### Phase 5: /backbone-subscribe and /backbone-unsubscribe Commands

- [x] Create .claude/commands/backbone-subscribe.md (adds topic to presence record subscriptions list)
- [x] Create .claude/commands/backbone-unsubscribe.md (removes topic from subscriptions)
- [x] Update /backbone-join to display active subscriptions in roster

### Phase 6: /backbone-complete Command

- [x] Create .claude/commands/backbone-complete.md
- [x] Find claimed messages for this session, prompt for completion section per type schema
- [x] Update status: complete, write updated timestamp
- [x] Move file to messages/archive/ (create if needed) — removes from active scan path

### Phase 7: Tests & Validation

- [x] Add tests/test-message-bus.sh covering publish, inbox filtering, topic subscriptions, full lifecycle
- [x] Verify tests/test-cr-workflow.sh still passes (backward compat)
- [ ] Manual walkthrough: publish a task message, subscribe from another agent, claim and complete

---

## v2: Agent Presence & Discovery

**Spec**: [spec-v2-agent-presence-and-discovery.md](spec-v2-agent-presence-and-discovery.md)

### Phase 1: Presence Schema & Storage

- [x] Define presence record schema (YAML frontmatter + prose sections)
- [x] Define frontmatter fields: id, agent_name, repo, status, joined, updated, ttl_hours, capabilities
- [x] Define prose sections: Current Task, Architectural Knowledge, Learned
- [x] Define filename convention: presence-{agent_name}.md (overwrite on re-join)
- [x] Create agent-backbone/presence/ directory with README.md explaining schema and TTL semantics
- [x] Write example presence file (presence-example.md) as documentation

### Phase 2: /backbone-join Command

- [x] Create .claude/commands/backbone-join.md in agent-backbone
- [x] Implement roster read: render active, stale, and recently-inactive agents on join
- [x] Implement name inference from working directory + task context
- [x] Implement developer confirmation/override of inferred name
- [x] Write presence record to ../agent-backbone/presence/
- [x] Surface capability matches from active agents relevant to current task

### Phase 3: /backbone-leave Command

- [x] Create .claude/commands/backbone-leave.md
- [x] Implement learned section prompt (what was built, decided, open questions)
- [x] Update status to inactive and write updated timestamp
- [x] Test leave flow: presence record updated correctly, learned block present

### Phase 4: /backbone-roster Command

- [x] Create .claude/commands/backbone-roster.md
- [x] Show active agents (name, repo, task, capabilities, time since join)
- [x] Show stale agents with staleness warning
- [x] Show recently inactive agents with learned summary

### Phase 5: Capability Matching

- [x] Add capabilities list to presence frontmatter
- [x] Implement capability overlap scan on /backbone-join
- [x] Surface matching agents as "you may want to consult" hints
- [x] Document common capability tags in presence/README.md

### Phase 6: Tests & Validation

- [x] Add tests/test-presence-lifecycle.sh covering write, TTL staleness, leave update, learned block persistence
- [ ] Manual walkthrough with a real dual-repo session (one grostak-v2 + one stak-app agent)

---
