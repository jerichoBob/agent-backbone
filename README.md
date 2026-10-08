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
    | (SessionStart hook joins)   | (SessionStart hook joins)
    | /backbone-send              | /backbone-inbox
    |                             | /backbone-done
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
├── docs/              # git transport, notifier, live-exchange and verification runbooks
├── tests/             # Protocol and state tests (tooling tests live in aidev-toolkit)
│   ├── test-backbone-workflow.sh
│   ├── test-message-bus.sh
│   ├── test-presence-lifecycle.sh
│   ├── test-repo-docs.sh
│   └── module-path.sh
├── .claude/
│   ├── commands/      # correction/learning only; the backbone commands ship in aidev-toolkit
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

These commands are installed into your project repos (grostak-v2, stak-app, etc.). Four commands cover the daily work:

| Command | What it does |
|---------|--------------|
| `/backbone-send` | Draft and send a message (any type: cr, task, etc.) with direct or topic routing. Refuses secrets, pushes in git mode, starts the no-ack timer |
| `/backbone-inbox` | See and claim messages addressed to you (direct messages + subscribed topics) |
| `/backbone-done` | Fill completion notes, mark done, archive the message |
| `/backbone` | Everything else, by subcommand: `status` (roster), `join`, `leave`, `subscribe <topic>`, `unsubscribe <topic>`, `name [address]`, `update` |

(`/backbone-setup` bootstraps the backbone from aidev-toolkit.) The old names `/backbone-publish`, `-complete`, `-join`, `-leave`, `-roster`, `-subscribe`, `-unsubscribe` and `-update` still work as forwarding aliases that print a deprecation note, and are removed in 0.6.0.

### Sessions register themselves

With the optional hooks installed (`backbone-install-hooks.sh <project>`, which shows what it adds and asks first), a SessionStart hook registers your session, prints the pending count first, and tells the agent to start the watcher; a SessionEnd hook marks it inactive. You never type `/backbone join`. Writing the "Learned" summary still needs `/backbone leave`, because a hook cannot do that.

**Identity.** Your *address* (`stak-app:bob`) is what others send to; each session is `address~ab12`, so several of your sessions never collide, and a message to the address reaches all of them (the first to claim wins). Without `agent=` in `backbone.config` the address is `<repo>:<git user.name>`; with no git user the hook refuses rather than share a name. Presence filenames use `__` for `:` so Windows can create them; the real name is the `agent_name` inside the file.

### Notification

When a direct message goes unacknowledged for 5 minutes, the sender's session pings the receiver's human through a command you configure (`notify_command=` in the machine-local `backbone.config`). `notify_confirm=ask` (default) shows the exact target and text first; `auto` sends without asking, and can be set per project with `notify_confirm.<project>=`. See [docs/notify.md](docs/notify.md).

### Installation

The commands and scripts are the `backbone` module of [aidev-toolkit](https://github.com/jerichoBob/aidev-toolkit), installed once by `/aid-update` and called by absolute path under `~/.claude/aidev-toolkit/modules/backbone/`. Nothing is copied into your projects. This repo holds the state and the protocol: messages, presence, roster, message-type schemas, specs and runbooks.

From any project repo, in a Claude Code session:

```text
/backbone-setup
```

It clones this repo as `../agent-backbone` if missing, checks the module is installed, and offers the session hooks (it asks before changing `settings.json`). To add the hooks directly: `bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-install-hooks.sh <project>`.

**Upgrading a project that has the old per-project copies:** re-run the hook installer, then delete `.claude/scripts/backbone/`, `.claude/.backbone-copied` and the project's `.claude/commands/backbone*.md` (project copies override the global ones until removed).

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

To add a new type, write a schema file in `messages/types/{type}.md`. No command changes needed — `/backbone-send` reads the registry dynamically.

---

## Sending feedback to the backbone

The backbone is itself a message recipient. From any repo, any agent can report a bug, propose an improvement, or ask a question:

```
/backbone-send --type feedback
```

Feedback messages route to `topic: backbone-meta`. The backbone maintainer session — whoever has joined as `agent-backbone:maintainer` — is auto-subscribed to that topic and sees all feedback in `/backbone-inbox`.

**To become the maintainer:** open a session in `agent-backbone/` and start a session (or run `/backbone join`). When the working directory is `agent-backbone`, the command suggests `agent-backbone:maintainer` as the name and auto-subscribes to `backbone-meta`.

```plaintext
stak-app/            grostak-v2/         agent-backbone/
    |                     |                    |
    | /backbone-send      | /backbone-send      | (hook joins)
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

0.5.0

### Release Notes

#### v0.5.0 (2026-10-08) — author: robert.w.seaton.jr@gmail.com

- feat: pluggable notifier with `ask`/`auto` confirmation, per-project override, ping log and `docs/notify.md`; roster column renamed `notify` [`0022c45`]
- feat: Windows-safe presence and seen-marker filenames, lookups scan `agent_name`, `backbone-migrate-presence.sh` [`0022c45`]
- feat: SessionStart/SessionEnd hooks register and deregister sessions (`<address>~<suffix>` per session); consent-based hook installer [`0022c45`]
- feat: commands collapsed to `/backbone`, `/backbone-send`, `/backbone-inbox`, `/backbone-done`; old names are aliases removed in 0.6.0 [`000c01a`]
- docs: toolkit survey and module boundary for the Phase 6 migration; Windows and live-exchange runbooks [`01cec29`]

#### v0.4.0 (2026-10-07) — author: robert.w.seaton.jr@gmail.com

- feat: add notify_confirm resolution with per-project override [`cfb899a`]
- docs: add v6 Q7 on Google Chat as a message bus [`da3528c`]
- docs: add participant-verification options to v6 Q7 [`5c2eba8`]

#### v0.3.0 (2026-10-07) — author: robert.w.seaton.jr@gmail.com

- feat: add pluggable notifier script with injection-safe env contract [`79d111c`]
- docs: settle v6 Q1 (ask default, per-project override) and add Q6 [`614c14a`]

#### v0.2.0 (2026-10-07) — author: robert.w.seaton.jr@gmail.com

- feat: add git transport, notification helpers, and secret check
- docs: add v6 simplification spec and update v5 tracker

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
