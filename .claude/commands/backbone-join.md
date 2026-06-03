# /backbone-join — Register this session on the backbone

Run this at the start of any session that will interact with the backbone (sending or receiving CRs, reading peer context). It registers your presence so other agents can find you.

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

Stale agents (past TTL — may be abandoned):
  stak-app:refill-flow  (stak-app, last seen 6h ago)
    Task: Wiring refill request UI
    Capabilities: mobile-hooks, patient-api

Recently inactive:
  agent-backbone:cr-workflow  (agent-backbone, left 2h ago)
    Learned: CR workflow implemented, /cr-inbox now requires presence record

(No agents registered yet.)  ← shown if presence/ is empty
═══════════════════════════════════════
```

If `presence/` is empty, say so and continue to registration.

## Step 2: Infer a candidate name

Infer a name from:

1. The working directory name (e.g. `grostak-v2` → `grostak-api`)
2. The current task or conversation context (e.g. `patient-schema`, `refill-flow`, `cr-workflow`)

Format: `{repo-short}:{task-slug}` — lowercase, hyphens, no spaces.

Examples: `grostak-api:patient-schema`, `stak-app:refill-flow`, `agent-backbone:v2-presence`

Present the inferred name to the developer:

```
Suggested name: grostak-api:patient-schema
Enter a different name, or press Enter to accept:
```

Use the confirmed name for registration.

## Step 3: Write the presence record

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

## Step 5: Confirm registration

```
Registered: {agent_name}
Presence record: ../agent-backbone/presence/presence-{agent_name}.md

Run /backbone-leave before ending this session to persist what you learned.
Run /cr-inbox to see change requests addressed to you.
```

## Notes

- If a presence file already exists with the same name but a different `joined` time, warn: "A presence record for {name} already exists (joined {time}). Overwriting."
- Capabilities are inferred — the developer can edit the presence file directly after registration if needed
