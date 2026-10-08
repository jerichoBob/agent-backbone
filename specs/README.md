# Specs — agent-backbone

> Single source of truth for all specifications. Parsed by `specs-parse.sh`.

---

## Quick Status

| Spec | Name | Progress | Status | Owner |
| ---- | ---- | -------- | ------ | ----- |
| v1 | A2A Coordination Backbone | 23/23 | ✅ Complete | <robert.w.seaton.jr@gmail.com> |
| v2 | Agent Presence & Discovery | 18/18 | ✅ Complete | <robert.w.seaton.jr@gmail.com> |
| v3 | Generic Message Bus | 23/23 | ✅ Complete | <robert.w.seaton.jr@gmail.com> |
| v4 | HCI/UX Observability Layer | 0/0 | 💡 Idea | <robert.w.seaton.jr@gmail.com> |
| v5 | Git Transport and Notification | 14/17 | 🔧 In Progress | <robert.w.seaton.jr@gmail.com> |
| v6 | Backbone Simplification and Toolkit Module | 25/40 | 🔧 In Progress | <robert.w.seaton.jr@gmail.com> |

---

## Architecture

> Document key architecture decisions and constraints here.

---

## v1: A2A Coordination Backbone

**Spec**: [spec-v1-a2a-coordination-backbone.md](spec-v1-a2a-coordination-backbone.md)

### Phase 1: Message Schema & Storage

- [x] Define the CR markdown file schema (YAML frontmatter + prose sections)
- [x] Define frontmatter fields: id, status, created, updated, source_repo, title, affected_endpoints, affected_tables
- [x] Define prose sections: Problem Statement, Solution Recommendation, Platform Implementation Notes, Mobile Implementation Notes
- [x] Define filename convention: cr-{id}-{status}.md with status lifecycle
- [x] Create agent-backbone/messages/ directory with README.md explaining schema and lifecycle
- [x] Write example CR file (cr-000-example.md) as documentation

### Phase 2: /cr-send Slash Command (stak-app)

- [x] Create .claude/commands/cr-send.md in the stak-app repo
- [x] Implement draft behavior: Claude drafts CR from context, writes to ../agent-backbone/messages/
- [x] Add pre-flight check that ../agent-backbone/messages/ is accessible
- [x] Output human-readable summary of what was written
- [x] Test the command end-to-end from the stak-app directory

### Phase 3: /cr-inbox and /cr-ready Slash Commands (grostak-v2)

- [x] Create .claude/commands/cr-inbox.md in the grostak-v2 repo (shows draft CRs, claim/rename to platform-in-progress)
- [x] Create .claude/commands/cr-ready.md in the grostak-v2 repo (fills Platform Implementation Notes, renames to awaiting-mobile)
- [x] Ensure cr-inbox prompt includes endpoint signatures, request/response shapes, auth changes
- [x] Test cr-inbox claim flow (file rename + frontmatter update)
- [x] Test cr-ready flow (notes written, file renamed to awaiting-mobile)

### Phase 4: /cr-inbox Slash Command (stak-app)

