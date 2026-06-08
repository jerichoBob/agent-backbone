# /backbone-update — Pull latest backbone and reinstall commands

Pull the latest `agent-backbone` from GitHub and reinstall all `backbone-*.md` commands into the current project.

## When to Use

- The backbone has been updated (new conventions, new commands, bug fixes)
- After any change to `agent-backbone/.claude/commands/` or `CONVENTIONS.md`
- Before starting a session to make sure you're on current backbone protocol

## Instructions

### Step 1: Verify backbone is accessible

```bash
ls ../agent-backbone/ 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

If `MISSING`:
> `../agent-backbone/` not found. Run `/backbone-setup` first to clone it.

Stop if missing.

### Step 2: Pull latest from GitHub

```bash
cd ../agent-backbone && git pull --ff-only 2>&1
```

If pull fails (e.g. local changes, merge conflict), show the error and stop:
> "git pull failed — resolve the issue in `../agent-backbone/` manually, then re-run /backbone-update."

Report: `agent-backbone pulled — now at {short commit hash}`

### Step 3: Reinstall commands into this project

```bash
bash ../agent-backbone/scripts/install-backbone-commands.sh "$(pwd)"
```

Show the install script output so the user can see which files were updated.

### Step 4: Confirm

```
Backbone Update Complete
========================

agent-backbone:  pulled to {short-hash}
Commands:        reinstalled into .claude/commands/

Run /backbone-join to register this session with the updated backbone.
```

## Notes

- `git pull --ff-only` is intentional — the backbone is a shared repo. If it fails, resolve manually in `../agent-backbone/`.
- Safe to run even if nothing changed — idempotent.
- To update all projects, run `/backbone-update` from each project repo in turn.
