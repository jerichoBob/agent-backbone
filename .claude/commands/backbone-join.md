# /backbone-join — Register this session on the backbone

Run this at the start of any session that will interact with the backbone (sending or receiving CRs, reading peer context). It registers your presence so other agents can find you.

## Transport

Backbone files can move over the local disk (default) or over git. Check which, and resolve the sync script once:

```bash
SYNC=.claude/scripts/backbone/backbone-sync.sh; [ -x "$SYNC" ] || SYNC=../agent-backbone/scripts/backbone-sync.sh
bash "$SYNC" --dir ../agent-backbone mode      # prints: local | git
```

- `local` — skip every `$SYNC` step below.
- `git` — run them. Exit `2` (remote unreachable) means stop and tell the developer; never fall back to local.

If `git`: run `bash "$SYNC" --dir ../agent-backbone pull` first, so the roster below is current.

## Pre-flight check

```bash
ls ../agent-backbone/presence/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop and tell the developer:
> `../agent-backbone/` is not accessible. Make sure `agent-backbone` is a sibling directory to this repo.

## Step 1: Read and display the current roster

Read all files in `../agent-backbone/presence/`. For each, extract frontmatter (`agent_name`, `repo`, `status`, `joined`, `updated`, `ttl_hours`, `capabilities`) and the first line of the **Current Task** section.

Compute staleness: `stale = (now - updated) > ttl_hours * 3600`

Display the roster in three groups:

```
═══════════════════════════════════════
 Backbone Roster
═══════════════════════════════════════

Active agents:
  grostak-api:patient-schema  (grostak-v2, joined 23m ago)
    Task: Designing patient clinical data schema
    Capabilities: schema-analysis, patient-api, migrations
    Subscriptions: schema-changes

Stale agents (past TTL — may be abandoned):
  stak-app:refill-flow  (stak-app, last seen 6h ago)
    Task: Wiring refill request UI
    Capabilities: mobile-hooks, patient-api
    Subscriptions: (none)

Recently inactive:
  agent-backbone:maintainer  (agent-backbone, left 2h ago)
    Learned: CR workflow implemented, /cr-inbox now requires presence record

(No agents registered yet.)  ← shown if presence/ is empty
═══════════════════════════════════════
```

If `presence/` is empty, say so and continue to registration.

## Step 2: Infer a candidate name

Infer a name from:

1. The working directory name (e.g. `grostak-v2` → `grostak-api`)
2. The current task or conversation context (e.g. `patient-schema`, `refill-flow`, `maintainer`)

Format: `{repo-short}:{task-slug}` — lowercase, hyphens, no spaces.

Examples: `grostak-api:patient-schema`, `stak-app:refill-flow`, `agent-backbone:v2-presence`

**Maintainer detection:** If the working directory is `agent-backbone` and the task context is maintenance, improvement, or issue triage (rather than a specific feature), suggest `agent-backbone:maintainer` as the name. This is the well-known name that feedback messages are routed to.

Present the inferred name to the developer:

```
Suggested name: grostak-api:patient-schema
Enter a different name, or press Enter to accept:
```

Use the confirmed name for registration.

## Step 3: Write the presence record

**Get the current timestamp first — do not approximate:**

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

Use the exact output for both `joined` and `updated` fields. Never use midnight (`T00:00:00Z`) or any guessed value.

Write to `../agent-backbone/presence/presence-{agent_name}.md`:

```markdown
---
agent_name: {confirmed-name}
repo: {working-directory-name}
status: active
joined: {current-ISO-timestamp}
updated: {current-ISO-timestamp}
ttl_hours: 4
capabilities:
  - {inferred-capability-1}
  - {inferred-capability-2}
subscriptions:
  - backbone-meta    # if agent_name == agent-backbone:maintainer; else []
---

# Current Task

{1-3 sentences describing what this session is working on, inferred from context}

# Architectural Knowledge

{What this agent already knows about the system that peers would find useful.
If this is a fresh session with no prior context, write "None yet — session just started."}

# Learned

<!-- To be filled in by /backbone-leave -->
```

Infer 2-4 capabilities from the working directory and current task context. Use tags from `../agent-backbone/presence/README.md` where they fit; add new ones if needed.

**git transport only:** `bash "$SYNC" --dir ../agent-backbone push join {agent_name}`. Presence is written only on join and leave in git mode — there is no heartbeat, so `updated` and `ttl_hours` do not mean the agent is still online.

## Step 4: Capability match hints

After writing the presence record, scan all **active** agents for capability overlap with this session's declared capabilities.

For each match, surface a hint:

```
You may want to consult:
  → grostak-api:patient-schema (active, 23m ago) — shares: patient-api, schema-analysis
    Architectural Knowledge: [first sentence of their Architectural Knowledge section]
    File: ../agent-backbone/presence/presence-grostak-api:patient-schema.md
```

If no matches, skip the hints section.

## Step 5: Load and display backbone conventions

Read `../agent-backbone/CONVENTIONS.md`. Display it to the developer under a "Backbone Conventions" header so they are aware of the operating rules before the session proceeds.

If the file does not exist, skip silently.

## Step 5b: Start the new-message watcher

Start the poll with the **Monitor** tool so this session is woken when a message addressed to it arrives. It prints nothing while idle (no model tokens) and prints one line, then exits, on a new message:

```bash
bash .claude/scripts/backbone/backbone-poll.sh --dir ../agent-backbone --agent {agent_name}
```

(Fall back to `../agent-backbone/scripts/backbone-poll.sh` if the installed copy is missing.) The default check interval is 30 seconds. When it fires, run `/backbone-inbox`, and restart the watcher afterwards.

In `git` mode the poll also writes the receiver's `seen` marker, which stops the sender's 5-minute no-ack ping.

## Step 6: Confirm registration

```
Registered: {agent_name}
Presence record: ../agent-backbone/presence/presence-{agent_name}.md

Run /backbone-leave before ending this session to persist what you learned.
Run /backbone-inbox to see messages addressed to you.
Run /backbone-subscribe <topic> to receive topic broadcasts.
```

## Notes

- If a presence file already exists with the same name but a different `joined` time, warn: "A presence record for {name} already exists (joined {time}). Overwriting."
- Capabilities are inferred — the developer can edit the presence file directly after registration if needed
- **Maintainer pattern**: when registering as `agent-backbone:maintainer`, automatically write `subscriptions: [backbone-meta]` — this is how feedback messages (type: feedback, topic: backbone-meta) reach the backbone maintainer's inbox without any manual subscription step
