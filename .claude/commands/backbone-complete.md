# /backbone-complete — Close out a message and archive it

Use this command after finishing the work described in a claimed message. It writes the completion notes, marks the message complete, and moves it to `messages/archive/` — removing it from the active scan path permanently.

## Transport

Backbone files can move over the local disk (default) or over git. Check which, and resolve the sync script once:

```bash
SYNC=.claude/scripts/backbone/backbone-sync.sh; [ -x "$SYNC" ] || SYNC=../agent-backbone/scripts/backbone-sync.sh
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

- `local` — nothing below changes: read and write `../agent-backbone/` directly and skip every `$SYNC` step.
- `git` — run the `$SYNC` steps shown below. Exit codes: `2` remote unreachable (stop and tell the developer; do NOT fall back to local), `3` lost a race (see the step), `4` config error.

If `git`: run `bash "$SYNC" --dir ../agent-backbone pull` first.

## Pre-flight check

Find claimed messages owned by this session:

```bash
ls ../agent-backbone/messages/*-claimed.md 2>/dev/null
```

Read each file's frontmatter. Show only those where `from` matches this session's agent name (for direct messages where this agent is the original sender responding back is not applicable — the receiver completes) OR where this agent claimed it (tracked by the rename at claim time — any claimed file in messages/ was claimed by the current session if no other session has the same name).

If none found: "No claimed messages for this session. Run /backbone-inbox to claim one first."

If multiple found: list them and ask which to complete.

## Step 1: Read the type schema

Read the claimed message's `type` field. Load `../agent-backbone/messages/types/{type}.md` to know what completion notes to write.

## Step 2: Write completion notes

Using current conversation context, write the completion section defined by the type schema:

- `cr` type: **Implementation Notes** — endpoints added, schema changes, migration path, breaking changes
- `task` type: **Completion Notes** — what was done, acceptance criteria met/unmet, follow-on work
- Other types: whatever the schema's completion section specifies

Be specific enough that the sender can act on it without follow-up questions.

## Step 3: Archive the message

1. Update the message file: fill in the completion section, set `status: complete`, `updated: {today}`
2. Create `../agent-backbone/messages/archive/` if it doesn't exist
3. Move the file: `{type}-{id}-claimed.md` → `archive/{type}-{id}-complete.md`

The file is now out of the active scan path. `/backbone-inbox` will never show it again.

4. **git transport only:** `bash "$SYNC" --dir ../agent-backbone push complete {type}-{id}` — commits the move as `backbone: complete {type}-{id}` and pushes it.

## Step 4: Confirm

```
Completed: ../agent-backbone/messages/archive/{type}-{id}-complete.md

Type:  {type}
From:  {from}

Completion notes written:
{brief bullet summary of what was documented}

Archived — this message will no longer appear in /backbone-inbox.
{if routing == direct: The sender ({from}) can read the archived file for implementation details.}
```

## Notes

- `messages/archive/` is the only destination for completed messages — never delete them
- The archive serves as the permanent audit trail (alongside presence `Learned` blocks)
- If the sender needs to follow up after reading completion notes, they publish a new message
