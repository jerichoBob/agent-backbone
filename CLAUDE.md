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
- `scripts/` — install script plus the v5 git-transport helpers (`backbone-sync.sh`, `backbone-poll.sh`, `backbone-session-start.sh`, `backbone-ack-check.sh`, `backbone-secret-check.sh`, `backbone-roster-lookup.sh`)
- `docs/git-transport.md` — how to run the backbone over git (opt-in via `transport=git` in `backbone.config`; default is local disk)
- `tests/` — lifecycle tests (backbone-workflow 43, message-bus 47, presence-lifecycle 38, git-transport 127 — all passing)

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

Install commands into a project repo: `bash ../agent-backbone/scripts/install-backbone-commands.sh`

## Development workflow

When working on this repo:

1. **Specs first** — see `specs/README.md` for the tracker. Each spec has phases and tasks.
2. **Tests after implementation** — run `bash tests/test-backbone-workflow.sh && bash tests/test-message-bus.sh && bash tests/test-presence-lifecycle.sh && bash tests/test-git-transport.sh` before marking tasks complete.
3. **Update docs** — keep README.md and specs/README.md in sync with code changes.

## File purposes

| File/Dir | Purpose |
|----------|---------|
| `messages/` | Active message bus (pending & claimed messages) |
| `messages/types/cr.md` | Change request schema definition |
| `messages/types/task.md` | Task assignment schema definition |
| `messages/archive/` | Completed messages (moved by /backbone-complete) |
| `presence/` | Agent registry (active/stale/inactive agents) |
| `specs/README.md` | Progress tracker for all specs (v1-v4) |
| `tests/test-backbone-workflow.sh` | Backbone workflow test (43 assertions) |
| `tests/test-message-bus.sh` | Generic bus test (47 assertions) |
| `tests/test-presence-lifecycle.sh` | Presence test (38 assertions) |
| `tests/test-git-transport.sh` | Git transport, notification, secret check, install (127 assertions; real git, two clones) |
| `scripts/install-backbone-commands.sh` | Copy (or `--link`) backbone commands and helper scripts into project repos |
| `scripts/backbone-sync.sh` | The only code that touches git; honors `transport=local\|git` |
| `.claude/commands/backbone-*.md` | Backbone slash commands (8 commands) |
| `.claude/commands/correction.md` | Capture lessons into `.claude/learnings.md` |
| `.claude/commands/learning.md` | Alias for correction |

## Learnings

Read `.claude/learnings.md` before any non-trivial task. It contains hard-won rules about Docker build args, seed pipeline ordering, mock-free testing, and tool invocation gotchas.
