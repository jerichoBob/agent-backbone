# /cr-inbox — Claim a change request addressed to this agent

Use this command from any repo to see change requests addressed to you and claim one for implementation.

## Pre-flight check

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop — `../agent-backbone/` is not accessible.

## Step 1: Determine this agent's name

Read this session's presence record from `../agent-backbone/presence/`. If no presence record exists, prompt the developer:
> "No presence record found. Run /backbone-join first to register this session, then retry /cr-inbox."

Stop if no presence record.

## Step 2: List addressed CRs

Scan `../agent-backbone/messages/` for `draft` CRs where `to` matches this agent's name OR `to: any`:

```bash
ls ../agent-backbone/messages/cr-*-draft.md 2>/dev/null
```

Read each file's frontmatter. Show only those where `to` == this agent's name or `to` == `any`.

If none found: "No change requests addressed to you. Nothing to claim."

Display a numbered summary:

```
Change Requests for {this-agent-name}:

#1  cr-20260603-143022  —  Add refill request endpoint
    From:   stak-app:refill-flow
    To:     grostak-api:core
    Tables: refill_requests
    Created: 2026-06-03

#2  cr-20260604-091500  —  (broadcast) Add bloodwork panel endpoint
    From:   stak-app:bloodwork
    To:     any
    Created: 2026-06-04
```

## Step 3: Claim a CR

Ask: "Which CR do you want to claim? (number, or 'skip')"

On selection:

1. Read the full CR file
2. Rename: `cr-{id}-draft.md` → `cr-{id}-in-progress.md`
3. Update frontmatter: `status: in-progress`, `updated: {today}`
4. Display the full **Problem Statement** and **Solution Recommendation** sections

Confirm:

```
Claimed: cr-{id}-in-progress.md
From:    {from}

{Problem Statement content}

{Solution Recommendation content}

Implement the changes above, then run /cr-ready to signal completion.
```
