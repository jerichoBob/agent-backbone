---
agent_name: stak-app:main
repo: stak-app
status: active
joined: 2026-06-15T13:54:40Z
updated: 2026-06-15T13:54:40Z
ttl_hours: 4
capabilities:
  - mobile-react-native
  - patient-api
  - grostak-v2-migration
  - mvp-strategy
subscriptions: []
---

# Current Task

MVP readiness evaluation against CHECKLIST_FINAL.md — identifying completed stories, remaining gaps, and additional stories needed. Preparing backbone update to grostak-v2 on current sprint status. spec-v22 (API Environment Indicator) just completed.

# Architectural Knowledge

- stak-app is a React Native + Expo iOS app; backend is exclusively grostak-v2 Hono API (Supabase fully removed)
- Hard constraint: stak-app must not call Clerk SDK for anything except auth token acquisition (sign-in/sign-up). All account management routes through grostak-v2 which calls Clerk Backend API server-side
- Local SQLite (lib/db.ts) is the offline store; sync.ts drives syncAll() to reconcile with grostak-v2
- env switching: APP_ENV=uat → .env.uat → api.grostak-uat.parallax-intelligence.ai; unset → .env.local → 192.168.86.199:3001
- Build path: xcodebuild + xcrun simctl, not npm run ios (Expo devicectl breaks on iOS 26.x betas)
- Metro must be in tmux session 'metro'; kill and restart when switching envs
- Simulator on secondary display: content group y=-1093, all osascript tap y-coords are negative
- osascript keyboard/mouse actions must be in a single script block — splitting causes focus loss to terminal
- Billing model: patient FREE/PRO subscription GONE from gv2 v1.48.1. AI Coach gated by clinic tier (GROWTH+), not patient sub. Do NOT wire patient billing UI.
- spec-v20 (Push Token) Phases 1-4 complete; Phase 5 manual UAT validation pending (syncSubscription 500 was the blocker, may be resolved in gv2 v1.51.3)
- spec-v21 (Mark Dose Skipped) 7/9 — code complete, 2 manual validations remain
- spec-v22 (API Environment Indicator) COMPLETE — 10/10, v1.11.3 shipped
- Agreed sprint priority: STORY-023 → 056 → 042/043 → 005
- grostak-v2 has shipped endpoints for STORY-058/059/064/073/056/023/061 — all waiting on stak-app wiring

# Learned

<!-- To be filled in by /backbone-leave -->
