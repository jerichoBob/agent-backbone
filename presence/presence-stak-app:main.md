---
agent_name: stak-app:main
repo: stak-app
status: active
joined: 2026-06-10T18:27:39Z
updated: 2026-06-10T18:27:39Z
ttl_hours: 4
capabilities:
  - mobile-react-native
  - patient-api
  - grostak-v2-migration
  - mvp-strategy
subscriptions: []
---

# Current Task

Starting new session. mvp-strategy Stage 5 complete (CHECKLIST_FINAL.md produced). Next up: spec-v18 Phases 2–7 (injection_site end-to-end — SQLite migration, API client contract, write path, sync read path, downstream verification, regression test). Also need to pick up any messages from grostak-v2 re: v29/v30 endpoint contracts.

# Architectural Knowledge

- stak-app is a React Native + Expo iOS app; backend is exclusively grostak-v2 Hono API (migration from Supabase in progress)
- Hard constraint: stak-app must not call Clerk SDK for anything except auth token acquisition (sign-in/sign-up). All account management routes through grostak-v2 which calls Clerk Backend API server-side
- Local SQLite (lib/db.ts) is the offline store; sync.ts drives syncAll() to reconcile with grostak-v2
- env switching: APP_ENV=uat → .env.uat → api.grostak-uat.parallax-intelligence.ai; unset → .env.local → 192.168.86.199:3001
- spec-v18 exists in stak-app (specs/spec-v18-injection-site-field-drop.md) — grostak-v2 Phase 1 complete (commit d99d3ec), UAT deployed. stak-app Phases 2–7 pending.
- grostak-v2 has shipped v29 (patient account mgmt: email/password/delete/export), v30 (notifications infra), v32 (dose status SKIPPED, WeightLog model, pausedAt) — stak-app needs to wire these
- mvp-strategy: Stages 0–5 complete. CHECKLIST_FINAL.md: 46 MVP stories, 6 GTM. Critical blockers: STORY-005, STORY-023, STORY-042/043, STORY-064, STORY-073

# Learned

<!-- To be filled in by /backbone-leave -->
