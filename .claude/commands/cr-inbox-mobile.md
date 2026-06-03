# /cr-inbox (stak-app) — Pick up a platform-ready change request

Use this command from **stak-app** to see change requests where the platform implementation is complete and the mobile side needs to act.

## Pre-flight check

```bash
ls ../agent-backbone/messages/ 2>/dev/null || echo "MISSING"
```

If `MISSING`: stop and tell the developer that `../agent-backbone/messages/` is not accessible.

## Step 1: List platform-ready CRs

Scan for `awaiting-mobile` CRs:

```bash
ls ../agent-backbone/messages/cr-*-awaiting-mobile.md 2>/dev/null
```

If none found: "No platform-ready change requests. Nothing to pick up."

For each found file, read its frontmatter and display a numbered summary:

```
Platform-Ready Change Requests:

#1  cr-20260603-143022  —  Add refill request endpoint
    Affects: POST /api/refills, GET /api/refills/:id
    Tables:  refill_requests
    Created: 2026-06-03
```

## Step 2: Claim a CR

Ask the developer: "Which CR do you want to pick up? (enter number, or 'skip')"

On selection:

1. Read the full CR file
2. Rename: `cr-{id}-awaiting-mobile.md` → `cr-{id}-mobile-in-progress.md`
3. Update frontmatter: `status: mobile-in-progress`, `updated: {today}`
4. Display the **Platform Implementation Notes** section in full

Confirm:

```
Claimed: cr-{id}-mobile-in-progress.md

--- Platform Implementation Notes ---
{full Platform Implementation Notes content}
-------------------------------------

Implement the mobile-side changes above, then run /cr-done to close this out.
```

## Notes

- Only shows `awaiting-mobile` CRs — other statuses are filtered out
- The Platform Implementation Notes section contains everything needed: endpoint signatures, schema, auth changes, breaking changes
