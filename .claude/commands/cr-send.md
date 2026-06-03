# /cr-send — Send a Change Request to the backbone

Use this command from **stak-app** (or any consumer repo) to draft and persist a structured change request to the agent-backbone message store.

## Pre-flight check

Before drafting, verify the backbone messages directory is accessible:

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
```

If the output is `MISSING`, stop and tell the developer:
> `../agent-backbone/messages/` is not accessible. Make sure `agent-backbone` is a sibling directory to this repo.

## What to draft

Read the current conversation context to understand:

1. **What change is needed** — what does the mobile app need that the platform doesn't yet provide?
2. **Which endpoints are affected** — existing endpoints being modified, or new ones needed
3. **Which tables are affected** — schema changes, new tables, or new columns
4. **Why** — what user-facing problem this solves

If context is sparse, ask the developer one question: *"What change do you need the platform to make?"* then proceed.

## CR file format

Generate an ID from the current date/time: `YYYYMMDD-HHMMSS`

Write the file to `../agent-backbone/messages/cr-{id}-draft.md` with this structure:

```markdown
---
id: "{id}"
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
source_repo: stak-app
title: "{short imperative title}"
affected_endpoints:
  - METHOD /path
affected_tables:
  - table_name
---

# Problem Statement

{1-3 sentences: what the mobile app needs and why the current platform doesn't support it}

# Solution Recommendation

{What the platform should build — endpoint signatures, request/response shapes, schema changes,
auth requirements. Be specific enough that a grostak-v2 agent can act on this without asking
follow-up questions.}

# Platform Implementation Notes

<!-- To be filled in by grostak-v2 agent via /cr-ready -->

# Mobile Implementation Notes

<!-- To be filled in by stak-app agent via /cr-done -->
```

## After writing

Confirm to the developer:

```
CR written: ../agent-backbone/messages/cr-{id}-draft.md

Title: {title}
Affects: {endpoint list}
Tables:  {table list}

Switch to your grostak-v2 session and run /cr-inbox to pick this up.
```
