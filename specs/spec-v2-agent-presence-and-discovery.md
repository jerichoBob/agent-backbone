---
version: 1
name: agent-presence-and-discovery
display_name: "Agent Presence & Discovery"
status: in-progress
created: 2026-06-03
depends_on: [a2a-coordination-backbone]
tags: [cross-repo, agents, coordination, discovery, presence]
---

# Agent Presence & Discovery

## Why (Problem Statement)

> As a Claude agent joining the backbone, I want to see which other agents are currently active and what they know so that I can treat them as peers or skills rather than starting from scratch.

### Context

The v1 CR workflow treats the backbone as a static message store — a file is written, a tab is switched, a file is read. This works for sequential handoffs but misses a bigger opportunity: if multiple agents are active simultaneously (or have recently been active), they carry context that is directly useful to each other.

- A stak-app agent mid-way through a patient flow refactor already knows which hooks map to which API endpoints — that's architectural knowledge useful to a grostak-v2 agent that just joined
- A grostak-v2 agent that just shipped a migration knows the exact schema delta — the stak-app agent shouldn't have to re-derive it from git
- As more agents join the backbone over time (new repos, new task specializations), the network effect compounds: every new agent both contributes context and can consume context from all prior sessions

Currently there is no presence mechanism — agents are invisible to each other. This spec adds a lightweight registration and discovery layer so agents can see the network and self-organize around what each one knows.

---

## What (Requirements)

### User Stories

- **US-1**: As a Claude agent starting a session, I want to register my presence (name, repo, current task, capabilities) so other agents can find me
- **US-2**: As a Claude agent, I want to run `/backbone-join` to see who else is active and decide whether to collaborate or work independently
- **US-3**: As a developer, I want to see the live roster of active agents in one command so I can understand the current state of coordinated work
- **US-4**: As a Claude agent, I want to treat another agent's presence record as a skill manifest — knowing what that agent has already analyzed lets me query it rather than re-derive the same context
- **US-5**: As a Claude agent ending a session, I want to mark myself inactive and leave a summary of what I learned so future agents can benefit from it

### Acceptance Criteria

- AC-1: An agent joining the backbone writes a presence record to `agent-backbone/presence/` within the first exchange of a session
- AC-2: The presence record includes: agent name (inferred + developer-overridable), repo, current task description, declared capabilities, and a timestamp
- AC-3: `/backbone-join` reads all active presence records and renders a human-readable roster before the session begins
- AC-4: Presence records older than a configurable TTL (default: 4 hours) are considered stale and shown separately from active agents
- AC-5: On session end (via `/backbone-leave`), the agent updates its record to `status: inactive` and writes a `learned` summary block
- AC-6: A new agent can read the `learned` blocks of recent inactive agents to bootstrap context without a live session
- AC-7: `/backbone-roster` works from any repo and shows all agents (active, stale, recently inactive) with their task and capability summaries

### Out of Scope

