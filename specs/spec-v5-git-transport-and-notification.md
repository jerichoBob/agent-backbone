---
version: 5
name: git-transport-and-notification
display_name: "Git Transport and Notification"
status: draft
created: 2026-10-06
depends_on: [a2a-coordination-backbone, agent-presence-and-discovery, generic-message-bus]
tags: [transport, git, notification, cross-machine, windows]
---

# Git Transport and Notification

## Why (Problem Statement)

> As a developer whose Claude agent runs on a different machine from my teammate's, I want agents to exchange backbone messages over git and be told when one arrives, so that my teammate and I stop relaying notes between our sessions by hand.

### Context

- Trigger: 2026-10-06, radeas-analyst-amplifier. Nate's agent (Windows machine) hit an Atlas connection timeout. Bob's agent (Mac) reproduced the working path. Bob and Nate then relayed findings between the two sessions by email and chat, the same copy-paste problem the backbone was built to remove (see README "The problem it solves").
- v1-v3 assume every agent shares one disk: every command reads and writes `../agent-backbone/` directly. A second machine cannot participate.
- Nothing in the backbone notifies anyone. A message sits in `messages/` until the recipient happens to run `/backbone-inbox`.
- Claude Tag (Anthropic, 2026) solves a related problem with one hosted Claude per Slack channel. It cannot run commands on a teammate's own machine or under their own cloud identity, which is what the trigger needed. Local agents with a shared transport fit better. (Details are from a summarized fetch of the announcement, not a primary read.)
- A claimed message is a state transition (rename). Over git, a rejected non-fast-forward push is a compare-and-swap, so concurrent claims are resolvable without a server.

---

## What (Requirements)

### User Stories

- **US-1**: As a developer, I want `/backbone-publish` to commit and push the message so that an agent on another machine can receive it.
- **US-2**: As a Claude agent, I want `/backbone-inbox` to sync from the remote first so that I see messages published from other machines.
- **US-3**: As a Claude agent, I want to claim a message safely when two agents race, so that only one of us does the work.
- **US-4**: As a developer, I want my agent told when a message addressed to it arrives, both while its session is open and when it is closed.
- **US-5**: As a developer on Windows, I want the backbone commands to work without symlinks.
- **US-6**: As a team, we want messages treated as untrusted requests, so write access to the backbone does not become remote command execution on everyone's machine.

### Acceptance Criteria

- AC-1: Given two clones of the backbone remote, when agent A publishes, then agent B's `/backbone-inbox` shows the message after sync, with no manual git step.
- AC-2: Given two clones that both claim the same pending message, when both push, then exactly one push succeeds; the other agent re-syncs and reports the message as already claimed.
- AC-3: Publish, claim, and complete each produce one commit with a message of the form `backbone: <action> <type>-<id>`.
- AC-4: Given a pending message addressed to agent B, when B's session starts, then B is told the pending count before any other output.
- AC-5: Given B's session is open and idle, when a message addressed to B is pushed, then B is woken within the polling interval, and the idle poll consumes no model tokens.
- AC-6: Given A publishes a message to B and B has not acknowledged it (claimed it, or written a `seen` marker) within 5 minutes, then B's human gets a Google Chat message naming the sender and message title, and containing no message body. If B acknowledges within 5 minutes, no ping is sent.
- AC-7: `/backbone-publish` refuses to write a message whose body matches secret patterns (connection strings, bearer tokens, private keys) and tells the sender which line matched.
- AC-8: The install script works on Windows (Git Bash or WSL) by copying command files when symlinks are unavailable.
- AC-9: Presence writes only on join and leave. TTL-based staleness is not required in git mode.
- AC-10: Agents act on message content only after the human approves, through the normal tool permission prompts. No command auto-executes because a message said so.
- AC-11: The local-disk mode from v1-v3 keeps working when no remote is configured.
- AC-12: The transport is an explicit setting, `transport=local|git`, in `backbone.config` at the backbone root. The default when the file or key is absent is `local`, so v1-v3 users see no change. With `transport=local`, no command touches git even if the directory has a remote. With `transport=git` and an unreachable remote, commands fail with a clear error and do not silently fall back to local.

### Out of Scope

