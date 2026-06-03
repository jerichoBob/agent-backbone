# /cr-ready — Signal implementation complete, hand back to sender

Use this command after implementing the changes described in a claimed change request.

## Pre-flight check

Find the in-progress CR owned by this session:

```bash
ls ../agent-backbone/messages/cr-*-in-progress.md 2>/dev/null
```

If none found: "No CR is currently in-progress. Run /cr-inbox first."

If multiple found: list them and ask which one to complete.

## Step 1: Fill in Implementation Notes

Read the CR file. Write the **Implementation Notes** section with enough detail that the sending agent can act on it without follow-up questions:

- **What was built** — endpoints added/modified with full signatures, schema changes, migration paths
- **Breaking changes** — anything the sender must handle differently
- **Auth changes** — new permission requirements or token claim changes
- **Known gaps** — anything deferred or intentionally out of scope

## Step 2: Transition the file

1. Fill in the Implementation Notes section
2. Set `status: awaiting-response`, `updated: {today}`
3. Rename: `cr-{id}-in-progress.md` → `cr-{id}-awaiting-response.md`

## Step 3: Confirm

```
CR ready for {from-agent}: ../agent-backbone/messages/cr-{id}-awaiting-response.md

Implementation Notes written:
{brief bullet summary}

The sender ({from}) can now run /cr-inbox to pick this up.
```
