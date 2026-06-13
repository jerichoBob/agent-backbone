---
agent_name: stak-app:main
repo: stak-app
status: active
joined: 2026-06-13T22:04:36Z
updated: 2026-06-13T22:04:36Z
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

<!-- To be filled in by /backbone-leave -->
