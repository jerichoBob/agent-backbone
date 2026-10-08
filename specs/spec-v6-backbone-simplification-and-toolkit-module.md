---
version: 6
name: backbone-simplification-and-toolkit-module
display_name: "Backbone Simplification and Toolkit Module"
status: draft
created: 2026-10-07
creator: robert.w.seaton.jr@gmail.com
owner: robert.w.seaton.jr@gmail.com
developer: ""
depends_on: [git-transport-and-notification]
tags: [simplification, notification, hooks, windows, toolkit-module, migration]
---

# Backbone Simplification and Toolkit Module

## Why (Problem Statement)

> As a developer who uses the backbone across several projects and machines, I want a handful of commands that mostly run themselves, a notification path that is not tied to one project's chat skill, and the whole thing installed once from aidev-toolkit, so that coordinating with a teammate's agent costs me almost no ceremony.

### Context

- v5 (git transport and notification) is 14 of 17 tasks done. Its three open tasks are external: the chat-ping send, Windows verification, and the first live Bob and Nate exchange. Working through them on 2026-10-07 turned up design problems that belong in a follow-up spec.
- **The ping has no portable sender.** v5 assumed a `/gchat` skill. The only one found is project-local to `~/wgh/radeas-analyst-amplifier/.claude/skills/gchat/` (needs that project's `venv`, an `@radeas.com` OAuth token, and a Chat space ID). `~/pgh/tbts-invoice-automation` has Gmail scripts only. `~/pgh/aidev-toolkit` has only the read-side `gmail-digest`. v5's roster maps agents to an email, but `send.py` needs `spaces/AAAA...`.
- **Two rules conflict on confirmation.** v5's decision (Bob, 2026-10-06) is an automatic ping with no per-ping confirmation. The Radeas gchat SKILL.md says to show the exact space and text and get explicit confirmation before every send. Calling its `send.py` from a script would bypass a safeguard written for that project.
- **Windows cannot hold the presence files.** `presence-stak-app:main.md` contains a colon, which Windows cannot create. This predates v5 and blocks the Windows task.
- **Too many commands.** There are nine backbone command files (complete, inbox, join, leave, publish, roster, subscribe, unsubscribe, update) plus an install script. Join, leave, subscribe and the poll are ceremony a hook can do.
- **Install is per project.** Commands and scripts are copied into every project's `.claude/`, with a `--link` option, a copy fallback and a manifest, to work around symlinks on Windows. aidev-toolkit modules are real file copies installed once under `~/.claude/aidev-toolkit/` and called by absolute path (the `sdd` module works this way), which removes that whole problem.
- v5 also left behind: `/tmp` scratch files, a hook that exists only as a documented snippet, and doc counts that were stale.

---

## What (Requirements)

### User Stories

- **US-1**: As a sender, I want the no-ack ping to go through a command I configure, so the backbone does not depend on any one project's chat skill.
- **US-2**: As a developer, I want to choose per project whether a ping asks me first or sends automatically, so my v5 decision and the Radeas confirmation rule can both hold.
- **US-3**: As a developer on Windows, I want presence and marker files to have names Windows can create.
- **US-4**: As a developer, I want joining and leaving to happen from session hooks, so I never type `/backbone-join`.
- **US-5**: As a developer, I want five commands instead of nine, so I can remember them.
- **US-6**: As a maintainer, I want the tooling installed once as an aidev-toolkit module, so updating it is `/aid-update` and nothing is copied per project.
- **US-7**: As Bob and Nate, we want evidence from a real exchange that this removes manual relaying.

### Acceptance Criteria

- AC-1: Given `notify_command` is set and `notify_confirm=auto`, when a direct message has no ack within the timeout, then the command runs once with the target, sender, title and id supplied as environment variables, and the message body is never passed.
- AC-2: Given `notify_confirm=ask` (the default), when the timeout passes, then nothing is sent until the sender's session shows the exact target and text and the developer approves.
- AC-2a: Given `notify_confirm` set in `backbone.config` as a machine default and `notify_confirm.<project>=` as a per-project override, when a ping is due, then the override for that project wins, else the machine default, else `ask`. Overrides are read only from the machine-local `backbone.config`, never from a file in a project repo.
- AC-3: Given a title containing quotes, `$(...)`, backticks or newlines, when a ping is sent, then the command receives the text unchanged and nothing in it is executed.
- AC-4: Given no `notify_command`, when the timeout passes, then the sender is told there is no notifier configured and nothing is attempted.
- AC-5: The roster's last column is an opaque notify target (for Radeas, a Chat space ID), not an email.
- AC-6: No file the backbone creates has a name containing `: / \ * ? " < > |`. Agent names are stored in file contents, and lookup never depends on the filename.
- AC-7: Existing presence files migrate with one command that supports a dry run, preserves git history, and is safe to run twice.
- AC-8: Given a configured agent name, when a session starts, then presence is registered without any command, the pending count is the first output line, and the agent is told to start the watcher. When the session ends, presence is marked inactive. A failing hook never blocks the session.
- AC-9: The user-facing commands are `/backbone-setup`, `/backbone-send`, `/backbone-inbox`, `/backbone-done` and `/backbone` (status, join, leave, subscribe, unsubscribe, name, update). The nine old names keep working as aliases that forward and print a deprecation note, until the cleanup phase removes them.
- AC-10: Every script path named in a command file exists in the repo, checked by a test.
- AC-11: `tests/test-git-transport.sh` passes under Git Bash and WSL on a real Windows machine, and the result is recorded.
- AC-12: One real Bob and Nate exchange runs over git, and what no longer had to be relayed is recorded.
- AC-13: Backbone tooling is installed from aidev-toolkit's `modules/backbone/` by absolute path. No project holds a copy of the scripts. State (messages, presence, roster) stays out of the toolkit.
- AC-14: All suites in both repos pass after the migration, and the installer was exercised in a scratch `HOME` without touching the real `~/.claude`.

### Out of Scope

- Writing the Radeas-side wrapper around `send.py`. It lives in that repo; this spec documents the contract and an example.
- A hosted always-on agent, message encryption, or signed-commit enforcement (unchanged from v5).
- Automatic "Learned" summaries on session end. That needs the model; a hook cannot write it.
- Changing v1 to v3 file formats or the message state encoding.

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`, which is the single source of truth for progress tracking. `specs-parse.sh` counts from README only.

### Design

- **Notifier contract.** `backbone.config` gains `notify_command=` and `notify_confirm=ask|auto` (default `ask`). A new `backbone-notify.sh` runs the command with `BACKBONE_NOTIFY_TARGET`, `BACKBONE_NOTIFY_TEXT`, `BACKBONE_NOTIFY_FROM`, `BACKBONE_NOTIFY_TITLE` and `BACKBONE_NOTIFY_ID` in the environment. Text is never interpolated into a shell string. Exit 0 means sent.
- **Confirmation.** In `auto`, `backbone-ack-check.sh` calls the notifier itself on timeout. In `ask`, it prints a `PING` line, the sender's session shows the target and text, and runs `backbone-notify.sh` only after approval. This implements v5's "automatic" decision as an opt-in, and leaves projects such as Radeas free to keep `ask`. **Setting resolution:** `notify_confirm=` in `backbone.config` is the machine default; `notify_confirm.<project>=` overrides it for one project (project key is the repo name, matching the `<repo>` in `<repo>:main`). Order: project override, then machine default, then `ask`. Overrides live only in the machine-local config because a file inside a project repo could be changed by anyone with push access to that repo, which would let a teammate switch your machine to `auto`. **Confirmed by Bob (Open Question 1).**
- **Roster.** The last column is renamed `notify` and holds whatever the notifier needs.
- **Filenames.** Presence files are named from a filesystem-safe form of the agent name (`:` becomes `__`). `agent_name` in the frontmatter stays authoritative and readers scan it. Seen markers use the same function. A migration script renames existing files.
- **Hooks.** SessionStart registers presence from the configured agent name (`agent=` or `BACKBONE_AGENT`, default `<repo>:main`), prints the count first, and adds a line telling the agent to start the poll under Monitor (a hook cannot start Monitor itself). SessionEnd marks presence inactive. Neither writes the "Learned" section.
- **Commands.** `/backbone-send` absorbs publish, the secret check and the ack timer. `/backbone-done` replaces complete. `/backbone-inbox` keeps its name. `/backbone` takes subcommands for the rest. Old names become thin aliases.
- **Module.** Tooling moves to `~/pgh/aidev-toolkit/modules/backbone/{scripts,skills,templates}` and is called by absolute path under `~/.claude/aidev-toolkit/modules/backbone/`. The toolkit's existing `backbone-setup` skill is merged into the new setup flow. agent-backbone keeps the specs, conventions, message types, and the reference deployment's state.
- **Ordering.** Behavior changes first, validated live, then the move, then cleanup. Moving a design that has not been used would move its bugs too.

### Phase 1: Pluggable notification

- Add `scripts/backbone-notify.sh` implementing the notifier contract without shell interpolation of message text
- Add `notify_command` and `notify_confirm` handling (default `ask`; unset command reports "no notifier configured")
- Add per-project override resolution (`notify_confirm.<project>=`, then machine default, then `ask`) in `backbone-lib.sh`, read only from the machine-local `backbone.config`
- Change `backbone-ack-check.sh` to call the notifier in `auto` and print a `PING` for confirmation in `ask`
- Rename the roster `gchat` column to `notify` across the lookup script, docs and tests
- Write `docs/notify.md` with the contract and an example wrapper for the Radeas gchat `send.py`
- Log each ping attempt (target, id, result, never the body) under `.claude/data/backbone/`
- Add tests covering injection-safe arguments (quotes, `$(...)`, backticks, newlines), `ask` versus `auto`, override precedence, notifier failure, and no body in any output

### Phase 2: Windows-safe filenames

- Define the safe filename function once in `backbone-lib.sh` and use it for presence and seen markers
- Make presence lookups scan `agent_name` instead of building a filename (lib plus the join, leave, roster, subscribe and inbox commands)
- Add `scripts/backbone-migrate-presence.sh` with dry run, history-preserving renames, and idempotence
- Update the presence-lifecycle and git-transport tests for the new names and add a migration test

### Phase 3: Session hooks

- Extend `backbone-session-start.sh` to register presence, keep the count first, and tell the agent to start the watcher
- Add `backbone-session-end.sh` that marks presence inactive and pushes in git mode
- Add the hook configuration for both, merged non-destructively into a project's `settings.json`, installed only with the developer's consent
- Add tests: first join, idempotent re-join, end marks inactive, hooks exit 0 on any failure, count remains the first line

### Phase 4: Collapse the commands

- Write `/backbone` with `status`, `join`, `leave`, `subscribe`, `unsubscribe`, `name` and `update`
- Write `/backbone-send` combining publish, secret check and ack timer, keeping the intent question
- Write `/backbone-done` replacing complete
- Update `/backbone-inbox` for the new scripts and keep the untrusted-message display
- Turn the nine old command files into forwarding aliases with a deprecation note
- Update the installer, README, CONVENTIONS.md, CLAUDE.md and every test that names a command
- Add a test that every script path referenced by a command file exists, and that each alias forwards

### Phase 5: Live validation (external)

- Run `tests/test-git-transport.sh` under Git Bash and WSL on a real Windows machine and record the result in `docs/windows-verification.md`
- Verify the poll, hooks and install on Windows, including that no colon filenames remain
- Run a real Bob and Nate exchange over git and record what no longer had to be relayed in `docs/live-exchange.md`
- Fix what the above turns up, then close the three open v5 tasks in `specs/README.md`

### Phase 6: Migrate into aidev-toolkit (next to last)

- Survey aidev-toolkit (`modules/sdd` layout, installer, absolute-path convention, test location) and record findings in Technical Notes before changing anything
- Record the module boundary decision: tooling moves, state and specs stay
- On a branch of aidev-toolkit, create `modules/backbone/{scripts,skills,templates}` and port the scripts with module-path resolution
- Merge the toolkit's existing `backbone-setup` skill into the new setup flow
- Port the tests into the toolkit's layout and run both repos' suites
- Update the toolkit's CLAUDE.md, README and installer; exercise the installer in a scratch `HOME`, never the real `~/.claude`
- Cut agent-backbone over: drop per-project script copies, `--link` and the copy manifest, and point commands at the module
- Write a rollback note and open the toolkit PR for the developer to review and merge

### Phase 7: Cleanup and release (last)

- Remove the deprecated aliases once every installed project has run the update
- Remove leftover scratch files (asking first) and fix any stale counts in docs
- Final documentation pass, version bump, and mark v5 and v6 complete

---

## Security

### Authentication

- Git remote access uses each person's own SSH key or `gh` auth (unchanged from v5). The notifier uses whatever credentials the configured command already has; the backbone stores none.

### Authorization

- Write access to the remote lets a person send requests to other agents, so it is granted only to people whose agents may do that. `notify_command` is read from the machine-local `backbone.config`, never from a message, a repo file, or the roster, so a sender cannot cause a command to run on a receiver's machine. Message text reaches the command only as environment variables.
- Hooks are installed only with the developer's consent, and settings are merged without overwriting existing hooks.

### Audit Logging

- Git history records every publish, claim, complete, and seen marker. Ping attempts are logged locally with target, id and result, never the body. Hook runs print one line, and failures print a reason.

---

## Technical Notes

### Architecture Decisions

- **Pluggable notifier over a built-in gchat call.** The only gchat implementation is Radeas-specific. A command contract works for chat, email, or nothing.
- **`ask` as the default.** Sending a message as a person without their approval is hard to undo, and the Radeas skill requires approval. `auto` is opt-in per project, which implements v5's decision without overriding another project's rule.
- **Filename safety through content, not escaping.** Storing the agent name in the file and scanning it avoids needing a reversible encoding.
- **Hooks cannot do everything.** They cannot start Monitor or write a "Learned" summary, so they print an instruction and leave the summary to an explicit `/backbone leave`.
- **Migration late.** Behavior is validated live before it moves.
- Coding rules applied: none loaded (no `coding-rules.md` in this repo). The project rule "no mocks" is followed: every test uses real git, real scripts and real files.
- Architecture principles applied: AP-001 (notifier arguments pass as environment variables, with injection tests), AP-002/AP-007 (hook and ping logging), AP-003 (notifier failure and unreachable-remote paths have explicit tasks and tests), AP-004 (each phase carries its own test task), AP-006 (no new third-party dependencies are introduced).

### Dependencies

- Write access to `~/pgh/aidev-toolkit` (a branch and PR).
- A Windows machine (Phase 5), and Nate for the live exchange.
- For the Radeas notifier: that project's gchat OAuth token and a DM space ID, both outside this repo.

### Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| Renaming commands breaks projects that have the old ones installed | Keep forwarding aliases until the cleanup phase |
| Presence rename loses history or breaks readers | Dry-run migration, history-preserving renames, readers scan `agent_name` |
| A hook error blocks session start | Hooks always exit 0 and print the reason |
| Moving to the toolkit before live use bakes in bugs | Live validation (Phase 5) precedes migration (Phase 6) |
| Work in the toolkit touches the global `~/.claude` | Work happens in the repo; the installer is exercised only in a scratch `HOME`; the developer runs the real install |
| Auto-sent pings read as coming from the sender | `ask` is the default; `auto` is an explicit per-project choice |

---

## Open Questions

1. ~~**Confirmation default**~~ **Settled (Bob, 2026-10-07):** `notify_confirm=ask` is the default; `auto` is opt-in through a machine default in `backbone.config` with a per-project override (`notify_confirm.<project>=`).
2. When `agent=` is not configured, is `<repo>:main` an acceptable automatic name, or should the hook refuse to register?
3. How long should the old command aliases live (one release, or until every project is updated)?
4. After the migration does agent-backbone remain a repo (specs, conventions, reference state), or fold into the toolkit?
5. Does the Windows verification use Nate's machine, and when?
6. **Sender authenticity (deferred, low priority):** `from:` is plain text and is not verified. The group is small (Bob, Nate, Bruno, possibly more) and the remote is a private repo, so the goal is consistency, not defence against a hostile member or a compromised account. Git history is the source of truth when someone needs to know who sent a message. Revisit if the group grows, write access reaches people outside it, or the remote becomes public. Options if it is ever needed, cheapest first: (a) show the pushing account beside `from:` in `/backbone-inbox`; (b) branch protection with no force pushes; (c) signed commits; (d) per-message signatures or encryption. Message encryption and signatures stay out of scope for v6.
7. **Google Chat as a message bus, not only a signal (open question, no change proposed):** could Google Chat (inside the company's Workspace) carry the messages themselves, instead of git? Chat is authenticated by the organization and removes the git dependency for people who lack repo access. Against it: it has no atomic claim (two agents could both act on one message), no queryable pending/claimed/complete state, retention depends on Workspace policy, bodies would transit the chat service (v5 keeps them out of pings), and the only gchat code found is a send script in one Radeas project, so there is no read side or per-agent app and OAuth setup. If pursued, the clean shape is a third `transport=chat` alongside `local` and `git`, not a replacement for git. Decide: (a) keep git as the bus and chat as the signal only (current design); (b) specify a `chat` transport in a later version; (c) something else. Revisit if git access becomes the bottleneck for new collaborators.

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| 2026-10-07 | Initial draft |
| 2026-10-07 | Add Open Question 6 (sender authenticity) |
| 2026-10-07 | Add Open Question 7 (Google Chat as a bus) |
| 2026-10-07 | Settle Q1: `ask` default, machine default plus per-project override (AC-2a) |
