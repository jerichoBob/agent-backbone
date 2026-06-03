# /cr-inbox (grostak-v2) — Claim an incoming change request

Use this command from **grostak-v2** to see pending change requests from stak-app and claim one for implementation.

## Pre-flight check

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop and tell the developer that `../agent-backbone/messages/` is not accessible.

## Step 1: List pending CRs

Scan for `draft` CRs:

```bash
ls ../agent-backbone/messages/cr-*-draft.md 2>/dev/null
```

If none found, tell the developer: "No pending change requests. Nothing to claim."

For each found file, read its frontmatter and display a numbered summary:

```
Pending Change Requests:

#1  cr-20260603-143022  —  Add refill request endpoint
    Affects: POST /api/refills, GET /api/refills/:id
    Tables:  refill_requests
    Created: 2026-06-03

#2  cr-20260604-091500  —  Add bloodwork panel endpoint
    Affects: GET /api/bloodwork/panels
    Tables:  bloodwork_panels
    Created: 2026-06-04
```

## Step 2: Claim a CR

Ask the developer: "Which CR do you want to claim? (enter number, or 'skip')"

On selection:

1. Read the full CR file
2. Rename: `cr-{id}-draft.md` → `cr-{id}-platform-in-progress.md`
3. Update frontmatter: `status: platform-in-progress`, `updated: {today}`
4. Display the full **Problem Statement** and **Solution Recommendation** sections

Confirm:

```
Claimed: cr-{id}-platform-in-progress.md

{Problem Statement content}

{Solution Recommendation content}

Implement the changes above, then run /cr-ready to signal completion.
```

## Notes

- Only shows `draft` CRs — `platform-in-progress`, `awaiting-mobile`, and `complete` CRs are filtered out
- If another session already claimed a CR (file renamed), it will not appear in the list
