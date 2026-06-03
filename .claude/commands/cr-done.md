# /cr-done — Close out a change request

Use this command after the sending agent has applied the changes from an `awaiting-response` CR.

## Pre-flight check

Find CRs awaiting response that were originally sent by this agent:

```bash
ls ../agent-backbone/messages/cr-*-awaiting-response.md 2>/dev/null
```

Read each file's frontmatter. Show only those where `from` matches this session's agent name.

If none found: "No CRs are awaiting your response."

If multiple found: list them and ask which one to close.

## Step 1: Fill in Follow-up Notes

Read the CR file. Write the **Follow-up Notes** section with:

- **Files changed** — source files added or modified
- **What was wired** — which new endpoints, schemas, or APIs are now in use
- **Tests** — test files added and what they cover
- **Known gaps** — anything deferred

## Step 2: Transition the file

1. Fill in the Follow-up Notes section
2. Set `status: complete`, `updated: {today}`
3. Rename: `cr-{id}-awaiting-response.md` → `cr-{id}-complete.md`

## Step 3: Confirm

```
CR complete: ../agent-backbone/messages/cr-{id}-complete.md

Follow-up Notes written:
{brief bullet summary}

This CR is now part of the permanent audit trail in agent-backbone/messages/.
```
