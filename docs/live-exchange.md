# Live Bob and Nate exchange (v6 Phase 6, v5 Phase 6; can run before or after the migration)

**Status: NOT YET RUN.** This needs two people on two machines over a shared private remote. Record what actually happened; the point is to learn what no longer had to be relayed by hand.

## Setup (each person, once)

1. Both clone the shared backbone repo as `../agent-backbone` next to their projects and set `transport=git` in their own `backbone.config` (never committed).
2. Both install the commands and hooks: `bash ../agent-backbone/scripts/install-backbone-commands.sh <project> --hooks` and accept the hook prompt.
3. Add each other to `roster.md` (the `notify` column is the notifier target; leave `notify_command` unset to see the `NONOTIFIER` path, or set it to the wrapper in `docs/notify.md`).
4. Pick `agent=` addresses (`bash scripts/backbone-name.sh set bob` / `nate`) or accept the inferred `<repo>:<user>`.

## The exchange

1. Bob opens a session; the hook registers him and prints the pending count. Nate does the same.
2. Bob runs `/backbone-send` with a real question or task for Nate (a real piece of work, not a test message).
3. Nate's open session should be woken by the watcher, or his next session start should show the count first. Note which happened and how long it took.
4. Nate runs `/backbone-inbox`, claims it, does the work, runs `/backbone-done`.
5. Bob sees the completion without being told. Try once with Nate's session closed and the 5-minute timer running, and note whether a ping went out and how.

## Record

| Question | Answer |
| -------- | ------ |
| Date, who, which projects | |
| Did each hook register presence with no command typed? | |
| How did Nate learn the message existed (watcher, start count, ping)? | |
| Elapsed time from send to Nate's claim | |
| Did anyone have to relay anything outside the backbone (chat, email, paste)? What? | |
| What no longer had to be relayed compared with before the backbone | |
| What went wrong or was confusing | |

## What to fix

(List problems found, then Phase 6's last task fixes them.)
