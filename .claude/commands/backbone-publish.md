# /backbone-publish — Publish a message to the backbone

Use this command to send a typed message to another agent (direct) or to a topic (pub/sub).

## Pre-flight check

```bash
ls ../agent-backbone/messages/types/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop — `../agent-backbone/` is not accessible.

## Transport

Backbone files can move over the local disk (default) or over git. Check which, and resolve the sync script once:

```bash
SYNC=.claude/scripts/backbone/backbone-sync.sh; [ -x "$SYNC" ] || SYNC=../agent-backbone/scripts/backbone-sync.sh
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

- `local` — nothing below changes: read and write `../agent-backbone/` directly and skip every `$SYNC` step.
- `git` — run the `$SYNC` steps shown below. Exit codes: `2` remote unreachable (stop and tell the developer; do NOT fall back to local), `3` lost a race (see the step), `4` config error.

If `git`: run `bash "$SYNC" --dir ../agent-backbone pull` now, before reading presence or types.

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

## Step 4b: Secret check

Before writing anything, write the drafted body to a scratch file inside the backbone (not `/tmp`) and scan it:

```bash
bash .claude/scripts/backbone/backbone-secret-check.sh {draft-file}
```

(Fall back to `../agent-backbone/scripts/backbone-secret-check.sh`.) Exit `1` means a possible secret — connection string with credentials, bearer token, private key, API key, or long token. The script prints `line N: <what matched>`, never the matched text. **Refuse to publish.** Tell the sender which lines matched, ask them to remove the secret or reference it by name (e.g. "the Atlas URI in your .env"), and re-draft. Do not offer to bypass the check. Delete the scratch file afterwards.

Applies to every transport: a secret in a local message still ends up in archives and presence logs.

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

### Step 5b: Push (git transport only)

```bash
bash "$SYNC" --dir ../agent-backbone push publish {type}-{id}
```

This commits the new file as `backbone: publish {type}-{id}` and pushes it. If it exits non-zero, report the error — the message is on disk but the recipient will not see it until a push succeeds.

### Step 5c: No-ack ping (git transport, direct messages to a named agent)

Skip this for `local` transport, topic routing, and `to: any` — there is no single recipient to ping.

After a successful push, start the sender-side timer with the **Monitor** tool:

```bash
bash .claude/scripts/backbone-ack-check.sh --dir ../agent-backbone --id {type}-{id} --to {to} --from {from} --title "{title}"
```

(Use `.claude/scripts/backbone/backbone-ack-check.sh`; fall back to `../agent-backbone/scripts/`.) Defaults: 5-minute timeout, 15-second check interval. The script stays silent if the receiver claims the message or writes a `seen` marker in time.

If it prints a `PING <human>|<gchat> :: ...` line, send the text after `::` to that person with the `/gchat` skill, as the developer's own account, with **no per-ping confirmation** (the developer accepted this by publishing). Send exactly that text — sender and title only, never the message body. If it prints `NOPING`, tell the developer there is no `roster.md` entry for the recipient (see `docs/git-transport.md`). If the `/gchat` skill is not installed, show the developer the ping text instead.

Limit: the timer lives in this session. If the session closes before the 5 minutes pass, no ping is sent.

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
