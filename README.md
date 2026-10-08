# agent-backbone

A persistent coordination layer for Claude Code agents working across multiple repos.

---

## The problem it solves

When you're working on a system split across multiple repos (`grostak-v2` platform + `stak-app` mobile), cross-repo coordination is manual copy-paste. Schema changes on the platform require mobile app updates. New endpoints need client code. The workflow currently looks like this:

1. Ask Claude in `stak-app` to analyze what needs to change
2. Copy-paste that analysis into a new Claude session in `grostak-v2`
3. Implement the platform side
4. Mentally note what changed
5. Switch back to `stak-app`, re-explain what the platform did
6. Implement the mobile side
7. Run tests on both

Steps 2, 4, and 5 are the problem. Context bleeds out. Notes get lost. The agents that did the thinking don't talk to each other — you're the message bus.

This repo fixes that with a generic message bus + presence/discovery system.

---

## What it is

A shared directory that multiple Claude agents can read and write. No server, no API, no ceremony. Just a well-defined place for:

- **Structured messages** — change requests, task assignments, notifications (any type you define)
- **Agent presence** — who's working on what, where, with what capabilities
- **Persistent context** — messages survive session boundaries; agents can pick up where others left off

The agents stay in their own repos. You stay in control. But instead of copy-pasting, you run a slash command and the coordination writes itself.

```text
stak-app/                    grostak-v2/
    |                             |
    | /backbone-join              | /backbone-join
    | /backbone-publish           | /backbone-inbox
    |                             | /backbone-complete
    +-----> agent-backbone/ <-----+
                |
          ├─ messages/        ← active message bus
          ├─ presence/        ← agent registry
          └─ archive/         ← completed work
```

---

## Repo layout

```plaintext
agent-backbone/
├── messages/          # Active message bus (pending & claimed messages)
│   ├── types/         # Message type schemas (cr, task, etc.)
│   └── archive/       # Completed messages
├── presence/          # Agent registry (who's online, what they're working on)
├── specs/             # Spec-Driven Development specs for this backbone itself
│   ├── README.md      # Progress tracker — what's been built, what hasn't
│   ├── spec-v1-a2a-coordination-backbone.md
│   ├── spec-v2-agent-presence-and-discovery.md
│   └── spec-v3-generic-message-bus.md
├── scripts/           # Installation and setup utilities
│   └── install-backbone-commands.sh
├── tests/             # Lifecycle and workflow tests
│   ├── test-cr-workflow.sh
│   ├── test-message-bus.sh
│   └── test-presence-lifecycle.sh
├── .claude/
│   ├── commands/      # Backbone slash commands (install these to your project repos)
│   ├── context-architecture-relationship.md  # How grostak-v2 and stak-app relate
│   ├── dev-environment-setup.md              # One-time Clerk + tenant setup
│   └── learnings.md                          # Hard-won lessons
├── CLAUDE.md          # Instructions for Claude Code instances working here
└── README.md          # You are here
```

---

## Message lifecycle

Each coordination event is a markdown file in `messages/`. The filename encodes type and state:

```plaintext
{type}-{id}-pending.md     ← published, waiting to be claimed
{type}-{id}-claimed.md     ← agent claimed it, working on it
{type}-{id}-complete.md    ← done, moved to messages/archive/
```

Examples:

```plaintext
cr-20260603-143022-pending.md      ← change request awaiting platform team
task-20260604-091500-claimed.md    ← task assignment in progress
```

Inside each file: YAML frontmatter (routing, timestamps, metadata) + prose sections defined by the message type schema. By the time it's complete and archived, it's a self-contained record of what was requested, who did it, and what was done.

---

## Slash commands

These commands are installed to your project repos (grostak-v2, stak-app, etc.) via symlinks:

### Core Message Bus

| Command | What it does |
|---------|--------------|
| `/backbone-publish` | Draft and publish a message (any type: cr, task, etc.) with direct or topic routing |
| `/backbone-inbox` | See and claim messages addressed to you (direct messages + subscribed topics) |
| `/backbone-complete` | Fill completion notes, mark done, archive the message |
| `/backbone-subscribe` | Subscribe to a topic (messages published to that topic appear in your inbox) |
| `/backbone-unsubscribe` | Remove a topic subscription |

### Presence & Discovery

