---
version: 3
name: generic-message-bus
display_name: "Generic Message Bus"
status: draft
created: 2026-06-03
depends_on: [a2a-coordination-backbone, agent-presence-and-discovery]
tags: [messaging, pub-sub, routing, generalization]
---

# Generic Message Bus

## Why (Problem Statement)

> As a developer building on the agent-backbone, I want a general-purpose typed messaging system so that agents can exchange any kind of structured information — not just change requests — using a consistent publish/subscribe model.

### Context

- The v1 CR workflow hardcodes one message type (change request) with one routing pattern (direct: sender → receiver) and one state machine (draft → in-progress → awaiting-response → complete)
- As the backbone grows, new message types will emerge: task assignments, status updates, capability queries, notifications — each with slightly different schemas and lifecycles
- Adding each new type as its own set of commands (`/task-send`, `/task-inbox`, etc.) recreates the problem v1 solved: proliferating, role-specific, non-composable commands
- The right abstraction is a typed message bus: messages have a `type` (defined by a schema file), a `routing` mode (direct or topic), and a shared state machine — and one set of commands handles all of them
- This is the same problem RabbitMQ solved: separate the *transport* (the bus) from the *schema* (the message type) from the *routing* (exchange type)

---

## What (Requirements)

### User Stories

- **US-1**: As a developer, I want to `/publish` a message of any registered type and have it routed to the right agent(s) without knowing which command to use
- **US-2**: As a Claude agent, I want `/inbox` to show all messages addressed to me regardless of type, so I have one place to check
- **US-3**: As a developer, I want to `/subscribe` to a topic so that any message published to that topic reaches this agent's inbox
- **US-4**: As a developer, I want to register a new message type by adding a schema file to `messages/types/` — no command changes required
- **US-5**: As a developer, I want the existing CR workflow (`/cr-send`, `/cr-inbox`, etc.) to keep working unchanged — v3 is additive, not breaking

### Acceptance Criteria

- AC-1: `/publish --type cr` produces a valid CR message using the existing CR schema — backward compatible with v1
- AC-2: `/publish --type task` produces a task message using the task schema defined in `messages/types/task.md`
- AC-3: `/inbox` shows all pending messages addressed to this agent, grouped by type
- AC-4: `/subscribe topic:patient-api` registers this agent to receive all messages published to the `patient-api` topic (stored in `presence/` as a subscription list)
- AC-5: A message published with `topic: patient-api` is delivered to all agents subscribed to that topic (visible in their `/inbox`)
- AC-6: All messages share the same state machine: `pending → claimed → complete` with the same filename encoding
- AC-7: Adding a new type schema to `messages/types/` makes that type available to `/publish` with no other changes

### Out of Scope

