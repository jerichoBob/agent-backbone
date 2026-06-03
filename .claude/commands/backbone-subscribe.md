# /backbone-subscribe — Subscribe to a topic

Use this command to add a topic to this session's subscription list. Messages published with that topic will appear in `/backbone-inbox`.

## Pre-flight check

Find this session's presence record in `../agent-backbone/presence/`. If none exists:
> "No presence record found. Run /backbone-join first."

## Step 1: Determine the topic

If a topic was passed as an argument (e.g. `/backbone-subscribe patient-api`), use it directly.

Otherwise, show any active topic messages in the backbone as hints, then ask:

```
Topic to subscribe to? (e.g. patient-api, schema-changes, available)
```

## Step 2: Update the presence record

Read the current presence file. Add the topic to the `subscriptions` list in frontmatter (create the field if absent). Avoid duplicates.

```yaml
subscriptions:
  - patient-api
  - schema-changes
```

Write `updated: {today}` timestamp.

## Step 3: Confirm

```
Subscribed: {agent_name} → topic "{topic}"

Active subscriptions: {full list}

Messages published to "{topic}" will now appear in /backbone-inbox.
```
