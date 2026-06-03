---
agent_name: grostak-api:patient-schema
repo: grostak-v2
status: inactive
joined: 2026-06-03T14:30:00
updated: 2026-06-03T17:45:00
ttl_hours: 4
capabilities:
  - schema-analysis
  - patient-api
  - auth-flow
  - migrations
---

# Current Task

Designing the patient clinical data schema — `doses`, `bloodwork_panels`, `side_effects`, and `stak_score_history` tables. Goal is to get these tables specced with multitenancy baked in from the start so stak-app can start wiring against them.

# Architectural Knowledge

- Tenant isolation pattern: every clinical table needs `tenant_id UUID NOT NULL REFERENCES tenants(id)` — RLS policies enforce this at the DB layer, not in application code
- Clerk JWT flow: `org_id` claim → `tenantMiddleware` → scoped Prisma client. The `authMiddleware` runs first and sets `clerkOrgId` on context; `tenantMiddleware` does the DB lookup
- Current schema gaps vs stak-app needs: `doses`, `bloodwork_panels`, `ai_conversations`, `side_effects`, `stak_score_history`, `progress_photos`, `refill_requests` — none of these exist yet in grostak-v2
- Migration pattern: `packages/db/prisma/migrations/YYYYMMDD_description/` — Prisma handles the SQL generation, but check `schema.prisma` for the source of truth
- RLS policies live in `packages/db/prisma/migrations/` alongside the table migrations — don't forget them

# Learned

- Decided to tackle `refill_requests` first (sent a CR to stak-app:refill-flow) — it's the simplest clinical table and validates the full CR workflow end-to-end
- `doses` table is more complex than it looks — needs to reference both `protocols` and `patients`, and the mobile app expects a `scheduled_at` + `taken_at` pair per dose
- `bloodwork_panels` will need a separate `bloodwork_results` table (one panel, many results) — don't conflate them
- Open question: should `ai_conversations` store full message history or just summaries? The mobile app currently stores full history in Supabase but that may not scale well in a multitenant context
- The archive analysis at `archive/stak-app-architecture-analysis/` has the full list of what stak-app currently reads — read that before designing any new clinical table