- Real-time push notifications between agents (presence is polled on join, not pushed)
- Automated agent-to-agent API calls (agents read each other's context; humans still drive implementation)
- Presence records as authoritative state (CR files from v1 remain the authoritative source for change requests)
- Authentication or tamper-proofing of presence records

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`.

### Phase 1: Presence Schema & Storage

- Define the presence record schema (YAML frontmatter + prose sections)
- Frontmatter fields: `id`, `agent_name`, `repo`, `status` (active | stale | inactive), `joined`, `updated`, `ttl_hours`, `capabilities`
- Prose sections: **Current Task** (what the agent is working on right now), **Architectural Knowledge** (what this agent knows about the system that other agents would find useful), **Learned** (filled in on `/backbone-leave` — discoveries, decisions made, questions answered)
- Filename: `presence-{agent_name}.md` — one file per named agent, overwritten on re-join (not appended)
- Create `agent-backbone/presence/` directory with a `README.md` explaining the schema and TTL semantics
- Write an example presence file (`presence-example.md`) as documentation

### Phase 2: `/backbone-join` Command

- Create `.claude/commands/backbone-join.md` in `agent-backbone` (symlinked or copied to each sibling repo's `.claude/commands/`)
- Command behavior:
  1. Read `../agent-backbone/presence/` and render the current roster (active agents, stale agents, recently inactive with learned summaries)
  2. Infer a candidate name from the working directory + current task context (e.g. `grostak-api:patient-schema`, `stak-app:refill-flow`)
  3. Present the inferred name to the developer for confirmation or override
  4. Write the presence record to `../agent-backbone/presence/presence-{name}.md`
  5. If any active agent has capabilities relevant to the current task, surface them as a "you may want to consult" note
- The roster display distinguishes: **active** (within TTL), **stale** (past TTL, not explicitly left), **recently left** (inactive, `learned` block present)

### Phase 3: `/backbone-leave` Command

- Create `.claude/commands/backbone-leave.md`
- Command behavior:
  1. Find this session's presence record
  2. Prompt Claude to write a `Learned` section: what was built, what was decided, any schema/API changes made, open questions left behind
  3. Update `status: inactive`, write `updated` timestamp
  4. Print a confirmation so the developer knows the handoff summary is persisted

### Phase 4: `/backbone-roster` Command

- Create `.claude/commands/backbone-roster.md`
- Shows all presence records with a structured summary:
  - Active agents: name, repo, task, capabilities, time since join
  - Stale agents: same fields + staleness warning
  - Recently inactive: name, repo, brief learned summary, time since left
- Useful for a developer context-switching to a new repo who wants the full network picture before starting

### Phase 5: Capability Matching

- Add a `capabilities` list to the presence frontmatter (free-form tags: `schema-analysis`, `patient-api`, `auth-flow`, `mobile-hooks`, etc.)
- On `/backbone-join`, after writing the new agent's record, scan other active agents for capability overlap with the current task
- Surface matches as: "Agent `grostak-api:patient-schema` (active 23m ago) knows about `patient-api` — their architectural knowledge section may save you time"
- No automated querying — the developer decides whether to read that agent's presence file

### Phase 6: Tests & Validation

- Add `tests/test-presence-lifecycle.sh` to `agent-backbone`: write a presence record, verify schema, simulate TTL staleness, simulate `/backbone-leave` update, verify learned block persists
- Manual walkthrough: use a real dual-repo session (one grostak-v2 agent + one stak-app agent) as the first live test of the full presence lifecycle

---

## Technical Notes

### Design Philosophy

**Behavior implies role — don't annotate what's already structurally evident.** grostak-v2 and stak-app exchange CRs as equals; neither issues directives to the other, both have full standing in the backbone. That *is* peer behavior. Adding a `role: peer` field would just be naming something the protocol already expresses. If orchestration is ever needed on this backbone, it won't fit the CR pattern — and that friction is the signal, not a field value.

### Architecture Decisions

- **One file per named agent, overwritten on re-join**: Avoids accumulation of stale presence cruft. Historical context lives in the `learned` blocks of inactive records plus the CR files from v1.
- **TTL in frontmatter, not enforced by a daemon**: No background process. Freshness is computed by the reading agent (`updated` timestamp vs. TTL). Simple, no infra.
- **Capabilities as free-form tags, not a formal registry**: The value is in approximate matching — if two agents both tag `patient-api`, that's enough signal. Don't over-engineer a schema.
- **`/backbone-join` is the entry point, not an automatic hook**: Agents join explicitly. This keeps the developer in the loop and avoids ghost registrations from abandoned sessions.
- **Agent name format `{repo-short}:{task-slug}`**: Readable in roster output, unique enough for single-developer use, naturally groups agents by repo.

### Relationship to v1 (CR Workflow)

Presence is a **layer above** the CR message store, not a replacement:

- CR files are the authoritative record of what needs to change and what did change
- Presence records are ephemeral context about who is working and what they know right now
- A future enhancement: `/cr-send` could auto-address a CR to a specific active agent by name rather than leaving it for whoever picks it up next

### Dependencies

- Depends on the v1 message schema (same sibling-directory assumption: `../agent-backbone/` from any project repo)
- No new packages or services

### Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| Developer forgets to run `/backbone-leave` | Stale TTL makes old records visually distinct; no functional harm if a record is abandoned |
| Agent name collisions (two sessions claim same name) | Last-write-wins on the file; for solo dev this is acceptable. Show a warning if the existing record has a different `joined` time |
| Presence files grow large as `learned` blocks accumulate context | `learned` block should be a concise summary (5–10 bullets max), not a transcript. Slash command prompt should enforce this |
| Capabilities tags diverge across sessions and lose matching value | Add a `presence/README.md` section listing common capability tags to reuse; still free-form but with examples |

---

## Open Questions

1. Should `/backbone-join` offer to read a relevant inactive agent's `learned` block directly into context, or just point to the file path?
2. Is there value in a `blocking_on` field in the presence record — so an active agent can signal "I am waiting for the platform side to complete X" and the incoming grostak-v2 agent immediately sees it as a priority?
3. Should the `capabilities` list be agent-declared (what I know) or task-declared (what I am doing)? Both are useful for different matching purposes.
4. **HCI/UX observability (future spec)**: As the backbone grows, humans need a way to see what's happening between agents in real time — not just the file artifacts, but the conversation flow. What does that surface look like in Claude Code or a Pi agent context? A live feed of presence transitions? A visual graph of who's talking to whom and about what? This is a distinct spec when the time comes — the backbone is the substrate, the HCI layer is what makes it legible to the humans supervising it.

---

## Security

Not applicable — same reasoning as v1. Internal developer tooling, local filesystem, no network endpoints.

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| 2026-06-03 | Initial draft |
