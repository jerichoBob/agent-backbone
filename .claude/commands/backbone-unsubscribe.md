# /backbone-unsubscribe — Remove a topic subscription

Use this command to remove a topic from this session's subscription list.

## Pre-flight check

Find this session's presence record in `../agent-backbone/presence/`. If none exists:
> "No presence record found. Run /backbone-join first."

## Step 1: Determine the topic

If a topic was passed as an argument (e.g. `/backbone-unsubscribe patient-api`), use it directly.

Otherwise, read the `subscriptions` list from the presence record and display it:

```
Active subscriptions:
  1) patient-api
  2) schema-changes

Remove which? (number or topic name, 'skip' to cancel)
```

If subscriptions list is empty: "No active subscriptions. Nothing to remove."

## Step 2: Update the presence record

Remove the topic from the `subscriptions` list in frontmatter. Write `updated: {today}`.

## Step 3: Confirm

```
Unsubscribed: {agent_name} ✕ topic "{topic}"

Remaining subscriptions: {list, or "none"}
```
