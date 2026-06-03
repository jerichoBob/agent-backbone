# Change Request (CR) Message Store

This directory is the shared message bus for any agents registered on the backbone. CR files are written by Claude agents and read by Claude agents — no manual copy-paste required.

---

## File Naming Convention

```
cr-{id}-{status}.md
```

- `{id}` — timestamp slug: `YYYYMMDD-HHMMSS` (collision-free, sortable)
- `{status}` — one of: `draft` | `in-progress` | `awaiting-response` | `complete`

Status is encoded in the filename so `ls messages/` is immediately informative and renames are atomic.

**Examples:**

```
cr-20260603-143022-draft.md
cr-20260603-143022-in-progress.md
cr-20260603-143022-awaiting-response.md
cr-20260603-143022-complete.md
```

---

## Frontmatter Schema

```yaml
---
id: YYYYMMDD-HHMMSS
status: draft | in-progress | awaiting-response | complete
created: YYYY-MM-DD
updated: YYYY-MM-DD
from: agent-name          # registered name of the sending agent
to: agent-name | any      # registered name of the target agent, or "any"
title: Short human-readable title
affected_endpoints:
  - METHOD /path/to/endpoint
affected_tables:
  - table_name
---
```

`from` and `to` use agent names registered via `/backbone-join`. Run `/backbone-roster` to see registered agents before sending. Use `to: any` for broadcast CRs that any available agent can claim.

---

## Prose Sections

Every CR file has four sections. The first two are filled in by the sending agent. The last two are filled in during implementation.

| Section | Filled by | When |
|---------|-----------|------|
| **Problem Statement** | sending agent | On `/cr-send` |
| **Solution Recommendation** | sending agent | On `/cr-send` |
| **Implementation Notes** | receiving agent | On `/cr-ready` |
| **Follow-up Notes** | sending agent | On `/cr-done` |

---

## Status Lifecycle

```
draft
  └─► in-progress        (receiving agent claims via /cr-inbox)
        └─► awaiting-response   (/cr-ready — receiving agent signals done)
              └─► complete       (/cr-done — sending agent closes out)
```

Each transition: renames the file + updates `status` and `updated` in frontmatter.

---

## Slash Commands

| Command | Who runs it | Action |
|---------|-------------|--------|
| `/backbone-join` | any agent | Register presence, see who else is active |
| `/backbone-roster` | any agent | See all active/recent agents and their capabilities |
| `/cr-send` | any agent | Draft and persist a new CR, addressed to a named agent |
| `/cr-inbox` | any agent | List CRs addressed to this agent, claim one |
| `/cr-ready` | receiving agent | Fill implementation notes, signal sender |
| `/cr-done` | sending agent | Fill follow-up notes, mark complete |
| `/backbone-leave` | any agent | Write learned summary, mark presence inactive |

---

## Directory Layout Assumption

All repos must be siblings under the same parent:

```
~/Play/github_repos/
  agent-backbone/    ← this repo
  grostak-v2/        ← or any other project
  stak-app/          ← or any other project
```

The slash commands use `../agent-backbone/` relative to their respective repos. If your layout differs, update the path in each command file.

---

## Audit Trail

CR files accumulate here permanently. `complete` CRs are filtered out of inbox views but remain as a decision log. A future `/cr-archive` command will move them to `messages/archive/`.
