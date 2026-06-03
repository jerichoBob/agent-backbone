# /backbone-leave — Deregister and leave a learned summary

Run this at the end of a session to mark yourself inactive and persist what you learned for future agents.

## Pre-flight check

Find this session's presence record. Read all files in `../agent-backbone/presence/` and identify the one matching this session's agent name (infer from working directory if needed).

If no presence record found:
> "No presence record found for this session. Run /backbone-join first to register before leaving."

Stop if not found.

## Step 1: Write the Learned section

Prompt Claude to synthesize a concise **Learned** section (5–10 bullets max) covering:

- **What was built or changed** — specific files, endpoints, schema, migrations
- **Decisions made** — architectural choices, tradeoffs, things that were ruled out
- **Open questions left behind** — anything unresolved that the next agent picking this up should know
- **Surprises or gotchas** — things that weren't obvious from the code or spec

Keep it tight. This is a handoff note, not a transcript. Future agents will read it at join time.

Example:

```
- Implemented /cr-inbox as a generic command — filters by agent name from presence record, not hardcoded role
- Decided against daemon-based TTL enforcement; reading agent computes staleness from timestamps
- Open: /backbone-join name inference needs testing across more repo layouts
- Gotcha: sed -i '' syntax differs on macOS vs Linux — test scripts use the macOS form
```

## Step 2: Update the presence record

Read the current presence file. Update:

1. Fill in the `# Learned` section with the synthesized bullets
2. Set `status: inactive`
3. Set `updated: {current-ISO-timestamp}`

Write the updated file back (same path — do not rename).

## Step 3: Confirm

```
Left backbone: {agent_name}
Presence record updated: ../agent-backbone/presence/presence-{agent_name}.md

Learned summary persisted ({N} bullets).
Future agents joining with similar capabilities will see this in /backbone-join hints.
```