- Guaranteed delivery or exactly-once semantics (filesystem is best-effort)
- Message TTL or automatic expiry
- Multi-hop routing (a message delivered to agent A is not automatically re-routed by A to agent B)
- Breaking changes to v1 CR commands — they remain as convenience wrappers

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`.

### Phase 1: Message Type Registry

- Create `messages/types/` directory with a `README.md` explaining how to define a type schema
- A type schema is a markdown file defining: frontmatter fields, prose sections, routing modes supported, and state machine overrides (if any)
- Migrate the existing CR schema into `messages/types/cr.md` (copy, don't delete v1 schema from `messages/README.md` — keep both during transition)
- Define `messages/types/task.md` — a lightweight task assignment schema: `title`, `description`, `priority`, `due_date`; sections: Task Description, Acceptance Criteria, Completion Notes
- Write `messages/types/README.md` documenting how to add a new type

### Phase 2: Generic Message Frontmatter

- Define the shared base frontmatter all messages carry regardless of type:

  ```yaml
  id: YYYYMMDD-HHMMSS
  type: cr | task | {any-registered-type}
  status: pending | claimed | complete
  routing: direct | topic
  from: agent-name
  to: agent-name      # for routing: direct
  topic: topic-name   # for routing: topic
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  ```

- Update `messages/README.md` to describe the generic schema (type + routing replaces the CR-specific fields)
- Existing CR files remain valid — `type: cr` is implied by the CR-specific fields

### Phase 3: `/publish` Command

- Create `.claude/commands/publish.md`
- Behavior:
  1. Ask (or accept as arg): `--type <type>` — list registered types from `messages/types/`
  2. Ask (or accept): `--to <agent>` for direct routing, or `--topic <topic>` for topic routing
  3. Read the type schema from `messages/types/{type}.md` to know which fields and sections to prompt for
  4. Draft the message content (same pattern as `/cr-send` — read context, fill in sections)
  5. Write to `messages/{type}-{id}-pending.md`
  6. Confirm written path, routing, and type

### Phase 4: `/inbox` Command (generic)

- Create `.claude/commands/inbox.md` (replaces `/cr-inbox` as the primary entry point)
- Behavior:
  1. Require presence record (same as `/cr-inbox` — agent must be registered)
  2. Scan `messages/` for `pending` files where `to` matches this agent OR this agent is subscribed to the message's `topic`
  3. Group results by type
  4. Developer selects a message; agent claims it (rename to `{type}-{id}-claimed.md`, update `status: claimed`)
  5. Display the full message content for the agent to act on
- `/cr-inbox` remains as a thin wrapper: calls `/inbox` filtered to `type: cr`

### Phase 5: `/subscribe` and `/unsubscribe` Commands

- Create `.claude/commands/subscribe.md`
- Behavior: adds a `subscriptions` list to this session's presence record — e.g. `subscriptions: [patient-api, schema-changes]`
- `/inbox` checks subscriptions when scanning for relevant messages
- Create `.claude/commands/unsubscribe.md` — removes a topic from the subscriptions list
- Update `/backbone-join` to show active subscriptions in the roster display

### Phase 6: `/complete` Command (generic done)

- Create `.claude/commands/complete.md` (replaces `/cr-done` as primary entry point)
- Behavior:
  1. Find claimed messages owned by this session
  2. Prompt agent to fill in the completion section (defined per type in the schema)
  3. Rename to `{type}-{id}-complete.md`, update `status: complete`
- `/cr-done` remains as a wrapper for `type: cr`

### Phase 7: Tests & Validation

- Add `tests/test-message-bus.sh` covering: publish a cr-type message, publish a task-type message, inbox filtering by agent name, inbox filtering by topic subscription, full lifecycle for each type
- Verify the existing `tests/test-cr-workflow.sh` still passes (backward compat check)
- Manual walkthrough: publish a `task` message from one agent session, subscribe from another, claim and complete it

---

## Technical Notes

### Design Philosophy

**The bus doesn't know about content — only routing and state.** The type registry (`messages/types/`) is where schemas live. The commands (`/publish`, `/inbox`, `/complete`) are generic drivers that read the schema to know what to prompt for. This means adding a new message type requires zero command changes.

**v1 CR commands are convenience wrappers, not deprecated.** `/cr-send`, `/cr-inbox`, `/cr-done` call through to `/publish --type cr`, `/inbox --type cr`, `/complete` respectively. They stay because they're ergonomic for the most common case.

**Topic routing uses the presence system.** Subscriptions live in the agent's presence record — there's no separate subscription store. When an agent joins with `subscriptions: [patient-api]`, that's how `/inbox` knows to show them topic messages. This keeps the data model flat.

### Architecture Decisions

- **`{type}-{id}-{status}.md` filename**: Extending the v1 convention. `cr-` prefix was the type; now it's explicit. Old `cr-*` files remain valid — the bus reads them as `type: cr`.
- **Type schemas as markdown**: Readable by both Claude and humans. Claude reads the schema at publish time to know what sections to fill in — no code parsing needed.
- **Subscriptions in presence records**: Avoids a separate subscription store. TTL and staleness semantics apply naturally — a stale agent's subscriptions don't receive messages in practice because no one is checking their inbox.
- **`/inbox` requires presence**: Same rationale as `/cr-inbox` — the agent needs a registered name to know which messages are "mine."

### Relationship to v1 and v2

- v1 CR workflow: `/cr-send` → `/publish --type cr`, `/cr-inbox` → `/inbox --type cr`, `/cr-done` → `/complete`. The v1 commands become wrappers.
- v2 presence: `/subscribe` adds to the presence record. `/inbox` reads subscriptions from presence. `/backbone-join` shows subscriptions in the roster.
- Neither v1 nor v2 is broken — v3 is a generalization layer on top.

### Dependencies

- v1 (a2a-coordination-backbone): CR schema migrated to `messages/types/cr.md`
- v2 (agent-presence-and-discovery): subscriptions stored in presence records

### Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| Type schema format is too rigid and slows down new type creation | Keep schema files as loose markdown guides, not strict validators — Claude reads them for hints, not enforcement |
| `/inbox` becomes noisy as message types multiply | Group by type in display; allow `--type` filter; topic subscriptions are opt-in |
| Old `cr-*` filenames break `/inbox` scanning | `/inbox` recognizes `cr-` prefix as `type: cr` for backward compat; document the convention |
| Topic fanout with many subscribers creates duplicate claimed messages | First-write-wins on rename; document that topic messages are claimed by one agent (competitive consumers) |

---

## Open Questions

1. Should topic routing be fanout (every subscriber gets a copy) or competing consumers (first claimer wins)? Competing consumers is simpler and matches the v1 CR pattern — but fanout is more useful for notifications.
2. Should `/publish` support both `--to` and `--topic` on the same message (multicast)? Or one routing mode per message?
3. When a v1 `cr-*` file is encountered by `/inbox`, should it be transparently treated as `type: cr`, or should there be a migration command to rename old files?

---

## Security

Not applicable — same reasoning as v1 and v2. Internal developer tooling, local filesystem, no network endpoints exposed. All access is via Claude Code sessions with OS-level file permissions.

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| 2026-06-03 | Initial draft |
