# /backbone-inbox — See and claim messages addressed to this agent

Use this command to see pending messages addressed to you (direct or via topic subscription) and claim one to work on.

## Pre-flight check

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop — `../agent-backbone/` is not accessible.

## Step 1: Identify this agent

Read this session's presence record from `../agent-backbone/presence/`. If none exists:
> "No presence record found. Run /backbone-join first — /backbone-inbox needs your registered name to filter messages."

Stop if not found. Extract `agent_name` and `subscriptions` (may be empty).

## Step 2: Scan for pending messages

Always run this shell command first to get a live listing — never use prior knowledge of the inbox state:

```bash
ls ../agent-backbone/messages/*-pending.md 2>/dev/null || echo "NONE"
```

For each file returned, read its frontmatter. Include it if:

- `routing: direct` AND (`to` == this agent's name OR `to` == `any`)
- `routing: topic` AND this agent's `subscriptions` list contains the message's `topic`

Apply optional filter: if `--type <type>` was passed, show only messages of that type.

Exclude `messages/types/`, `messages/archive/`, and `messages/README.md` from scanning.

## Step 3: Display results

If no messages found:

```
No pending messages for {agent_name}.
{if subscriptions empty: (You have no topic subscriptions — run /backbone-subscribe to add some.)}
```

Otherwise, group by type and display:

```
Pending Messages for {agent_name}

CR  (change requests)
  #1  cr-20260606-143022    From: stak-app:refill-flow    → direct
      Add refill request endpoint
      Tables: refill_requests

TASK  (task assignments)
  #2  task-20260604-091500  From: agent-backbone:spec-work  → direct
      Add index on refill_requests(tenant_id, status)
      Priority: normal

  #3  task-20260604-100000  From: stak-app:bloodwork  → topic: schema-changes
      Review bloodwork panel schema proposal
      Priority: high
```

## Step 4: Claim a message

Ask: "Which message do you want to claim? (number, or 'skip')"

On selection:

1. Read the full message file
2. Rename: `{type}-{id}-pending.md` → `{type}-{id}-claimed.md`
3. Update frontmatter: `status: claimed`, `updated: {today}`
4. Display the full message content

Confirm:

```
Claimed: {type}-{id}-claimed.md
From:    {from}
Type:    {type}

{full message content}

Work on this, then run /backbone-complete to close it out.
```

## Step 5: Spec Handover Protocol (for CR and task messages)

**Every CR or task received from another agent must be hydrated as a local spec before implementation begins.**

The sender's spec version numbers are theirs — this project has its own sequence. Do not use the sender's version number.

### On claim:

1. **Immediately send an ack** to the sender via a new backbone message:
   ```
   Claimed your {type} "{title}". Creating local spec now — will notify when complete.
   ```

2. **Run `/sdd-spec`** with a description synthesized from the CR/task content. This creates a local `spec-vN` (next number in this project's sequence) that captures the why, what, and how — including any context from the backbone message. Reference the sender's spec in the Technical Notes (e.g. "Sourced from stak-app backbone CR, their spec-v18").

3. **Implement against the local spec**, marking tasks complete as you go.

4. **Notify the sender when done** via a new backbone message including:
   - Your local spec number and filename
   - The commit hash
   - Any follow-up they need to do (e.g. "deployed to UAT, ready for your Phases 2–7")

### Why:
- The sender's spec lives in their repo. This project needs its own spec for traceability, code review context, and future sessions.
- Acks prevent duplicate work — without them, a sender doesn't know if their CR was picked up or ignored.
- The local spec number sequence is the authoritative history for this project.

## Notes

- `archive/` is never scanned — completed messages are invisible here by design
- Topic messages use competing-consumer semantics: first agent to rename the file wins
- Pass `--type cr` to see only change requests, `--type task` for tasks only
