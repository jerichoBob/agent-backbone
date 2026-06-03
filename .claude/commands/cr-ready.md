# /cr-ready — Signal platform implementation complete

Use this command from **grostak-v2** after implementing the platform side of a change request.

## Pre-flight check

Find the in-progress CR for this session:

```bash
ls ../agent-backbone/messages/cr-*-platform-in-progress.md 2>/dev/null
```

If none found: "No CR is currently claimed as platform-in-progress. Run /cr-inbox first."

If multiple found: list them and ask the developer which one to complete.

## Step 1: Fill in Platform Implementation Notes

Read the CR file. Then write the **Platform Implementation Notes** section with:

- **Endpoints added/modified** — full signatures: method, path, auth requirements, request body shape, response shape
- **Schema changes** — new tables, new columns, migration file path
- **Breaking changes** — anything the mobile app must handle differently
- **Auth notes** — any new permission requirements or JWT claim changes
- **Migration notes** — whether a migration must run before the mobile app can use the new endpoints

Be explicit enough that a stak-app agent can implement the mobile side without asking follow-up questions.

## Step 2: Transition the file

1. Update the CR file: fill in the Platform Implementation Notes section, set `status: awaiting-mobile`, set `updated: {today}`
2. Rename: `cr-{id}-platform-in-progress.md` → `cr-{id}-awaiting-mobile.md`

## Step 3: Confirm

```
CR ready for mobile: ../agent-backbone/messages/cr-{id}-awaiting-mobile.md

Platform Implementation Notes written:
{brief bullet summary of what was documented}

Switch to your stak-app session and run /cr-inbox to pick this up.
```
