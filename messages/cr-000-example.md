---
id: "000"
status: complete
created: 2026-06-03
updated: 2026-06-03
source_repo: stak-app
title: "Example: Add refill request endpoint"
affected_endpoints:
  - POST /api/refills
  - GET /api/refills/:id
affected_tables:
  - refill_requests
---

# Problem Statement

The mobile app needs to allow patients to submit refill requests for their current protocol medications. Currently there is no endpoint for this — the stak-app would need to write directly to Supabase, which bypasses tenant isolation and audit logging.

# Solution Recommendation

Add a `POST /api/refills` endpoint to grostak-v2 that accepts a `{ medication_id, notes }` body, creates a `refill_requests` row scoped to the authenticated patient's tenant, and returns the created record. Add a `GET /api/refills/:id` for status polling.

# Platform Implementation Notes

<!-- Filled in by grostak-v2 agent via /cr-ready -->

**Endpoints added:**

- `POST /api/refills` — requires `Authorization: Bearer <clerk-jwt>` with `org_id` claim. Body: `{ medication_id: string, notes?: string }`. Returns `{ id, status: "pending", created_at }`.
- `GET /api/refills/:id` — returns full refill record. 404 if not found in tenant scope.

**Schema:**

```sql
CREATE TABLE refill_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  patient_id UUID NOT NULL,
  medication_id UUID NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Migration:** `packages/db/prisma/migrations/20260603_add_refill_requests/`

**Breaking changes:** None. New tables, new routes.

**Auth:** Standard tenant middleware — `clerk_org_id` → `tenant_id` resolution applies. RLS policy added: patients can only read their own refill requests.

# Mobile Implementation Notes

<!-- Filled in by stak-app agent via /cr-done -->

**Files changed:**

- `src/api/refills.ts` — new API client functions `createRefillRequest()` and `getRefillRequest()`
- `src/screens/RefillScreen.tsx` — wired submit button to `createRefillRequest()`
- `src/hooks/useRefillStatus.ts` — polls `getRefillRequest()` every 30s while status is `pending`

**Test:** `src/__tests__/refills.test.ts` — covers happy path and 404 case.
