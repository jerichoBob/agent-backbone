---
agent_name: grostak-v2:main
repo: grostak-v2
status: active
joined: 2026-07-12T20:34:21Z
updated: 2026-07-27T22:00:00Z
ttl_hours: 4
capabilities:
  - notifications
  - mvp-strategy
  - patient-api
  - backbone-coordination
subscriptions: []
---

# Current Task

Completed spec-v64 (stak-app's task-20260727-170148 — score-history compute
500) and its follow-up spec-v65 (deep-dive sweep for the same bug class). Full
picture: `Dose.protocol` and `RefillRequest.protocol` are required Prisma
relations; a nested `select`/`include` throws "Inconsistent query result" for
any dose/refill whose protocol was hard-deleted (a `where` filter on the same
relation is safe — confirmed empirically, behaves like an inner join). Found
and fixed 13 total call sites across 6 files (`score-history.ts`,
`admin-tenants.ts`, `providers/console.ts` x2, `providers/search.ts`,
`cross-tenant-search.ts`). Also self-caught and fixed a correctness
regression in my own v64 fix before it spread: the first pass filtered the
protocol lookup map to `deletedAt: null`, which would have wrongly zeroed out
`formulationCategory` for *soft*-deleted (not hard-deleted) protocols,
breaking rotation scoring — fixed to fetch protocols unfiltered for the
lookup map specifically. All 12 v65 sites now resolve a "Deleted Protocol"
placeholder instead of crashing. Regression tests added across 4 test files
(1 new). Full suite 56/56 green.

# Architectural Knowledge

- Push notification infra (v30): `PushToken` + `NotificationLog` Prisma models (`packages/db/prisma/schema.prisma`), send logic in `apps/api/src/lib/expo-push.ts` (real `expo-server-sdk`, chunking, retry, dead-token cleanup), delivery trigger `apps/api/src/workers/reminder-scheduler.ts` (polls protocols every 5 min), registration route `POST /patients/me/push-token`, read-back `GET /patients/me/notifications`.
- Also confirmed UC-X02 (patient onboarding) is OBE — self-registration via invite token was replaced by provider-invite-via-magic-link (v52, spec-v23). mvp-strategy docs updated 2026-07-12.
- Per-protocol `reminderTime` / `reminderEnabled` fields drive both the server worker and (separately) the stak-app local scheduler — these are two parallel systems covering the same reminders.

# Learned

<!-- To be filled in by /backbone-leave -->