- [x] Create .claude/commands/cr-inbox.md in the stak-app repo (shows awaiting-mobile CRs, displays Platform Implementation Notes)
- [x] Implement claim flow (renames to mobile-in-progress)
- [x] Create .claude/commands/cr-done.md in stak-app (marks complete, writes Mobile Implementation Notes, renames to complete)
- [x] Test full handoff: platform-ready → mobile picks up → done
- [x] Verify complete CR file contains full audit trail (both sides' notes)

### Phase 5: Tests & Validation

- [x] Add tests/test-cr-workflow.sh covering CR lifecycle (create, parse, status transitions, filename/frontmatter consistency)
- [x] Manual end-to-end walkthrough with a real stak-app ↔ grostak-v2 change as the first live CR

---

## v3: Generic Message Bus

**Spec**: [spec-v3-generic-message-bus.md](spec-v3-generic-message-bus.md)

### Phase 1: Message Type Registry

- [x] Create messages/types/ directory with README.md explaining type schema format
- [x] Migrate CR schema into messages/types/cr.md
- [x] Define messages/types/task.md (task assignment schema)
- [x] Update messages/README.md to describe the generic base frontmatter

### Phase 2: Generic Message Frontmatter

- [x] Define shared base frontmatter (id, type, status, routing, from, to, topic, created, updated)
- [x] Update messages/README.md with generic schema and routing modes
- [x] Document backward compat: cr-* files treated as type: cr

### Phase 3: /backbone-publish Command

- [x] Create .claude/commands/backbone-publish.md
- [x] Implement type selection from messages/types/ registry
- [x] Implement direct routing (--to agent-name)
- [x] Implement topic routing (--topic topic-name)
- [x] Read type schema to drive content prompting
- [x] Write to messages/{type}-{id}-pending.md

### Phase 4: /backbone-inbox Command

- [x] Create .claude/commands/backbone-inbox.md
- [x] Scan messages/ (not archive/) for pending files addressed to this agent (direct + topic subscriptions)
- [x] Group results by type in display
- [x] Implement claim flow (rename to claimed, update status)

### Phase 5: /backbone-subscribe and /backbone-unsubscribe Commands

- [x] Create .claude/commands/backbone-subscribe.md (adds topic to presence record subscriptions list)
- [x] Create .claude/commands/backbone-unsubscribe.md (removes topic from subscriptions)
- [x] Update /backbone-join to display active subscriptions in roster

### Phase 6: /backbone-complete Command

- [x] Create .claude/commands/backbone-complete.md
- [x] Find claimed messages for this session, prompt for completion section per type schema
- [x] Update status: complete, write updated timestamp
- [x] Move file to messages/archive/ (create if needed) — removes from active scan path

### Phase 7: Tests & Validation

- [x] Add tests/test-message-bus.sh covering publish, inbox filtering, topic subscriptions, full lifecycle
- [x] Verify tests/test-cr-workflow.sh still passes (backward compat)
- [x] Manual walkthrough: publish a task message, subscribe from another agent, claim and complete

---

## v2: Agent Presence & Discovery

**Spec**: [spec-v2-agent-presence-and-discovery.md](spec-v2-agent-presence-and-discovery.md)

### Phase 1: Presence Schema & Storage

- [x] Define presence record schema (YAML frontmatter + prose sections)
- [x] Define frontmatter fields: id, agent_name, repo, status, joined, updated, ttl_hours, capabilities
- [x] Define prose sections: Current Task, Architectural Knowledge, Learned
- [x] Define filename convention: presence-{agent_name}.md (overwrite on re-join)
- [x] Create agent-backbone/presence/ directory with README.md explaining schema and TTL semantics
- [x] Write example presence file (presence-example.md) as documentation

### Phase 2: /backbone-join Command

- [x] Create .claude/commands/backbone-join.md in agent-backbone
- [x] Implement roster read: render active, stale, and recently-inactive agents on join
- [x] Implement name inference from working directory + task context
- [x] Implement developer confirmation/override of inferred name
- [x] Write presence record to ../agent-backbone/presence/
- [x] Surface capability matches from active agents relevant to current task

### Phase 3: /backbone-leave Command

- [x] Create .claude/commands/backbone-leave.md
- [x] Implement learned section prompt (what was built, decided, open questions)
- [x] Update status to inactive and write updated timestamp
- [x] Test leave flow: presence record updated correctly, learned block present

### Phase 4: /backbone-roster Command

- [x] Create .claude/commands/backbone-roster.md
- [x] Show active agents (name, repo, task, capabilities, time since join)
- [x] Show stale agents with staleness warning
- [x] Show recently inactive agents with learned summary

### Phase 5: Capability Matching

- [x] Add capabilities list to presence frontmatter
- [x] Implement capability overlap scan on /backbone-join
- [x] Surface matching agents as "you may want to consult" hints
- [x] Document common capability tags in presence/README.md

### Phase 6: Tests & Validation

- [x] Add tests/test-presence-lifecycle.sh covering write, TTL staleness, leave update, learned block persistence
- [x] Manual walkthrough with a real dual-repo session (one grostak-v2 + one stak-app agent)

---

---

## v5: Git Transport and Notification

**Spec**: [spec-v5-git-transport-and-notification.md](spec-v5-git-transport-and-notification.md)

### Phase 1: Git sync wrapper and race-safe claim

- [x] Write scripts/backbone-sync.sh with pull and push subcommands
- [x] Route publish, claim, and complete through it when transport=git
- [x] Keep local-disk behavior when transport=local or unset
- [x] Add the backbone.config transport setting (default local) and make the wrapper honor it, including the unreachable-remote error
- [x] Add tests/test-git-transport.sh using two real clones of a local bare repo, including flipping the transport setting

### Phase 2: Notification while a session is open or starting

- [x] Add the SessionStart pending-count hook
- [x] Add a Monitor-based poll script and document starting it from /backbone-join
- [x] Test the poll is silent with no new messages and fires on a new addressed one

### Phase 3: Notification to a closed session

- [x] Define the agent-to-human map and where it lives
- [x] Add the receiver seen marker written by the session-start hook and the poll
- [ ] Add the 5-minute no-ack gchat ping to /backbone-publish (sender and title only) — BLOCKED on the send only: trigger, timer and publish step are built and tested (tests/test-git-transport.sh §9); the /gchat send is unverified because no gchat skill is installed here

### Phase 4: Safety

- [x] Add the secret-pattern check to /backbone-publish
- [x] Add untrusted-message language to CONVENTIONS.md and the inbox display
- [x] Document access control requirements for the remote

### Phase 5: Windows

- [x] Add a copy fallback to the install script when symlinks are unavailable
- [ ] Verify the sync wrapper and Monitor poll on a real Windows machine (Git Bash and WSL) — BLOCKED: needs a real Windows machine; nothing in this environment can verify it

### Phase 6: First live use

- [ ] Use it for a real Bob and Nate exchange and record what no longer had to be relayed — BLOCKED: needs a live exchange between two people on two machines

## v6: Backbone Simplification and Toolkit Module

**Spec**: [spec-v6-backbone-simplification-and-toolkit-module.md](spec-v6-backbone-simplification-and-toolkit-module.md)

### Phase 1: Pluggable notification

- [x] Add `scripts/backbone-notify.sh` implementing the notifier contract without shell interpolation of message text
- [x] Add `notify_command` and `notify_confirm` handling (default `ask`; unset command reports "no notifier configured")
- [x] Add per-project override resolution (`notify_confirm.<project>=`, then machine default, then `ask`) in `backbone-lib.sh`, read only from the machine-local `backbone.config`
- [x] Change `backbone-ack-check.sh` to call the notifier in `auto` and print a `PING` for confirmation in `ask`
- [x] Rename the roster `gchat` column to `notify` across the lookup script, docs and tests
- [x] Write `docs/notify.md` with the contract and an example wrapper for the Radeas gchat `send.py`
- [x] Log each ping attempt (target, id, result, never the body) under `.claude/data/backbone/`
- [x] Add tests covering injection-safe arguments (quotes, `$(...)`, backticks, newlines), `ask` versus `auto`, override precedence, notifier failure, and no body in any output

### Phase 2: Windows-safe filenames

- [x] Define the safe filename function once in `backbone-lib.sh` and use it for presence and seen markers
- [x] Make presence lookups scan `agent_name` instead of building a filename (lib plus the join, leave, roster, subscribe and inbox commands); the safe-name function allows `~`, and an address (`<repo>:<user>`) resolves to all of its session records (`<address>~<suffix>`)
- [x] Add `scripts/backbone-migrate-presence.sh` with dry run, history-preserving renames, and idempotence
- [x] Update the presence-lifecycle and git-transport tests for the new names and add a migration test

### Phase 3: Session hooks

- [x] Extend `backbone-session-start.sh` to register presence, keep the count first, and tell the agent to start the watcher; address is `agent=`/`BACKBONE_AGENT` else `<repo>:<git user slug>` (noted as inferred, refuse if no git user), and each session registers as `<address>~<4-char random>`
- [x] Add `backbone-session-end.sh` that marks presence inactive and pushes in git mode
- [x] Add the hook configuration for both, merged non-destructively into a project's `settings.json`, installed only with the developer's consent
- [x] Add tests: first join, idempotent re-join, end marks inactive, hooks exit 0 on any failure, count remains the first line

### Phase 4: Collapse the commands

- [x] Write `/backbone` with `status`, `join`, `leave`, `subscribe`, `unsubscribe`, `name` and `update`
- [x] Write `/backbone-send` combining publish, secret check and ack timer, keeping the intent question
- [x] Write `/backbone-done` replacing complete
- [x] Update `/backbone-inbox` for the new scripts and keep the untrusted-message display
- [x] Turn the nine old command files into forwarding aliases with a deprecation note (eight aliases: `/backbone-inbox` keeps its name, so it is updated rather than aliased)
- [x] Update the installer, README, CONVENTIONS.md, CLAUDE.md and every test that names a command
- [x] Add a test that every script path referenced by a command file exists, and that each alias forwards
- [ ] Rehearse the Bob and Nate exchange on this machine with two clones and two sessions, and record what had to be relayed by hand in `docs/live-exchange.md` (rehearsal section) — NEXT
- [ ] Run the hook installer and the `/backbone` commands end to end in a scratch project inside a real Claude Code session (scratch `HOME` for anything global), and record the result in `docs/e2e-check.md` — NEXT, after the rehearsal

### Phase 5: Migrate into aidev-toolkit

- [x] Survey aidev-toolkit (`modules/sdd` layout, installer, absolute-path convention, test location) and record findings in Technical Notes before changing anything
- [x] Record the module boundary decision: tooling moves, state and specs stay
- [ ] On a branch of aidev-toolkit, create `modules/backbone/{scripts,skills,templates}` and port the scripts with module-path resolution — NEXT: not blocked. Work happens on a branch in `~/pgh/aidev-toolkit` (same directory as `~/Play/github_repos/aidev-toolkit`)
- [ ] Merge the toolkit's existing `backbone-setup` skill into the new setup flow — BLOCKED on the toolkit branch above; note it must install `backbone.md` too (it globs `backbone-*.md` only)
- [ ] Port the tests into the toolkit's layout and run both repos' suites — BLOCKED on the toolkit branch above
- [ ] Update the toolkit's CLAUDE.md, README and installer; exercise the installer in a scratch `HOME`, never the real `~/.claude` — BLOCKED on the toolkit branch above
- [ ] Cut agent-backbone over: drop per-project script copies, `--link` and the copy manifest, and point commands at the module — BLOCKED on the toolkit module existing
- [ ] Write a rollback note and open the toolkit PR for the developer to review and merge — BLOCKED on the work above; opening a PR is outward-facing, so it waits for the developer

### Phase 6: Live validation (Windows runs only after the migration)

- [ ] Run `tests/test-git-transport.sh` under Git Bash and WSL on a real Windows machine and record the result in `docs/windows-verification.md` — BLOCKED until the migration is done (Windows testing now runs against the toolkit module): needs a real Windows machine (Nate's or Bob's laptop); runbook and empty results table are ready in that file
- [ ] Verify the poll, hooks and install on Windows, including that no colon filenames remain — BLOCKED until the migration is done: same Windows machine; steps are in `docs/windows-verification.md`
- [ ] Run a real Bob and Nate exchange over git and record what no longer had to be relayed in `docs/live-exchange.md` — NOT BLOCKED by the migration: needs Nate (or a second session on a second clone here) to run it; can happen before or after Phase 5. Script and empty record are ready in that file
- [ ] Fix what the above turns up, then close the three open v5 tasks in `specs/README.md` — BLOCKED on the three tasks above

### Phase 7: Cleanup and release (last)

- [ ] Remove the deprecated aliases in the next minor release after they ship (one release, per Open Question 3) — BLOCKED until the release after the one that ships the aliases (0.5.0); remove in 0.6.0
- [ ] Remove leftover scratch files (asking first) and fix any stale counts in docs — PARTLY DONE: doc counts and command names were fixed in Phase 4; scratch-file removal needs your yes first (candidates: v5's `/tmp` files and any `.claude/data` scratch), so nothing was deleted
- [ ] Final documentation pass, version bump, and mark v5 and v6 complete — BLOCKED: v5 and v6 each still have open external tasks, so neither can be marked complete; version bumped to 0.5.0 for the work done so far

---
