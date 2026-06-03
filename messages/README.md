# Change Request (CR) Message Store

This directory is the shared message bus between `grostak-v2` and `stak-app`. CR files are written by Claude agents and read by Claude agents — no manual copy-paste required.

---

## File Naming Convention

```
cr-{id}-{status}.md
```

- `{id}` — timestamp slug: `YYYYMMDD-HHMMSS` (collision-free, sortable)
- `{status}` — one of: `draft` | `platform-in-progress` | `awaiting-mobile` | `mobile-in-progress` | `complete`

Status is encoded in the filename so `ls messages/` is immediately informative and renames are atomic.

**Examples:**

```
cr-20260603-143022-draft.md
cr-20260603-143022-platform-in-progress.md
cr-20260603-143022-awaiting-mobile.md
cr-20260603-143022-mobile-in-progress.md
cr-20260603-143022-complete.md
```

---

## Frontmatter Schema

```yaml
---
id: YYYYMMDD-HHMMSS
status: draft | platform-in-progress | awaiting-mobile | mobile-in-progress | complete
created: YYYY-MM-DD
updated: YYYY-MM-DD
source_repo: stak-app | grostak-v2
title: Short human-readable title
affected_endpoints:
  - METHOD /path/to/endpoint
affected_tables:
  - table_name
---
```

---

## Prose Sections

Every CR file has four sections. The first two are filled in by the stak-app agent at creation. The last two are filled in during implementation.

| Section | Filled by | When |
|---------|-----------|------|
| **Problem Statement** | stak-app agent | On `/cr-send` |
| **Solution Recommendation** | stak-app agent | On `/cr-send` |
| **Platform Implementation Notes** | grostak-v2 agent | On `/cr-ready` |
| **Mobile Implementation Notes** | stak-app agent | On `/cr-done` |

---

## Status Lifecycle

```
draft
  └─► platform-in-progress   (grostak-v2 claims via /cr-inbox)
        └─► awaiting-mobile   (grostak-v2 signals done via /cr-ready)
              └─► mobile-in-progress  (stak-app claims via /cr-inbox)
                    └─► complete       (stak-app signals done via /cr-done)
```

Each transition: renames the file + updates `status` and `updated` in frontmatter.

---

## Slash Commands

| Command | Repo | Action |
|---------|------|--------|
| `/cr-send` | stak-app | Draft and persist a new CR |
| `/cr-inbox` | grostak-v2 | List `draft` CRs, claim one |
| `/cr-ready` | grostak-v2 | Fill platform notes, mark `awaiting-mobile` |
| `/cr-inbox` | stak-app | List `awaiting-mobile` CRs, claim one |
| `/cr-done` | stak-app | Fill mobile notes, mark `complete` |

---

## Directory Layout Assumption

All three repos must be siblings under the same parent:

```
~/Play/github_repos/
  agent-backbone/    ← this repo
  grostak-v2/
  stak-app/
```

The slash commands use `../agent-backbone/messages/` relative to their respective repos. If your layout differs, update the path in each command file.

---

## Audit Trail

CR files accumulate here permanently. `complete` CRs are filtered out of inbox views but remain as a decision log. A future `/cr-archive` command will move them to `messages/archive/`.
