# End-to-end check of hooks and commands (v6 Phase 4)

**Status: scripted half PASSED (2026-10-08); real-session half NOT RUN.**

## What was run

`.claude/scripts/e2e-check-hooks.sh` builds a scratch project next to a scratch copy of this repo under a scratch `HOME` (the real `~/.claude` is not touched), installs with the real installer, then reads the hook commands back out of the project's `settings.json` and runs them exactly as Claude Code would: from the project directory, with the session JSON on stdin and `CLAUDE_PROJECT_DIR` set.

| Check | Result |
| ----- | ------ |
| `install-backbone-commands.sh --hooks` (the pre-migration installer) with no terminal changes nothing (consent withheld) | Passed |
| `backbone-install-hooks.sh --yes` adds the hooks | Passed |
| Second run adds no duplicate | Passed |
| Existing `model` setting and an existing SessionStart hook survive | Passed |
| Start hook: pending count is the first output line, presence registered, watcher instruction printed | Passed |
| `backbone-presence.sh me` returns the session name from the project directory | Passed |
| Same `session_id` again re-joins: no second session record | Passed |
| End hook exits 0 and marks the session inactive | Passed |
| Hooks exit 0 on garbage stdin and on a missing backbone directory | Passed |
| No colon filenames in the scratch tree | Passed (after migration, below) |

## Found and fixed

- The reference deployment's three presence files (`presence-grostak-v2:main.md`, `presence-stak-app:main.md`, `presence-stak-app:preferences-persistence.md`) still had colons: the migration script existed but had never been run on this repo. Ran `backbone-migrate-presence.sh` (dry run first, then for real, then again to confirm "nothing to migrate"). The renames are staged with `git mv` semantics, not committed.

## Not covered: a real Claude Code session

The script cannot show that Claude Code itself fires the hooks, that the SessionStart output lands in the model's context, or that the model follows the `/backbone`, `/backbone-send`, `/backbone-inbox` and `/backbone-done` command files. To close this task, open a session in a scratch project that has the hooks installed and check:

1. The first line of context is `backbone: N pending message(s) for <name>`.
2. `/backbone status` lists the session; `/backbone-send` asks the intent question first; `/backbone-inbox` shows messages as quoted data; `/backbone-done` archives.
3. Closing the session marks presence inactive (`status: inactive` in its presence file).

A nested `claude` run needs credentials and writes a transcript under `~/.claude`, so it was not launched automatically. Record the outcome here when done.
