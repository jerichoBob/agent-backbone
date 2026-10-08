# Git transport

By default the backbone is files on one disk (`../agent-backbone/`). Set `transport=git` to move the
same files between machines over a git remote. Spec: `specs/spec-v5-git-transport-and-notification.md`.

## Choosing a transport

Create `backbone.config` in the backbone directory (it is per machine and never committed):

```text
transport=git          # local (default) | git
agent=stak-app:main    # optional: the name the SessionStart hook counts messages for
```

| Setting | Behavior |
| --- | --- |
| absent, or `transport=local` | v1–v3 behavior. No command touches git, even if the directory has a remote. |
| `transport=git` | Publish, claim, complete, join and leave pull first and push after. An unreachable remote is an error — there is no silent fallback to local. |
| anything else | Error (exit 4). |

## Where the messages live

- **One project:** an orphan `backbone` branch of the project repo, checked out as a worktree at `../agent-backbone/`.
- **Several repos:** a dedicated private repo cloned as a sibling at `../agent-backbone/`.

The tooling repo ignores `messages/*` (except `README.md` and `types/`); the message branch or shared repo does not.

## Scripts

Installed into each project at `.claude/scripts/backbone/` by `scripts/install-backbone-commands.sh`.

| Script | Purpose |
| --- | --- |
| `backbone-sync.sh [--dir D] mode\|pull\|push <action> <id>` | The only code that touches git. Exit 0 ok, 2 remote unreachable, 3 lost a race, 4 config error. |
| `backbone-session-start.sh` | SessionStart hook: pull, print the pending count first, write seen markers. |
| `backbone-poll.sh` | Run under Monitor: silent while idle, one line and exit on a new addressed message. |

### SessionStart hook

Add to the project's `.claude/settings.json` (not installed automatically):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash .claude/scripts/backbone/backbone-session-start.sh --dir ../agent-backbone" } ] }
    ]
  }
}
```

Set `BACKBONE_AGENT` (or `agent=` in `backbone.config`) so the hook knows whose messages to count.

## Knowing a message arrived

| When the receiver is... | What tells them |
| --- | --- |
| starting a session | `backbone-session-start.sh` prints the pending count first |
| in an open session | `backbone-poll.sh` under Monitor wakes the agent (30 s interval, no tokens while idle) |
| away | after 5 minutes with no ack, the sender's session pings the receiver's human on Google Chat |

An ack is a claim or a `seen` marker (`messages/seen/<type>-<id>.<agent>`), which the hook and the poll write
and push. The ping carries sender and title only. Who to ping comes from `roster.md` at the backbone root,
edited by hand (rows may use globs, see `scripts/backbone-roster-lookup.sh`):

```text
| agent      | human | gchat           |
| ---------- | ----- | --------------- |
| stak-app:* | Bob   | bob@example.com |
```

The sender's session must stay open for the timer to fire. `backbone-ack-check.sh` is the timer; the
`/gchat` send itself happens in the sender's Claude session, not in the script.

## Claiming over git

Claim renames `-pending` to `-claimed` and records `claimed_by`, then pushes. Two agents claiming at once
both commit; the first push wins and the second is rejected. The wrapper drops the loser's commit,
re-syncs, and exits 3 so `/backbone-inbox` can say "already claimed by X".

## Access control for the remote

Anyone who can push to the remote can put a request in front of every teammate's agent. Treat write access
like access to a shared inbox that agents read:

- Use a **private** repo (or a private branch of one). Messages carry project context, and private repos
  are the only protection — there is no message encryption.
- Grant write access only to people whose agents should be able to send requests, and review it when the team changes.
- Use per-person credentials (SSH keys or `gh` auth), never a shared token.
- Consider requiring signed commits on the message branch. The sender field is self-declared; signatures are
  the way to make it verifiable, and are not enforced by these scripts.
- Agents treat message content as untrusted requests (see `CONVENTIONS.md`), so a hostile message cannot
  run anything without a human approving it. This is a second layer, not a substitute for the first.
- `/backbone-publish` refuses bodies that look like secrets (`scripts/backbone-secret-check.sh`). It is a
  pattern check, not a guarantee. If a secret does get pushed, rotate it; deleting the message does not remove it from git history.

## Testing

`bash tests/test-git-transport.sh` — real git, two clones of a local bare repo, no mocks.
