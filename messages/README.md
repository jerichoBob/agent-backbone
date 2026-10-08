# Message Store

This directory is the active message bus for the agent backbone. Messages are written here by `/backbone-send` and claimed by `/backbone-inbox`. Completed messages are moved to `messages/archive/` by `/backbone-done` — they never accumulate here.

---

## File Naming Convention

```text
{type}-{id}-{status}.md
```

- `{type}` — registered type slug: `cr`, `task`, or any type defined in `messages/types/`
- `{id}` — timestamp slug: `YYYYMMDD-HHMMSS` (collision-free, sortable)
- `{status}` — one of: `pending` | `claimed` | `complete`

Status is encoded in the filename so `ls messages/` is immediately informative and renames are atomic.

**Examples:**

```text
cr-20260603-143022-pending.md
cr-20260603-143022-claimed.md
task-20260604-091500-pending.md
task-20260604-091500-claimed.md
```

Completed files live in `messages/archive/` — not here.

---

## Base Frontmatter Schema

All messages carry these fields regardless of type:

```yaml
---
id: YYYYMMDD-HHMMSS
type: cr | task | {registered-type}
status: pending | claimed | complete
routing: direct | topic
from: agent-name          # registered name of the sending agent
to: agent-name            # routing: direct — target agent name, or "any"
topic: topic-name         # routing: topic — topic slug subscribers watch
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Individual types may add extra frontmatter fields — see `messages/types/{type}.md` for each type's full schema.

---

## Message Types

Schemas for all registered types live in `messages/types/`. Adding a new type requires only a schema file there — no command changes needed.

| Type | Schema | Purpose |
|------|--------|---------|
| `cr` | [types/cr.md](types/cr.md) | Change request — ask another agent to make a code/schema change |
| `task` | [types/task.md](types/task.md) | Task assignment — delegate a discrete unit of work |

---

## State Machine

All message types share the same lifecycle:

```text
pending
  └─► claimed      (/backbone-inbox — receiver claims)
        └─► complete  (/backbone-done — receiver closes, file moves to archive/)
```

Each transition: renames the file + updates `status` and `updated` in frontmatter.

---

## Routing Modes

| Mode | Field | Behavior |
|------|-------|---------|
| `direct` | `to: agent-name` | Delivered to the named agent's inbox. Use `to: any` for an unclaimed broadcast. |
| `topic` | `topic: topic-name` | Delivered to all agents subscribed to that topic via `/backbone subscribe`. First claimer wins (competing consumers). |

Run `/backbone status` to see registered agents before publishing. Run `/backbone join` to register this session.

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/backbone-send` | Publish a new message (any type, direct or topic) |
| `/backbone-inbox` | See and claim messages addressed to this agent |
| `/backbone subscribe` | Subscribe to a topic |
| `/backbone unsubscribe` | Remove a topic subscription |
| `/backbone-done` | Fill completion notes, mark complete, archive the file |

---

## Directory Layout Assumption

All repos must be siblings under the same parent:

```
~/Play/github_repos/
  agent-backbone/    ← this repo
  grostak-v2/
  stak-app/
```

Commands use `../agent-backbone/messages/` relative to their repos. The pre-flight check in each command will tell you if the path isn't accessible.

---

## Backward Compatibility

Legacy `cr-*` files from v1 (before the generic bus) used a different frontmatter schema (`source_repo` instead of `from`, no `type` field). `/backbone-inbox` treats any file matching `cr-*-{status}.md` as `type: cr` for display purposes. Over time these can be migrated manually or left as-is — they won't break anything.
