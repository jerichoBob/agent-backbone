# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo is a coordination backbone for two sibling projects:

- `../grostak-v2/` — the backend platform (Hono API, Next.js web, Postgres via Prisma, multi-tenant)
- `../stak-app/` — the patient-facing iOS mobile app (Expo/React Native)

It holds no application code. Its role is shared context, cross-project slash commands, coordination specs, and utility scripts that span both repos.

## What lives here

- `.claude/commands/` — backbone slash commands (publish, inbox, join, leave, complete, subscribe, etc.)
- `messages/` — active message bus (pending and claimed messages)
- `messages/types/` — message type registry (cr, task, and future types)
- `messages/archive/` — completed messages (moved here by /backbone-complete)
- `presence/` — agent registry (who's active, what they're working on, their capabilities)
- `.claude/context-architecture-relationship.md` — canonical explanation of how grostak-v2 and stak-app relate
- `.claude/learnings.md` — captured lessons and correction rules (read before doing anything non-trivial)
- `specs/` — SDD specs for this backbone itself (v1: CR workflow, v2: presence/discovery, v3: generic message bus)
- `tests/` — lifecycle tests (cr-workflow, presence-lifecycle, message-bus — 124/124 passing)

## Architecture: grostak-v2 ↔ stak-app

The mobile app (`stak-app`) is patient-facing. It currently talks directly to Supabase but is being rewired to call `grostak-v2`'s Hono API. The platform (`grostak-v2`) is the new multi-tenant backend that clinics use via a provider web dashboard.

Tenant resolution: every API request carries a Clerk JWT with an `org_id` claim → `tenantMiddleware` looks up `tenants WHERE clerk_org_id = $org_id` → returns a scoped DB client with RLS enforced. The `clerk_org_id` field is the authoritative Clerk↔tenant link, not the slug.

The cross-project coordination problem: schema changes on the platform side require corresponding changes in the mobile app. This repo exists to make that coordination explicit and trackable rather than copy-pasted between sessions.

## Backbone commands (run from any repo with commands installed)

| Command | Purpose |
|---------|---------|
| `/backbone-join` | Register this session, see who else is active |
| `/backbone-publish` | Draft and send a message (cr, task, or any registered type) |
| `/backbone-inbox` | See messages addressed to you, claim one to work on |
| `/backbone-complete` | Write completion notes, archive the message |
| `/backbone-subscribe` | Subscribe to a topic (messages to that topic appear in your inbox) |
| `/backbone-unsubscribe` | Remove a topic subscription |
| `/backbone-leave` | Mark inactive, write what you learned |
| `/backbone-roster` | Show all agents (active/stale/inactive) |

Install commands into a project repo: `bash ../agent-backbone/scripts/install-cr-commands.sh`

## Learnings

Read `.claude/learnings.md` before any non-trivial task. It contains hard-won rules about Docker build args, seed pipeline ordering, mock-free testing, and tool invocation gotchas.
