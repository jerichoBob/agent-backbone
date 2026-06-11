---
agent_name: grostak-v2:main
repo: grostak-v2
status: inactive
joined: 2026-06-09T16:04:26Z
updated: 2026-06-10T18:22:09Z
ttl_hours: 4
capabilities:
  - mvp-strategy
  - tenant-architecture
  - patient-api
  - backbone-coordination
subscriptions: []
---

# Current Task

Stage 5 (PRIORITIZE) complete — `CHECKLIST_FINAL.md` produced with 95 stories across MVP/Beta/GTM/Backlog tiers. Stage 6 (EMIT) is next. Also fixed backbone timestamp bug (agents were writing midnight UTC instead of real time) — fix committed to agent-backbone and reinstalled in both repos.

# Architectural Knowledge

- Multi-tenant clinical platform: Hono + Prisma + Postgres RLS. Tenant identity resolved from Clerk JWT — never from request params.
- `tenant = clinic` (UNRES-002 resolved). Location is a sub-entity within a tenant (FK → Tenant). No cross-tenant Owner identity architecture needed — multi-location reporting is within-tenant aggregation grouped by Location. New `Location` model required.
- B2B billing: PB&J charges clinics (STARTER/GROWTH/SCALE/ENTERPRISE). Patient subscription (FREE/PRO) deprecated. AI coaching = GROWTH+ tier. Stripe billing deferred to Beta — first pilots on manual invoicing.
- MVP strategy: Stages 0–5 complete. 95 stories: 76 MVP (56 FUNCTIONAL, 20 ABSENT/PARTIAL), 4 Beta, 3 GTM, 12 Backlog. Zero COMPLETE (conservative threshold — requires integration test).
- Key MVP gaps: UC-X01 notifications (zero infra), UC-X02 patient onboarding (Clerk-invisible, entirely absent), UC-O05 Location model (new), UC-O03 business reports (unblocked by location model resolution).
- Hard constraint: UC-X02 — Clerk must be completely transparent to patients. All onboarding/account mgmt within GroStak/Stak app.
- Pre-launch gates: LLC, EIN, AWS BAA, RDS encryption, audit logging, HIPAA notices, clinic BAA template — all required before real patient data. See `mvp-strategy/PRE_LAUNCH_GATES.md`.
- Backbone timestamp fix: `backbone-join` and `backbone-leave` now shell out `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamps — committed to agent-backbone @ 78152cc.
- Zod v4 now direct dep of `apps/api` — `doses.ts` is the reference validation pattern.

# Learned

- Implemented v29 (patient account management): `PATCH /patients/me/email`, `PATCH /patients/me/password`, `DELETE /patients/me/account`, `POST /patients/me/data-export` — all wired through `patientAuthMiddleware`, Clerk calls server-side only
- Implemented v30 (notifications infrastructure): `PushToken` + `NotificationLog` schema, push-token routes, `reminder-scheduler.ts` worker (setInterval 5min), `expo-push.ts` with retry + `DeviceNotRegistered` token cleanup, `GET /patients/me/notifications`
- Implemented v32 (protocol & dose gaps): `Dose.status` (LOGGED/SKIPPED), `WeightLog` model, `pausedAt` auto-set on status transitions (server-authoritative), dose soft-delete
- Gotcha: migration `20260610171334` dropped `schedule_times` DEFAULT — raw `prisma.protocol.create()` in tests must now pass `scheduleTimes: []` explicitly or it throws P2011
- Gotcha: `patientClerkUserId` must be set in `ContextVariableMap` and by `patientAuthMiddleware` for email/password routes to call Clerk Backend API; `clerkUserId` key is not available in patient context
- README Quick Status table was badly drifted (17 rows wrong); `/sdd-specs --verify` corrected all counts — notably v12 was false-positive `42/42 Complete`, actually `37/40 In Progress` (3 tasks genuinely unimplemented: API config strip, UAT seed comment, tenant settings UI toggle)
- Open: v29 Clerk success/error paths (email change, password change, OAuth guard, post-delete 401) all require live Clerk test user — blocked until stak-app specs patient auth flows and `setup-test-env.sh` is run with real credentials
- Open: v30 `DeviceNotRegistered` receipt path requires real Expo push token from a test device — synthetic tokens fail at `Expo.isExpoPushToken()` before any network call, so this path cannot be exercised without stak-app cooperation
- Message drafted for stak-app with full v29/v30 endpoint contracts + specific asks for E2E test coordination — ready to send once stak-app is active on backbone
