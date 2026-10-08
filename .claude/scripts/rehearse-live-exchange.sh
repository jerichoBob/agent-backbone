#!/usr/bin/env bash
# Rehearse the Bob and Nate exchange on one machine: a bare remote, two clones (bob, nate), two
# "projects" with their own git user, real hooks, real scripts. A person's keystrokes are marked
# "BY HAND" — those are the steps a command file tells the model to do (write/rename a message file).
# Everything else is the backbone's own scripts. Prints a transcript; exits 1 on any unexpected result.
# Usage: bash .claude/scripts/rehearse-live-exchange.sh [SCRIPTS_DIR]
#   default SCRIPTS_DIR: $BACKBONE_MODULE/scripts, else the installed module, else ../aidev-toolkit/modules/backbone/scripts
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="${1:-}"
if [[ -z "$S" ]]; then
  for c in "${BACKBONE_MODULE:-}" "$HOME/.claude/aidev-toolkit/modules/backbone" "$ROOT/../aidev-toolkit/modules/backbone"; do
    [[ -n "$c" && -f "$c/scripts/backbone-sync.sh" ]] && { S="$(cd "$c/scripts" && pwd)"; break; }
  done
fi
[[ -f "$S/backbone-sync.sh" ]] || { echo "BLOCKED: backbone module not found"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_EMAIL=r@example.com GIT_COMMITTER_EMAIL=r@example.com
FAILS=0
step() { echo; echo "── $*"; }
ok()   { echo "   ok: $*"; }
bad()  { echo "   FAIL: $*"; FAILS=$((FAILS+1)); }
expect() { if [[ "$1" == *"$2"* ]]; then ok "$3"; else bad "$3 (wanted '$2' in: $1)"; fi; }

step "setup: bare remote, bob and nate backbone clones, one project each"
git init -q --bare -b main "$W/remote.git"
git clone -q "$W/remote.git" "$W/seed" 2>/dev/null
mkdir -p "$W/seed/messages" "$W/seed/presence"; touch "$W/seed/messages/.gitkeep" "$W/seed/presence/.gitkeep"
cat > "$W/seed/roster.md" <<'R'
| agent | human | notify |
| ----- | ----- | ------ |
| demo:nate | Nate | spaces/NATEDM |
R
export GIT_AUTHOR_NAME=Seed GIT_COMMITTER_NAME=Seed
git -C "$W/seed" add -A; git -C "$W/seed" commit -q -m init; git -C "$W/seed" push -q origin HEAD:main
for p in bob nate; do
  git clone -q "$W/remote.git" "$W/$p-bb" 2>/dev/null
  printf 'transport=git\nagent=demo:%s\n' "$p" > "$W/$p-bb/backbone.config"
  mkdir -p "$W/$p-proj"; git -C "$W/$p-proj" init -q -b main
done
git -C "$W/bob-proj" config user.name Bob; git -C "$W/nate-proj" config user.name Nate
BB="$W/bob-bb"; NB="$W/nate-bb"

step "1. both sessions start; hooks register presence with no command typed"
B_OUT="$(echo '{"session_id":"bob-s1"}' | bash "$S/backbone-session-start.sh" --dir "$BB" --project "$W/bob-proj" 2>&1)"
N_OUT="$(echo '{"session_id":"nate-s1"}' | bash "$S/backbone-session-start.sh" --dir "$NB" --project "$W/nate-proj" 2>&1)"
echo "$B_OUT" | sed 's/^/   bob  | /'; echo "$N_OUT" | sed 's/^/   nate | /'
expect "$(head -1 <<<"$B_OUT")" "backbone: 0 pending" "bob's first line is the pending count"
expect "$(head -1 <<<"$N_OUT")" "backbone: 0 pending" "nate's first line is the pending count"
BOB="$(bash "$S/backbone-presence.sh" --dir "$BB" me "$W/bob-proj" 2>&1)"; [[ -n "$BOB" ]] && ok "bob session name: $BOB" || bad "me returned nothing"
git -C "$NB" pull -q --rebase origin main 2>/dev/null; git -C "$BB" pull -q --rebase origin main 2>/dev/null

step "2. nate's watcher starts (baseline = nothing pending)"
( bash "$S/backbone-poll.sh" --dir "$NB" --agent demo:nate --interval 1 --max-iterations 30 > "$W/poll.out" 2>&1; echo "exit=$?" >> "$W/poll.out" ) &
POLL=$!
sleep 3

step "3. BY HAND (what /backbone-send writes): bob publishes a task to demo:nate, then pushes via the sync script"
ID=20261008-120000
cat > "$BB/messages/task-$ID-pending.md" <<M
---
id: "$ID"
type: task
status: pending
routing: direct
from: $BOB
to: demo:nate
title: Add index on refill_requests
created: 2026-10-08
updated: 2026-10-08
---

Please add an index on refill_requests(tenant_id, status).
M
bash "$S/backbone-secret-check.sh" "$BB/messages/task-$ID-pending.md"; [[ $? -eq 0 ]] && ok "secret check clean" || bad "secret check"
bash "$S/backbone-sync.sh" --dir "$BB" push publish "task-$ID" && ok "published" || bad "publish push"

step "4. nate's watcher wakes with no one telling nate"
wait $POLL
cat "$W/poll.out" | sed 's/^/   poll | /'
expect "$(cat "$W/poll.out")" "task-$ID" "watcher names the new message"
expect "$(cat "$W/poll.out")" "exit=0" "watcher exited 0 (woke the agent)"

step "5. bob's no-ack timer: nate's watcher already wrote a seen marker, so the timer stays silent"
ACK="$(bash "$S/backbone-ack-check.sh" --dir "$BB" --id "task-$ID" --to demo:nate --from "$BOB" --title "Add index" --timeout 3 --interval 1 2>&1)"; rc=$?
[[ $rc -eq 0 && -z "$ACK" ]] && ok "silent, exit 0 (the watcher's wake is the ack)" || bad "expected silence, rc=$rc out=$ACK"

step "5b. a second message while nate's session is closed (no watcher, no seen marker): the timer fires"
ID2=20261008-121500
sed -e "s/$ID/$ID2/g" -e 's/Add index on refill_requests/Review the schema change/' "$BB/messages/task-$ID-pending.md" > "$BB/messages/task-$ID2-pending.md"
bash "$S/backbone-sync.sh" --dir "$BB" push publish "task-$ID2" && ok "published second message"
T() { bash "$S/backbone-ack-check.sh" --dir "$BB" --id "task-$ID2" --to demo:nate --from "$BOB" --title 'He said "hi" $(touch /tmp/PWNED) `id`' --timeout 2 --interval 1 2>&1; echo "rc=$?"; }
OUT="$(T)"; echo "$OUT" | sed 's/^/   ack  | /'
expect "$OUT" "NONOTIFIER" "no notify_command: nothing attempted, bob is told"
cat > "$W/notifier.sh" <<'N'
#!/usr/bin/env bash
printf 'target=%s\nfrom=%s\ntitle=%s\nid=%s\ntext=%s\n' "$BACKBONE_NOTIFY_TARGET" "$BACKBONE_NOTIFY_FROM" "$BACKBONE_NOTIFY_TITLE" "$BACKBONE_NOTIFY_ID" "$BACKBONE_NOTIFY_TEXT" > "$NOTIFY_LOG"
N
chmod +x "$W/notifier.sh"
printf 'notify_command=env NOTIFY_LOG=%s %s\n' "$W/notified.txt" "$W/notifier.sh" >> "$BB/backbone.config"
OUT="$(T)"; echo "$OUT" | sed 's/^/   ack  | /'
expect "$OUT" "PING Nate|spaces/NATEDM" "ask mode (default): prints PING for bob to approve, sends nothing"
[[ ! -f "$W/notified.txt" ]] && ok "notifier not run before approval" || bad "notifier ran without approval"
printf 'notify_confirm=auto\n' >> "$BB/backbone.config"
OUT="$(T)"; echo "$OUT" | sed 's/^/   ack  | /'
expect "$OUT" "SENT" "auto mode: notifier ran"
[[ -f "$W/notified.txt" ]] && sed 's/^/   notif| /' "$W/notified.txt"
expect "$(cat "$W/notified.txt" 2>/dev/null)" "target=spaces/NATEDM" "notify column reached the notifier"
grep -q "Review the schema" "$W/notified.txt" && bad "message BODY leaked to notifier" || ok "no body in the ping"
[[ ! -e /tmp/PWNED ]] && ok "injection attempt in the title did not execute" || { bad "title was executed"; rm -f /tmp/PWNED; }

step "6. nate: new session start shows the count first; BY HAND (what /backbone-inbox does): claim"
N2="$(echo '{"session_id":"nate-s2"}' | bash "$S/backbone-session-start.sh" --dir "$NB" --project "$W/nate-proj" 2>&1)"
echo "$N2" | sed 's/^/   nate | /'
expect "$(head -1 <<<"$N2")" "2 pending" "count is the first line and shows both unclaimed messages"
NATE="$(bash "$S/backbone-presence.sh" --dir "$NB" me "$W/nate-proj" 2>&1)"
sed -e 's/^status: pending/status: claimed/' -e "s/^updated:.*/updated: 2026-10-08\nclaimed_by: $NATE/" \
  "$NB/messages/task-$ID-pending.md" > "$NB/messages/task-$ID-claimed.md"; rm "$NB/messages/task-$ID-pending.md"
bash "$S/backbone-sync.sh" --dir "$NB" push claim "task-$ID" && ok "claimed" || bad "claim push"

step "7. bob's timer would now stay silent (claimed counts as an ack)"
ACK2="$(bash "$S/backbone-ack-check.sh" --dir "$BB" --id "task-$ID" --to demo:nate --from "$BOB" --title "Add index" --timeout 3 --interval 1 2>&1)"; rc=$?
[[ $rc -eq 0 && -z "$ACK2" ]] && ok "silent, exit 0" || bad "expected silent exit 0, rc=$rc out=$ACK2"

step "8. BY HAND (what /backbone-done does): nate completes; bob sees it after a pull"
sed -e 's/^status: claimed/status: completed/' "$NB/messages/task-$ID-claimed.md" > "$NB/messages/task-$ID-completed.md"; rm "$NB/messages/task-$ID-claimed.md"
bash "$S/backbone-sync.sh" --dir "$NB" push complete "task-$ID" && ok "completed" || bad "complete push"
B2="$(echo '{"session_id":"bob-s2"}' | bash "$S/backbone-session-start.sh" --dir "$BB" --project "$W/bob-proj" 2>&1)"
echo "$B2" | sed 's/^/   bob  | /'
[[ -f "$BB/messages/task-$ID-completed.md" ]] && ok "bob's clone holds the completed message after a pull" || bad "completion did not reach bob"
expect "$(head -1 <<<"$B2")" "0 pending" "FINDING: bob is NOT told the task finished (completion is not addressed to the sender)"

step "9. no colon filenames anywhere"
BAD="$(find "$BB" "$NB" -path '*/.git' -prune -o -name '*:*' -print)"
[[ -z "$BAD" ]] && ok "none" || bad "colon filenames: $BAD"

echo; [[ $FAILS -eq 0 ]] && echo "REHEARSAL OK" || echo "REHEARSAL: $FAILS failure(s)"; exit $((FAILS>0))