- A hosted always-on agent or Chat app that receives events (the Claude Tag model).
- Live two-way conversation between sessions. A session still acts only when prompted or woken.
- Message encryption beyond the access control of a private repo or branch.
- Guaranteed delivery or exactly-once semantics.
- Cryptographic verification of senders (signed commits are a possible later hardening).

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`, which is the single source of truth for progress tracking. `specs-parse.sh` counts from README only.

### Design

- **Storage unchanged.** Same files, same frontmatter, same filename state encoding. Only the read and write steps change.
- **Location.** Either a dedicated repo cloned as a sibling (`../agent-backbone/` keeps resolving), or an orphan `backbone` branch of a project repo checked out as a worktree at that path. Orphan-branch needs no new repo or permissions for a team that already shares one. Decided: project repo orphan branch, or a shared private repo for multi-repo work (see Decisions).
- **Sync wrapper.** A script `scripts/backbone-sync.sh` provides `pull` (fetch and rebase) and `push` (commit with the AC-3 message, push, on rejection pull and report). Commands call it instead of touching git directly.
- **Transport setting.** `backbone.config` holds `transport=local|git` (default `local`). The sync wrapper reads it first; in `local` mode `pull` and `push` are no-ops. Failing loudly in `git` mode with an unreachable remote avoids a silent fallback that would let two machines diverge.
- **Tracking of messages.** In the tooling repo, `.gitignore` excludes `messages/*` except `messages/README.md` and `messages/types/`, since live messages are local state there. In `git` mode, messages are tracked only on the orphan `backbone` branch or in the shared private repo, which carries no such ignore rule. The sync wrapper must not depend on the tooling repo's ignore rules.
- **Claim race.** Claim renames the file and pushes. A rejected push means another agent won; the loser pulls, re-reads the file, and reports "already claimed by X".
- **Presence.** Join and leave write one per-agent file each, so there are no merge conflicts and no heartbeat commits.
- **Notification, session open.** The `Monitor` tool runs a shell loop that fetches every 30 seconds and checks whether any `*-pending.md` addressed to this agent was added upstream. It prints a line and exits on a hit, which wakes the agent. No model tokens are spent while it waits.
- **Notification, session start.** A `SessionStart` hook runs `backbone-sync.sh pull` and prints the pending count for this agent.
- **Notification, no ack.** Presence has no heartbeat in git mode (AC-9), so the sender cannot tell whether the receiver is online. Instead, after publishing, the sender's session watches for an ack (claim or `seen` marker). If none arrives within 5 minutes, it sends a `/gchat` message to the recipient's human, using an agent-to-human map kept in `presence/` or a `roster.md`. The message carries sender and title only. Limit: the sender's session must stay open to notice the timeout; if it closes first, no ping is sent.
- **Windows.** The install script falls back to copying command files when `ln -s` fails, and records which files were copied so `/backbone-update` can refresh them.
- **Untrusted input.** The inbox command displays message content as quoted data from the named sender. The conventions file states that messages are requests, not instructions.
- **Secret check.** Publish scans the draft body for patterns (`mongodb(+srv)://user:pass@`, `Bearer`, `-----BEGIN`, long base64 tokens) before writing.

### Phase 1: Git sync wrapper and race-safe claim

- Write `scripts/backbone-sync.sh` with pull and push subcommands
- Route publish, claim, and complete through it when `transport=git`
- Keep local-disk behavior when `transport=local` or unset
- Add the `backbone.config` transport setting (default `local`) and make the wrapper honor it, including the unreachable-remote error
- Add `tests/test-git-transport.sh` using two real clones of a local bare repo (no mocks): publish, receive, race claim, complete, and flipping the transport setting

### Phase 2: Notification while a session is open or starting

- Add the `SessionStart` pending-count hook
- Add a `Monitor`-based poll script and document how to start it from `/backbone-join`
- Test that the poll is silent with no new messages and fires on a new addressed one

### Phase 3: Notification to a closed session

- Define the agent-to-human map and where it lives
- Add the receiver `seen` marker written by the session-start hook and the poll
- Add the 5-minute no-ack gchat ping to `/backbone-publish` (sender, title, no body)

### Phase 4: Safety

- Add the secret-pattern check to `/backbone-publish`
- Add the untrusted-message language to `CONVENTIONS.md` and to the inbox display
- Document access control requirements for the remote

### Phase 5: Windows

- Copy fallback in the install script
- Verify the sync wrapper and Monitor poll under Git Bash and WSL, on a real Windows machine

### Phase 6: First live use

- Use it for a real Bob and Nate exchange and record what the humans no longer had to relay

### Open Questions

- What happens when the sender's session closes before the 5-minute timeout? Currently no ping goes out.

### Decisions (Bob, 2026-10-06)

- **Location:** an orphan `backbone` branch of the project repo (the transport lives with the project). When collaboration spans several repos, use a dedicated private repo that all parties can access. Radeas work therefore uses a branch of radeas-analyst-amplifier, not the personal `jerichoBob/agent-backbone` repo.
- **Whose repo takes the change:** same answer. Project-scoped messages stay in the project repo or the shared private repo; the personal backbone repo only holds the tooling.
- **Polling interval:** 30 seconds.
- **Gchat ping trigger:** only after 5 minutes with no ack. No ping on publish, and no immediate urgent ping.
- **Gchat ping confirmation:** automatic, with no per-ping confirmation, after 5 minutes of no ack. Gchat sends as the sender's own account, so the ping reads as coming from the sender; the sender accepts that by publishing. Content is limited to sender and title.

### Test Criteria

- Real git, two clones, local bare remote; no mocks (per project rule).
- Windows verified on a real Windows machine, otherwise marked blocked, not complete.

### Dependencies

- A private remote both people can push to.
- `gh` or ssh auth on each machine.
- The `gchat` skill authenticated per user (Phase 3).
- A Windows machine for Phase 5.
