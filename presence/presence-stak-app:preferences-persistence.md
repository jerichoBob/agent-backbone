---
agent_name: stak-app:preferences-persistence
repo: stak-app
status: active
joined: 2026-09-20T04:30:37Z
updated: 2026-09-20T04:30:37Z
ttl_hours: 4
capabilities:
  - mobile-react-native
  - patient-api
  - healthkit
subscriptions: []
---

# Current Task

Implementing spec-v30 (HealthKit cross-account cache scoping) — code complete, unit tests green, but manual on-device TestFlight verification uncovered a blocking pre-existing bug: `preferences` never persists round-trip against grostak-v2 (client hardcodes it null; server has no column and silently drops it on PATCH). Wrote spec-v37 to track the fix. stak-app-side Phase 1 (pass `preferences` through instead of hardcoding null) is done; about to publish a backbone message requesting the grostak-v2-side schema/endpoint change (Phase 2).

# Architectural Knowledge

- `contexts/AuthContext.tsx`'s `Patient` type (from `GET /auth/session`) had no `preferences` field; `patientToProfile()` hardcoded `preferences: null` — now extracted to `lib/patient-mapping.ts` and passes through `p.preferences ?? null`.
- grostak-v2's `Patient` Prisma model (`packages/db/prisma/schema.prisma`) has no `preferences` column; `PATCH /patients/me/profile` (`apps/api/src/routes/patients/me/index.ts`) only reads `firstName/lastName/email/sex/dateOfBirth/consentAcceptedAt/disclaimerAcceptedAt` off the body — any `preferences` key is silently dropped, no error.
- This blocks `hooks/useHealthSync.ts`'s HealthKit connect state (`isConnected`) and the `auto_fill_checkin`/`show_on_today` toggles from ever persisting against the real backend — not a stak-app bug in isolation, needs both repos.

# Learned

<!-- To be filled in by /backbone-leave -->
