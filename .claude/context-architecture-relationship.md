# Architecture Relationship: stak-app ↔ grostak-v2

- **`stak-app`** (`../stak-app/`) — patient-facing iOS app (Expo/React Native), currently talking directly to Supabase; being rewired to call grostak-v2's Hono API
- **`grostak-v2`** (`../grostak-v2/`) — multi-tenant backend platform (Hono API, Next.js web, Postgres/Prisma); clinics use the provider web dashboard to manage patient protocols, bloodwork, etc.

## Why this backbone exists

Schema and API changes on the grostak-v2 side require coordinated changes in stak-app. Without explicit tracking, those dependencies get copy-pasted between sessions or dropped. This repo makes cross-project coordination visible and trackable.

## Tenant resolution (grostak-v2)

Every API request carries a Clerk JWT with an `org_id` claim → `tenantMiddleware` looks up `tenants WHERE clerk_org_id = $org_id` → returns a scoped DB client with RLS enforced. The `clerk_org_id` field is the authoritative Clerk↔tenant link.
