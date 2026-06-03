# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo is a coordination backbone for two sibling projects:

- `../grostak-v2/` — the backend platform (Hono API, Next.js web, Postgres via Prisma, multi-tenant)
- `../stak-app/` — the patient-facing iOS mobile app (Expo/React Native)

It holds no application code. Its role is shared context, cross-project slash commands, coordination specs, and utility scripts that span both repos.

## What lives here

- `.claude/commands/` — slash commands for grostak-v2 operations (deploy, test, db-extract, etc.)
- `.claude/scripts/` — utility scripts (seed provisioning, data exports, infra setup)
- `.claude/context-architecture-relationship.md` — canonical explanation of how grostak-v2 and stak-app relate
- `.claude/dev-environment-setup.md` — one-time Clerk + tenant provisioning steps
- `.claude/learnings.md` — captured lessons and correction rules (read before doing anything non-trivial)
- `specs/` — SDD specs for cross-project coordination features (this backbone itself)

## Architecture: grostak-v2 ↔ stak-app

The mobile app (`stak-app`) is patient-facing. It currently talks directly to Supabase but is being rewired to call `grostak-v2`'s Hono API. The platform (`grostak-v2`) is the new multi-tenant backend that clinics use via a provider web dashboard.

Tenant resolution: every API request carries a Clerk JWT with an `org_id` claim → `tenantMiddleware` looks up `tenants WHERE clerk_org_id = $org_id` → returns a scoped DB client with RLS enforced. The `clerk_org_id` field is the authoritative Clerk↔tenant link, not the slug.

The cross-project coordination problem: schema changes on the platform side require corresponding changes in the mobile app. This repo exists to make that coordination explicit and trackable rather than copy-pasted between sessions.

## Key commands (run from grostak-v2/)

| Task | Command |
|------|---------|
| Local deploy (full Docker pipeline) | `bash scripts/local-docker-run.sh` |
| UAT deploy | `bash scripts/uat-deploy-app.sh` |
| Run all tests (local) | `bash tests/run-all.sh` |
| DB snapshot | `tsx scripts/db-extract.ts --env local` |
| Refresh AWS deploy creds | `bash scripts/assume-deploy-role.sh` |

Slash commands for these are in `.claude/commands/` and should be run from the `grostak-v2` repo context.

## Learnings

Read `.claude/learnings.md` before any non-trivial task. It contains hard-won rules about Docker build args, seed pipeline ordering, mock-free testing, and tool invocation gotchas.