| Command | What it does |
|---------|--------------|
| `/backbone-join` | Register this session as an agent (shows roster of active/stale/inactive agents) |
| `/backbone-leave` | Mark yourself inactive, write learned summary |
| `/backbone-roster` | Show active agents (name, repo, task, capabilities) and recent activity |

### Installation

From any project repo:

```bash
bash ../agent-backbone/scripts/install-backbone-commands.sh
```

This symlinks `.claude/commands/backbone-*.md` from agent-backbone into your repo's `.claude/commands/` directory.

---

## Running over git (v5)

By default every agent shares one disk. To let agents on different machines exchange messages, set `transport=git` in `backbone.config` (per machine, never committed) and point `../agent-backbone/` at a private repo or an orphan `backbone` branch. Publish, claim, complete, join and leave then pull first and push after; two agents claiming at once resolve through git's push rejection, so exactly one wins. Receivers are told through a SessionStart count, a Monitor poll while a session is open, and a 5-minute no-ack chat ping from the sender. Messages are treated as untrusted requests and bodies that look like secrets are refused. Default and opt-out: leave the setting out, or `transport=local`, and nothing changes.

Setup, hook snippet, roster format and remote access-control advice: [`docs/git-transport.md`](docs/git-transport.md). Status: [spec v5](specs/spec-v5-git-transport-and-notification.md) (14 of 17 tasks done; Windows verification and the first live exchange are open).

## Message types

Message types are defined in `messages/types/`. Each type has a schema file that defines its frontmatter fields and prose sections.

| Type | Schema | Purpose |
|------|--------|---------|
| `cr` | [messages/types/cr.md](messages/types/cr.md) | Change request — coordinate schema/API changes across repos |
| `task` | [messages/types/task.md](messages/types/task.md) | Task assignment — delegate discrete work to another agent |
| `feedback` | [messages/types/feedback.md](messages/types/feedback.md) | Bug reports, ideas, questions about the backbone itself |

To add a new type, write a schema file in `messages/types/{type}.md`. No command changes needed — `/backbone-publish` reads the registry dynamically.

---

## Sending feedback to the backbone

The backbone is itself a message recipient. From any repo, any agent can report a bug, propose an improvement, or ask a question:

```
/backbone-publish --type feedback
```

Feedback messages route to `topic: backbone-meta`. The backbone maintainer session — whoever has joined as `agent-backbone:maintainer` — is auto-subscribed to that topic and sees all feedback in `/backbone-inbox`.

**To become the maintainer:** open a session in `agent-backbone/` and run `/backbone-join`. When the working directory is `agent-backbone`, the command suggests `agent-backbone:maintainer` as the name and auto-subscribes to `backbone-meta`.

```plaintext
stak-app/            grostak-v2/         agent-backbone/
    |                     |                    |
    | /backbone-publish   | /backbone-publish   | /backbone-join
    |   --type feedback   |   --type feedback   |   (as maintainer)
    |                     |                    |
    +------> topic: backbone-meta <------------+
                                    /backbone-inbox shows feedback
```

---

## Development status

See [specs/README.md](specs/README.md) for the full spec tracker.

| Spec | Status | Progress |
|------|--------|----------|
| v1: A2A Coordination Backbone | 🔄 In Progress | 22/23 tasks |
| v2: Agent Presence & Discovery | 🔄 In Progress | 17/18 tasks |
| v3: Generic Message Bus | 🔄 In Progress | 22/23 tasks |
| v4: HCI/UX Observability Layer | 💡 Idea | 0/0 tasks |

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

0.1.2

### Release Notes

#### v0.1.2 (2026-10-07) — author: robert.w.seaton.jr@gmail.com

- chore: untrack local messages [`ac6207b`]

#### v0.1.1 (2026-10-06) — author: robert.w.seaton.jr@gmail.com

- docs: add story status sync protocol and message type [`d84de76`]
- specs: add v5 transport setting and message tracking rule [`e8735f8`]
- chore: stop tracking live messages [`3f55085`]
- chore: sync presence records [`d8a9912`]

#### v0.1.0 (2026-06-06)

- feat: v3 generic message bus with type registry, backbone-* commands, archive, tests [`b0224bd`]
- feat: v2 agent presence and discovery with join/leave/roster commands [`d61715d`]
- feat: initial agent-backbone scaffold with v1 CR workflow spec [`e326ff8`]
