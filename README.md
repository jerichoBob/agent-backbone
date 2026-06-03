# agent-backbone

The connective tissue between two Claude Code agents that would otherwise have to shout across the room.

---

## The problem it solves

`grostak-v2` (the platform) and `stak-app` (the mobile app) share an API contract that's still evolving. A schema change on the platform means a corresponding change in the mobile app. A new endpoint means updated client code. Right now the workflow looks like this:

1. Ask Claude in `stak-app` to analyze what needs to change and why
2. Copy-paste that analysis into a new Claude Code session in `grostak-v2`
3. Implement the platform side
4. Mentally note what changed
5. Switch back to `stak-app`, re-explain what the platform did
6. Implement the mobile side
7. Run tests on both

Steps 2, 4, and 5 are the problem. Context bleeds out. Notes get lost. The agents that did the thinking don't talk to each other — you're the message bus.

This repo fixes that.

---

## What it is

A shared directory that both Claude agents can read and write. No server, no API, no ceremony. Just a well-defined place to put structured coordination messages (change requests) that survive the gap between sessions.

The agents stay in their own repos. You stay in control. But instead of copy-pasting, you run a slash command and the handoff writes itself.

```plaintext
stak-app/              grostak-v2/
    |                       |
    | /cr-send              | /cr-inbox
    |                       | /cr-ready
    +----> agent-backbone/messages/ <----+
                    |
              /cr-inbox (stak-app)
              /cr-done
```

---

## Repo layout

```plaintext
agent-backbone/
├── messages/          # Change request files (the message bus)
├── specs/             # Spec-Driven Development specs for this backbone itself
│   ├── README.md      # Progress tracker — what's been built, what hasn't
│   └── spec-v1-a2a-coordination-backbone.md
├── .claude/
│   ├── commands/      # Slash commands (currently grostak-v2 ops — see note below)
│   ├── scripts/       # Utility scripts spanning both repos
│   ├── context-architecture-relationship.md  # How grostak-v2 and stak-app relate
│   ├── dev-environment-setup.md              # One-time Clerk + tenant setup
│   └── learnings.md                          # Hard-won lessons, read before doing anything non-trivial
├── CLAUDE.md          # Instructions for Claude Code instances working here
└── README.md          # You are here
```

---

## The change request lifecycle

Each coordination event is a markdown file in `messages/`. The filename encodes its state:

```plaintext
cr-{id}-draft.md               ← stak-app wrote it, platform hasn't seen it
cr-{id}-platform-in-progress.md  ← grostak-v2 agent claimed it
cr-{id}-awaiting-mobile.md     ← platform done, mobile side's turn
cr-{id}-mobile-in-progress.md  ← stak-app agent claimed it
cr-{id}-complete.md            ← both sides done
```

Inside each file: problem statement, solution recommendation, platform implementation notes, mobile implementation notes. By the time it's complete, the file is a self-contained record of what changed and why.

---

## Slash commands (in progress)

These commands are being built as part of [spec v1](specs/spec-v1-a2a-coordination-backbone.md):

| Command | Repo | What it does |
|---------|------|--------------|
| `/cr-send` | stak-app | Claude drafts a change request from context and writes it to `messages/` |
| `/cr-inbox` | grostak-v2 | Shows pending CRs, lets you claim one |
| `/cr-ready` | grostak-v2 | Fills in platform implementation notes, signals mobile side |
| `/cr-inbox` | stak-app | Shows platform-ready CRs with implementation notes |
| `/cr-done` | stak-app | Marks complete, writes mobile implementation notes |

---

## Assumed directory layout

This repo expects to live as a sibling to the other two:

```plaintext
~/Play/github_repos/
├── agent-backbone/    ← this repo
├── grostak-v2/        ← platform
└── stak-app/          ← mobile app
```

The slash commands use relative paths (`../agent-backbone/messages/`) — if your layout differs, the pre-flight checks in each command will tell you.

---

## Project context

**grostak-v2** is a multi-tenant healthcare platform. Clinics are tenants. Providers use a Next.js web dashboard. The API is built on Hono. Tenant isolation is enforced via Clerk JWTs (`org_id` claim) and Postgres RLS.

**stak-app** is the patient-facing iOS app. It's currently wired to Supabase directly but is being migrated to call the grostak-v2 API instead. That migration is why cross-repo coordination matters — every new clinical feature (protocols, bloodwork, messaging) needs both sides to move together.

For the full architecture picture, see [`.claude/context-architecture-relationship.md`](.claude/context-architecture-relationship.md).

---

## Changelog

0.1.0

### Release Notes

#### v0.1.0 (2026-06-03)

- feat: initial agent-backbone scaffold with v1 CR workflow and v2 presence/discovery specs [`e326ff8`]
