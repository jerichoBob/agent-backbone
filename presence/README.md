# Agent Presence Store

This directory holds presence records for all agents currently registered on the backbone. Each record describes who an agent is, what it's working on, what it knows, and what it learned before leaving.

---

## File Naming Convention

```text
presence-{agent_name}.md
```

One file per named agent. **Overwritten on re-join** — no accumulation of old records. Historical context lives in the `Learned` section of inactive records and in the `messages/` CR audit trail.

**Agent name format:** `{repo-short}:{task-slug}`

Examples:

```text
presence-grostak-api:patient-schema.md
presence-stak-app:refill-flow.md
presence-agent-backbone:maintainer.md
```

---

## Frontmatter Schema

```yaml
---
agent_name: repo-short:task-slug
repo: full repo directory name
status: active | stale | inactive
joined: YYYY-MM-DDTHH:MM:SS
updated: YYYY-MM-DDTHH:MM:SS
ttl_hours: 4
capabilities:
  - capability-tag
  - capability-tag
---
```

### Field Reference

| Field | Description |
|-------|-------------|
| `agent_name` | Unique identifier for this session. Format: `{repo-short}:{task-slug}` |
| `repo` | Working directory name (e.g. `grostak-v2`) |
| `status` | `active` = within TTL; `stale` = past TTL, not explicitly left; `inactive` = left via `/backbone-leave` |
| `joined` | ISO timestamp when the agent registered |
| `updated` | ISO timestamp of last frontmatter update |
| `ttl_hours` | Hours until record is considered stale (default: 4) |
| `capabilities` | Free-form tags describing what this agent knows or is doing |

---

## Prose Sections

| Section | Filled by | When |
|---------|-----------|------|
| **Current Task** | Agent on `/backbone-join` | Describes what this session is working on right now |
| **Architectural Knowledge** | Agent on `/backbone-join` | What this agent knows about the system that peers would find useful |
| **Learned** | Agent on `/backbone-leave` | Discoveries, decisions made, schema/API changes, open questions left behind |

---

## TTL and Staleness

Presence records do **not** expire automatically — there is no background daemon. Instead, the reading agent computes freshness:

```
stale = (now - updated) > ttl_hours * 3600
```

- **Active**: `updated` within `ttl_hours` and `status: active`
- **Stale**: past TTL or `status` never set to `inactive` — agent may have abandoned the session
- **Inactive**: `status: inactive` set explicitly via `/backbone-leave`

On `/backbone-join`, stale records are shown separately with a staleness warning. They are not deleted — the `Learned` section may still contain useful context.

---

## Common Capability Tags

Use these tags in the `capabilities` list for consistent matching across sessions:

| Tag | Meaning |
|-----|---------|
| `schema-analysis` | Has analyzed the DB schema |
| `patient-api` | Knows the patient-facing API surface |
| `auth-flow` | Understands Clerk JWT + tenant middleware |
| `mobile-hooks` | Knows stak-app React hooks and data layer |
| `backbone-development` | Working on the backbone itself (specs, commands, tests) |
| `migrations` | Has written or reviewed DB migrations |
| `test-infrastructure` | Knows the test setup and patterns |

Free-form tags are fine too — these are just the most common ones. Consistent tags improve capability matching on `/backbone-join`.

---

## Well-Known Agent Names

Some agent names are reserved by convention and carry special behavior:

| Name | Repo | Behavior |
|------|------|----------|
| `agent-backbone:maintainer` | `agent-backbone` | Auto-subscribes to `backbone-meta` on join — receives all feedback messages |

### The Maintainer Pattern

Any session working on the backbone itself (fixing bugs, implementing specs, triaging feedback) should join as `agent-backbone:maintainer`. `/backbone-join` suggests this name automatically when the working directory is `agent-backbone` and the task is maintenance-flavored.

When registered as `agent-backbone:maintainer`, the backbone acts as a first-class message recipient. Other agents across any repo can send feedback via:

```
/backbone-publish --type feedback
```

The feedback message routes to `topic: backbone-meta`. The maintainer session sees it in `/backbone-inbox` because it is subscribed to that topic automatically.

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/backbone-join` | Register presence, see roster, get capability match hints |
| `/backbone-roster` | See all agents (active, stale, recently inactive) |
| `/backbone-leave` | Write learned summary, mark inactive |
