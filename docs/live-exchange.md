# Live Bob and Nate exchange (v6 Phase 6, v5 Phase 6; can run before or after the migration)

**Status: NOT YET RUN.** This needs two people on two machines over a shared private remote. Record what actually happened; the point is to learn what no longer had to be relayed by hand.

## Rehearsal on one machine (2026-10-08)

**Status: PASSED, 1 finding.** Script: `.claude/scripts/rehearse-live-exchange.sh [SCRIPTS_DIR]` (it takes the scripts directory as an argument so it can later be pointed at the toolkit module). It builds a bare remote, two backbone clones and two projects with different git users, then runs the real hooks and scripts. Steps marked "by hand" are what a command file tells the model to do (write or rename a message file); the script does them with `sed` and `mv`, so the model-driven part is not exercised here.

| Step | Result |
| ---- | ------ |
| Both session hooks register presence with no command typed, pending count is the first output line | Passed |
| Hook prints the watcher instruction (a hook cannot start Monitor) | Passed |
| Nate's watcher wakes on Bob's published message with nobody telling Nate, and names the sender | Passed |
| Watcher wake counts as an ack: Bob's no-ack timer stays silent | Passed |
| Second message, Nate's session closed, no `notify_command`: `NONOTIFIER` | Passed |
| Same, `notify_command` set, default `ask`: `PING` printed, notifier not run | Passed |
| Same, `notify_confirm=auto`: notifier runs once with target, from, title, id and text in the environment | Passed |
| Title containing quotes, `$(...)` and backticks reaches the notifier unchanged and nothing executes | Passed |
| Message body never reaches the notifier | Passed |
| Nate's next session start shows both unclaimed messages, count first | Passed |
| Claim, complete, and Bob's clone holds the completed message after a pull | Passed |
| No filename contains a colon in either clone | Passed |

### Still relayed by hand (the finding)

- **Bob is not told when Nate finishes.** `/backbone-done` archives the message, but the completion is not addressed to the sender, so Bob's session start reports `0 pending`. Today the inbox's spec-handover step has the receiver send a separate completion message; if Nate skips that, Bob must ask in chat. Candidate fix: have `/backbone-done` publish a short `info` reply addressed to the original `from`. Not changed yet; decide with Bob.
- The rehearsal could not exercise the model-driven steps (drafting, the intent question, showing a PING for approval), the real Monitor tool, or a real chat notifier.

## Setup (each person, once)

1. Both clone the shared backbone repo as `../agent-backbone` next to their projects and set `transport=git` in their own `backbone.config` (never committed).
2. Both run `/aid-update` (installs the backbone module) and `/backbone-setup` in their project, accepting the hook prompt.
3. Add each other to `roster.md` (the `notify` column is the notifier target; leave `notify_command` unset to see the `NONOTIFIER` path, or set it to the wrapper in `docs/notify.md`).
4. Pick `agent=` addresses (`/backbone name set bob` / `nate`) or accept the inferred `<repo>:<user>`.

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
