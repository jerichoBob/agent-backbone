# /cr-done — Signal mobile implementation complete

Use this command from **stak-app** after implementing the mobile side of a change request.

## Pre-flight check

Find the in-progress CR for this session:

```bash
ls ../agent-backbone/messages/cr-*-mobile-in-progress.md 2>/dev/null
```

If none found: "No CR is currently claimed as mobile-in-progress. Run /cr-inbox first."

If multiple found: list them and ask the developer which one to complete.

## Step 1: Fill in Mobile Implementation Notes

Read the CR file. Then write the **Mobile Implementation Notes** section with:

- **Files changed** — which source files were added or modified
- **API calls wired** — which new endpoints are now being called and from where
- **UI changes** — any screens, components, or hooks added/modified
- **Tests** — test files added and what they cover
- **Known gaps** — anything deferred or not yet handled

## Step 2: Transition the file

1. Update the CR file: fill in Mobile Implementation Notes, set `status: complete`, set `updated: {today}`
2. Rename: `cr-{id}-mobile-in-progress.md` → `cr-{id}-complete.md`

## Step 3: Confirm

```
CR complete: ../agent-backbone/messages/cr-{id}-complete.md

Mobile Implementation Notes written:
{brief bullet summary of what was documented}

This CR is now part of the permanent audit trail in agent-backbone/messages/.
```
