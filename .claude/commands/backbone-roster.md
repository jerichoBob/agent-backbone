# /backbone-roster — Show all registered agents

Use this command from any repo to get a full picture of the backbone network — who's active, who's stale, and what recent sessions learned.

## Pre-flight check

```bash
ls ../agent-backbone/presence/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop — `../agent-backbone/` is not accessible.

## Step 1: Read all presence records

**IMPORTANT: Always fetch fresh from disk. Never use cached file contents from earlier in the conversation — presence files are written by other agents and change between reads.**

Use the Bash tool to get the current file list:

```bash
ls ../agent-backbone/presence/presence-*.md 2>/dev/null || echo "MISSING"
```

Then use the Read tool on each file individually to force a fresh read. Do not skip any file because you think you already have its contents.

For each file, extract:

- `agent_name`, `repo`, `status`, `joined`, `updated`, `ttl_hours`, `capabilities`
- First sentence of **Current Task**
- Full **Learned** section (for inactive agents)

Compute staleness for each: `stale = (now - updated) > ttl_hours * 3600`

## Step 2: Display the roster

Group into three sections. If a section is empty, omit it.

```
═══════════════════════════════════════════════
 Backbone Roster  ({total} agents)
═══════════════════════════════════════════════

ACTIVE  ({n} agents)
────────────────────────────────────────────
  grostak-api:patient-schema
  Repo:         grostak-v2
  Joined:       23 minutes ago
  Capabilities: schema-analysis, patient-api, migrations
  Task:         Designing patient clinical data schema

  stak-app:refill-flow
  Repo:         stak-app
  Joined:       1 hour ago
  Capabilities: mobile-hooks, patient-api
  Task:         Wiring refill request UI to new endpoint

STALE  ({n} agents — past TTL, may be abandoned)
────────────────────────────────────────────
  stak-app:bloodwork
  Repo:         stak-app
  Last seen:    7 hours ago  (TTL: 4h)
  Capabilities: mobile-hooks
  Task:         Adding bloodwork panel display

RECENTLY INACTIVE  ({n} agents)
────────────────────────────────────────────
  agent-backbone:maintainer
  Repo:         agent-backbone
  Left:         2 hours ago
  Learned:
    - Decided against daemon-based TTL; reading agent computes staleness
    - Open: name inference needs testing across more repo layouts
    - Gotcha: sed -i '' syntax differs on macOS vs Linux

═══════════════════════════════════════════════
```

If `presence/` is empty:

```
No agents registered on the backbone yet.
Run /backbone-join to register this session.
```

## Notes

- "Recently inactive" shows all `status: inactive` records — they are never auto-deleted
- Stale records are those where `(now - updated) > ttl_hours * 3600` and `status != inactive`
- To clean up stale records manually, delete the presence file or run `/backbone-join` with the same name to overwrite it
