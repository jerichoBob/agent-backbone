---
agent_name: stak-app:main
repo: stak-app
status: inactive
joined: 2026-06-13T22:04:36Z
updated: 2026-06-13T22:07:56Z
ttl_hours: 4
capabilities:
  - mobile-react-native
  - patient-api
  - grostak-v2-migration
  - mvp-strategy
subscriptions: []
---

# Current Task

Resuming v20 Phase 5 validation (push token registration against UAT); fixing syncSubscription 500 on UAT; then moving to STORY-023 (mark dose skipped) as sprint priority #1.

# Architectural Knowledge

- stak-app is a React Native + Expo iOS app; backend is exclusively grostak-v2 Hono API (Supabase fully removed)
- Hard constraint: stak-app must not call Clerk SDK for anything except auth token acquisition (sign-in/sign-up). All account management routes through grostak-v2 which calls Clerk Backend API server-side
- Local SQLite (lib/db.ts) is the offline store; sync.ts drives syncAll() to reconcile with grostak-v2
- env switching: APP_ENV=uat → .env.uat → api.grostak-uat.parallax-intelligence.ai; unset → .env.local → 192.168.86.199:3001
- Build path: xcodebuild + xcrun simctl, not npm run ios (Expo devicectl breaks on iOS 26.x betas)
- Metro must be in tmux session 'metro'; kill and restart when switching envs
- Simulator on secondary display: content group y=-1093, all osascript tap y-coords are negative
- osascript keyboard/mouse actions must be in a single script block — splitting causes focus loss to terminal
- syncSubscription is 500ing on UAT (GET /patients/me/subscription) — under investigation
- initDb race condition fixed: _initPromise guard added to prevent concurrent migration runs (duplicate column: injection_site)
- Billing model: patient FREE/PRO subscription GONE from gv2 v1.48.1. AI Coach gated by clinic tier (GROWTH+), not patient sub. Do NOT wire patient billing UI.
- spec-v20 Phases 1-4 complete and committed; Phase 5 (manual UAT validation) in progress
- Per-step error logging added to syncAll() to identify which step 500s

# Learned

- Fixed concurrent `initDb()` race: added `_initPromise` guard in `lib/db.ts` — prevents duplicate ALTER TABLE errors (`injection_site` column) when two callers hit `initDb` before migrations complete
- Added per-step error logging to `syncAll()` in `lib/sync.ts` — Metro now shows `syncAll step [syncSubscription] failed` so the failing endpoint is immediately visible
- Identified `syncSubscription` (GET /patients/me/subscription) as the UAT 500 — not yet fixed; needs investigation in grostak-v2
- v20 Phase 5 still blocked: UAT sign-in works (app reaches Today screen) but syncAll 500s on subscription endpoint before push token registration fires
- osascript simulator driving on secondary display: content group y=-1093, coords are negative-y; Cmd+Left rotates the simulator (don't use for back nav); all actions must be one atomic block
- Backbone inbox had a new message from grostak-v2 (story-status-update-20260613-211914): applied and archived; specs/README.md updated with gv2 v1.48.1 status — patient FREE/PRO subscription gone, AI Coach is clinic-tier only
- Branch `feat/grostak-v2-migration` pushed: 5 commits ahead of previous push (db fix, sync logging, backbone commands reinstall, story status map update, run-ios skill)
- Open: syncSubscription 500 on UAT needs grostak-v2 investigation before v20 Phase 5 can complete
- Open: v12 (Onboarding Hang Fix) spec needs scope-update pass — written against Supabase, now uses Clerk + grostak-v2
