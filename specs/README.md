# Specs — agent-backbone

> Single source of truth for all specifications. Parsed by `specs-parse.sh`.

---

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1 | A2A Coordination Backbone | 22/23 | 🔄 In Progress | robert.w.seaton.jr@gmail.com |
| v2 | Agent Presence & Discovery | 0/18 | ✏️ Draft | robert.w.seaton.jr@gmail.com |
| v3 | HCI/UX Observability Layer | 0/0 | 💡 Idea | robert.w.seaton.jr@gmail.com |

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

## v2: Agent Presence & Discovery

**Spec**: [spec-v2-agent-presence-and-discovery.md](spec-v2-agent-presence-and-discovery.md)

### Phase 1: Presence Schema & Storage

- [ ] Define presence record schema (YAML frontmatter + prose sections)
- [ ] Define frontmatter fields: id, agent_name, repo, status, joined, updated, ttl_hours, capabilities
- [ ] Define prose sections: Current Task, Architectural Knowledge, Learned
- [ ] Define filename convention: presence-{agent_name}.md (overwrite on re-join)
- [ ] Create agent-backbone/presence/ directory with README.md explaining schema and TTL semantics
- [ ] Write example presence file (presence-example.md) as documentation

### Phase 2: /backbone-join Command

- [ ] Create .claude/commands/backbone-join.md in agent-backbone
- [ ] Implement roster read: render active, stale, and recently-inactive agents on join
- [ ] Implement name inference from working directory + task context
- [ ] Implement developer confirmation/override of inferred name
- [ ] Write presence record to ../agent-backbone/presence/
- [ ] Surface capability matches from active agents relevant to current task

### Phase 3: /backbone-leave Command

- [ ] Create .claude/commands/backbone-leave.md
- [ ] Implement learned section prompt (what was built, decided, open questions)
- [ ] Update status to inactive and write updated timestamp
- [ ] Test leave flow: presence record updated correctly, learned block present

### Phase 4: /backbone-roster Command

- [ ] Create .claude/commands/backbone-roster.md
- [ ] Show active agents (name, repo, task, capabilities, time since join)
- [ ] Show stale agents with staleness warning
- [ ] Show recently inactive agents with learned summary

### Phase 5: Capability Matching

- [ ] Add capabilities list to presence frontmatter
- [ ] Implement capability overlap scan on /backbone-join
- [ ] Surface matching agents as "you may want to consult" hints
- [ ] Document common capability tags in presence/README.md

### Phase 6: Tests & Validation

- [ ] Add tests/test-presence-lifecycle.sh covering write, TTL staleness, leave update, learned block persistence
- [ ] Manual walkthrough with a real dual-repo session (one grostak-v2 + one stak-app agent)

---
