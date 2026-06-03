# /cr-send — Send a Change Request to a named agent

Use this command from any repo to draft and persist a structured change request addressed to a specific agent on the backbone.

## Pre-flight check

Verify the backbone is accessible and check who's registered:

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
ls ../agent-backbone/presence/ 2>/dev/null
```

If `messages/` is `MISSING`: stop and tell the developer:
> `../agent-backbone/` is not accessible. Make sure `agent-backbone` is a sibling directory to this repo.

## Step 1: Show the roster

Read all files in `../agent-backbone/presence/` and display a brief roster so the developer can choose a target:

```
Registered agents:
  grostak-api:core       active   schema-analysis, patient-api
  stak-app:refill-flow   active   mobile-hooks, patient-api
  (or: no agents registered — use "any" to broadcast)
```

If no presence records exist, continue with `to: any`.

## Step 2: Determine target

If agents are registered, ask: "Who should receive this CR? (enter agent name, or 'any' to broadcast)"

## Step 3: Draft the CR

Read the current conversation context to understand:

1. **What change is needed**
2. **Which endpoints are affected** — existing or new
3. **Which tables are affected**
4. **Why** — what user-facing problem this solves

If context is sparse, ask: *"What change do you need the receiving agent to make?"* then proceed.

## Step 4: Write the CR file

Generate an ID: `YYYYMMDD-HHMMSS`

Determine the `from` name: read this session's presence record from `../agent-backbone/presence/` if it exists, otherwise use the working directory name as a fallback (e.g. `stak-app:unknown`).

Write to `../agent-backbone/messages/cr-{id}-draft.md`:

```markdown
---
id: "{id}"
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
from: {this-agent-name}
to: {target-agent-name | any}
title: "{short imperative title}"
affected_endpoints:
  - METHOD /path
affected_tables:
  - table_name
---

# Problem Statement

{1-3 sentences: what needs to change and why}

# Solution Recommendation

{Specific enough that the receiving agent can implement without follow-up questions:
endpoint signatures, request/response shapes, schema changes, auth requirements.}

# Implementation Notes

<!-- To be filled in by receiving agent via /cr-ready -->

# Follow-up Notes

<!-- To be filled in by sending agent via /cr-done -->
```

## Step 5: Confirm

```
CR written: ../agent-backbone/messages/cr-{id}-draft.md

Title:  {title}
From:   {from}
To:     {to}
Affects: {endpoint list}
Tables:  {table list}

{if to != "any": Switch to your {to} session and run /cr-inbox to pick this up.}
{if to == "any": Any registered agent can pick this up via /cr-inbox.}
```
