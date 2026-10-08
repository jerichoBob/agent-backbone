# Windows verification (v6 Phase 6, after the migration)

**Status: NOT YET RUN.** This needs a real Windows machine (Nate's, or Bob's Windows laptop). Nothing in the macOS environment that built v6 can verify it. Fill in the results table and commit this file when you have run it.

## Before you start

- Git for Windows (Git Bash) and, for the second pass, WSL with `git` and `bash`.
- `jq` or `python3` on the PATH (the hook installer needs one; with neither it prints the snippet to paste).
- A clone of this repo at `C:\...\agent-backbone`. Do the Git Bash pass in a path **outside** WSL's `/mnt/c` for the WSL pass, or the filesystem differences hide real problems.
- Developer Mode or admin rights are **not** required: the installer copies files when symlinks are unavailable.

## Steps (run each in Git Bash, then again in WSL)

1. **Clone.** `git clone <repo> agent-backbone`. A clone with colon-named presence files fails on Windows; if it does, run the migration from a Mac first (`bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-migrate-presence.sh`, commit) and re-clone. Record whether the clone itself succeeded.
2. **Suites.** In the installed or checked-out aidev-toolkit: `bash tests/test-backbone-git-transport.sh`, `test-backbone-presence.sh`, `test-backbone-commands.sh`. In agent-backbone: `bash tests/test-message-bus.sh`, `test-backbone-workflow.sh`, `test-presence-lifecycle.sh`, `test-repo-docs.sh` (set `BACKBONE_MODULE` if the module is not installed). Record pass/fail counts and paste any failure output.
3. **No colon filenames.** `find . -path ./.git -prune -o -name '*:*' -print` prints nothing.
4. **Install.** Run the toolkit installer (`/aid-update`, or `scripts/install.sh` in a scratch `HOME`). Expect real-file copies of the backbone skills under `commands/` and `skills/`, no symlinks, and executable scripts under `modules/backbone/scripts/`. Then in a scratch project run `bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-install-hooks.sh <project>`: a consent prompt, and `.claude/settings.json` containing both hooks.
5. **Hooks.** Start a Claude Code session in the project. The first line of hook output is `backbone: N pending message(s) for <repo>:<user>~xxxx`, and a presence file named `presence-<repo>__<user>~xxxx.md` appears. End the session: the record's `status` becomes `inactive`.
6. **Poll.** Run `bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-poll.sh --dir <backbone> --agent <name> --interval 5 --max-iterations 3`. It prints nothing and exits 1 when idle, and prints one line and exits 0 when a message addressed to `<name>` is added.
7. **Line endings.** If any script fails with `$'\r': command not found`, note which file and whether `core.autocrlf` was on. `.gitattributes` pins `*.sh` to LF, so a failure here means a checkout that predates it or an editor that rewrote the file.

## Results

| Pass | Date | Machine / shell | Suites (pass/fail counts) | Clone OK | No colon files | Install + hooks | Poll | Notes |
| ---- | ---- | --------------- | ------------------------- | -------- | -------------- | --------------- | ---- | ----- |
| Git Bash | | | | | | | | |
| WSL | | | | | | | | |

## What turned up

(Nothing recorded yet. List each problem, the file, and the fix. Phase 6's last task fixes these and then closes the three open v5 tasks.)
