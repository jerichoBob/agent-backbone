# /backbone-publish — Publish a message to the backbone

Use this command to send a typed message to another agent (direct) or to a topic (pub/sub).

## Pre-flight check

```bash
ls ../agent-backbone/messages/types/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop — `../agent-backbone/` is not accessible.

## Step 0: Clarify intent

**MUST ask this before doing anything else, even if context seems obvious.**

Ask the user:

```
What is the intent of this message?
  a) Informational — share context or artifacts; no action required from the receiver
  b) Task — delegate a unit of work with acceptance criteria
  c) Change request — ask the receiver to make a code/schema change
  d) Other — describe:
```

Wait for the answer. Use it to guide the message type and tone:

- Informational → use a lightweight prose message; do NOT add acceptance criteria or a to-do list
- Task → proceed to Step 1 and select `task` type
- Change request → proceed to Step 1 and select `cr` type
- Other → ask a follow-up to clarify before proceeding

**Never infer intent from context and skip this step.**

## Step 1: Determine message type

If `--type <type>` was provided as an argument, use it directly.

Otherwise, list registered types by scanning `../agent-backbone/messages/types/` for `*.md` files (excluding `README.md`) and ask:

```
Available message types:
  cr    — Change request (ask another agent to make a code/schema change)
  task  — Task assignment (delegate a unit of work)

Type? (enter slug, e.g. "cr" or "task"):
```

Read the selected type's schema from `../agent-backbone/messages/types/{type}.md` before proceeding.

## Step 2: Determine routing

If `--to <agent>` or `--topic <topic>` was provided, use it.

Otherwise ask:

```
Route to:
  1) A specific agent (direct)  — you'll pick from the roster
  2) A topic (pub/sub)          — any subscribed agent will see it
```

**For direct routing:**

- Read `../agent-backbone/presence/` and show active agents
- Ask: "Which agent? (enter name, or 'any' for unclaimed broadcast)"
- Set `routing: direct`, `to: {agent-name}`

**For topic routing:**

- Ask: "Topic name? (e.g. patient-api, schema-changes)"
- Set `routing: topic`, `topic: {topic-name}`

## Step 3: Determine sender name

Read this session's presence record from `../agent-backbone/presence/`. If none exists:
> "No presence record found. Run /backbone-join first to register this session."
Stop if not found.

## Step 4: Draft the message content

Read the type schema from `../agent-backbone/messages/types/{type}.md` to understand what sections to fill in.

Using current conversation context, draft:

- Any type-specific frontmatter fields (e.g. `affected_endpoints` for cr, `priority` for task)
- Each prose section defined by the type schema

If context is sparse for a section, ask one focused question rather than leaving it blank.

## Step 5: Write the message file

Generate ID: `YYYYMMDD-HHMMSS`

Write to `../agent-backbone/messages/{type}-{id}-pending.md`:

```markdown
---
id: "{id}"
type: {type}
status: pending
routing: {direct|topic}
from: {this-agent-name}
to: {agent-name}        # if routing: direct
topic: {topic-name}     # if routing: topic
{type-specific fields}
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

{prose sections from type schema}
```

## Step 6: Confirm

```
Published: ../agent-backbone/messages/{type}-{id}-pending.md

Type:    {type}
From:    {from}
{To:     {to}   or   Topic: {topic}}

{if direct && to != "any":
  Switch to your {to} session and run /backbone-inbox to pick this up.}
{if topic:
  Any agent subscribed to "{topic}" will see this in /backbone-inbox.}
{if to == "any":
  Any registered agent can claim this via /backbone-inbox.}
```
