#!/usr/bin/env bash
# Tests the v5 git transport: sync wrapper, race-safe claim, transport setting,
# notification scripts, secret check. Uses real git with two clones of a local bare
# repo — no mocks.
# Run from the agent-backbone root: bash tests/test-git-transport.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$ROOT/scripts/backbone-sync.sh"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0

export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }
assert_file() { if [[ -f "$1" ]]; then pass "$2"; else fail "$2 (missing: $1)"; fi; }
assert_no_file() { if [[ ! -f "$1" ]]; then pass "$2"; else fail "$2 (should not exist: $1)"; fi; }
assert_contains() { if grep -q -- "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3 (pattern '$2' not in $1)"; fi; }

# make_msg <dir> <type> <id> <to>   — write a pending direct message
make_msg() {
  cat > "$1/messages/$2-$3-pending.md" <<EOF
---
id: "$3"
type: $2
status: pending
routing: direct
from: sender:main
to: $4
title: Test message $3
created: 2026-10-07
updated: 2026-10-07
---

Body of $3.
EOF
}

# claim_msg <dir> <type> <id> <agent> — rename pending to claimed, recording claimed_by
claim_msg() {
  sed -e 's/^status: pending/status: claimed/' -e "s/^updated:.*/updated: 2026-10-07\nclaimed_by: $4/" \
    "$1/messages/$2-$3-pending.md" > "$1/messages/$2-$3-claimed.md"
  rm "$1/messages/$2-$3-pending.md"
}

# new_world — fresh bare remote and two synced clones in transport=git mode
new_world() {
  rm -rf "$TMP_DIR/w"; mkdir -p "$TMP_DIR/w"
  BARE="$TMP_DIR/w/remote.git"; A="$TMP_DIR/w/a"; B="$TMP_DIR/w/b"
  git init -q --bare -b main "$BARE"
  git clone -q "$BARE" "$A" 2>/dev/null
  mkdir -p "$A/messages" "$A/presence"; touch "$A/messages/.gitkeep" "$A/presence/.gitkeep"
  git -C "$A" add -A && git -C "$A" commit -q -m "init" && git -C "$A" push -q origin HEAD:main
  git -C "$A" branch -q -M main 2>/dev/null; git -C "$A" branch -q --set-upstream-to=origin/main main 2>/dev/null
  git clone -q "$BARE" "$B" 2>/dev/null
  echo "transport=git" > "$A/backbone.config"; echo "transport=git" > "$B/backbone.config"
}

echo ""
echo "Git Transport Tests"
echo "==================="

# ── 1. Transport setting ──────────────────────────────────────────────────────
echo ""
echo "1. Transport setting (AC-11, AC-12)"
new_world
rm -f "$B/backbone.config"
assert_eq "$("$SYNC" --dir "$B" mode)" "local" "no backbone.config defaults to local"
echo "transport=local" > "$B/backbone.config"
before="$(git -C "$B" rev-parse HEAD)"
make_msg "$B" task 100 "a:main"
"$SYNC" --dir "$B" push publish task-100; rc=$?
assert_eq "$rc" "0" "local-mode push exits 0"
assert_eq "$(git -C "$B" rev-parse HEAD)" "$before" "local mode makes no commit even though a remote exists"
assert_eq "$(git -C "$BARE" log --oneline | wc -l | tr -d ' ')" "1" "local mode pushes nothing to the remote"
assert_file "$B/messages/task-100-pending.md" "local mode leaves the message on disk"
rm "$B/messages/task-100-pending.md"
echo "transport=carrier-pigeon" > "$B/backbone.config"
"$SYNC" --dir "$B" mode >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "invalid transport value fails loudly (exit 4)"
echo "transport=git" > "$B/backbone.config"
assert_eq "$("$SYNC" --dir "$B" mode)" "git" "transport=git is honored"

# ── 2. Publish and receive (AC-1, AC-3) ───────────────────────────────────────
echo ""
echo "2. Publish and receive over git (AC-1, AC-3)"
new_world
make_msg "$A" task 200 "b:main"
"$SYNC" --dir "$A" push publish task-200; rc=$?
assert_eq "$rc" "0" "publish push succeeds"
assert_eq "$(git -C "$BARE" log -1 --format=%s main)" "backbone: publish task-200" "publish commit message is 'backbone: publish task-200'"
assert_no_file "$B/messages/task-200-pending.md" "B does not see it before pulling"
"$SYNC" --dir "$B" pull; rc=$?
assert_eq "$rc" "0" "B pull succeeds"
assert_file "$B/messages/task-200-pending.md" "B sees the message after pull, no manual git step"
assert_eq "$(git -C "$A" ls-files backbone.config | wc -l | tr -d ' ')" "0" "backbone.config is never committed"

# ── 3. Race-safe claim (AC-2, AC-3) ───────────────────────────────────────────
echo ""
echo "3. Concurrent claim: exactly one wins (AC-2)"
claim_msg "$A" task 200 "a:main"
claim_msg "$B" task 200 "b:main"
"$SYNC" --dir "$A" push claim task-200; rcA=$?
"$SYNC" --dir "$B" push claim task-200 2>"$TMP_DIR/loser.err"; rcB=$?
assert_eq "$rcA" "0" "first claimer's push succeeds"
assert_eq "$rcB" "3" "second claimer's push is rejected as a lost race (exit 3)"
assert_contains "$TMP_DIR/loser.err" "lost the race" "loser is told it lost the race"
assert_file "$B/messages/task-200-claimed.md" "loser's tree now holds the winner's claimed file"
assert_contains "$B/messages/task-200-claimed.md" "claimed_by: a:main" "loser sees the winner as claimed_by"
assert_no_file "$B/messages/task-200-pending.md" "loser has no stale pending copy"
assert_eq "$(git -C "$BARE" log --format=%s main | grep -c 'backbone: claim task-200')" "1" "remote has exactly one claim commit"
assert_eq "$(git -C "$B" status --porcelain | grep -v backbone.config | wc -l | tr -d ' ')" "0" "loser's working tree is clean after re-sync"

# ── 4. Complete (AC-3) ────────────────────────────────────────────────────────
echo ""
echo "4. Complete and archive"
mkdir -p "$A/messages/archive"
git -C "$A" mv -f messages/task-200-claimed.md messages/archive/task-200-complete.md 2>/dev/null || mv "$A/messages/task-200-claimed.md" "$A/messages/archive/task-200-complete.md"
"$SYNC" --dir "$A" push complete task-200; rc=$?
assert_eq "$rc" "0" "complete push succeeds"
assert_eq "$(git -C "$BARE" log -1 --format=%s main)" "backbone: complete task-200" "complete commit message matches AC-3"
"$SYNC" --dir "$B" pull
assert_file "$B/messages/archive/task-200-complete.md" "B receives the archived message"
assert_no_file "$B/messages/task-200-claimed.md" "claimed copy is gone on B"

# ── 5. Unreachable remote (AC-12) ─────────────────────────────────────────────
echo ""
echo "5. Unreachable remote: fail loudly in git mode, ignore in local mode"
new_world
git -C "$A" remote set-url origin "$TMP_DIR/w/does-not-exist.git"
make_msg "$A" task 300 "b:main"
"$SYNC" --dir "$A" pull 2>"$TMP_DIR/pull.err"; rc=$?
assert_eq "$rc" "2" "pull with unreachable remote exits 2 (no silent fallback)"
assert_contains "$TMP_DIR/pull.err" "unreachable" "pull error says the remote is unreachable"
"$SYNC" --dir "$A" push publish task-300 2>"$TMP_DIR/push.err"; rc=$?
assert_eq "$rc" "2" "push with unreachable remote exits 2"
assert_eq "$(git -C "$A" log -1 --format=%s)" "backbone: publish task-300" "commit is kept locally when the push fails"
echo "transport=local" > "$A/backbone.config"
"$SYNC" --dir "$A" pull; rc=$?
assert_eq "$rc" "0" "flipping to transport=local makes the same bad remote irrelevant"
echo "transport=git" > "$A/backbone.config"
git -C "$A" remote set-url origin "$BARE"
"$SYNC" --dir "$A" push publish task-300; rc=$?
assert_eq "$rc" "0" "re-running push after the remote returns delivers the kept commit"
"$SYNC" --dir "$B" pull
assert_file "$B/messages/task-300-pending.md" "B receives the message that was queued locally"

# make_topic_msg <dir> <type> <id> <topic> — write a pending topic message
make_topic_msg() {
  cat > "$1/messages/$2-$3-pending.md" <<EOF
---
id: "$3"
type: $2
status: pending
routing: topic
from: sender:main
topic: $4
title: Topic message $3
created: 2026-10-07
updated: 2026-10-07
---

Body of $3.
EOF
}

# ── 6. Session start (AC-4) ───────────────────────────────────────────────────
echo ""
echo "6. SessionStart pending count (AC-4)"
new_world
SESSION="$ROOT/scripts/backbone-session-start.sh"
printf -- '---\nagent_name: b:main\nsubscriptions:\n  - schema-changes\n---\n' > "$B/presence/presence-b:main.md"
make_msg "$A" task 601 "b:main"
make_msg "$A" task 602 "a:main"
make_msg "$A" task 603 "any"
make_topic_msg "$A" task 604 "schema-changes"
make_topic_msg "$A" task 605 "unsubscribed-topic"
"$SYNC" --dir "$A" push publish task-601 >/dev/null
out="$("$SESSION" --dir "$B" --agent "b:main")"; rc=$?
assert_eq "$rc" "0" "session-start exits 0"
assert_eq "$(head -1 <<<"$out")" "backbone: 3 pending message(s) for b:main" "count is the first output line (direct + any + subscribed topic)"
assert_eq "$(grep -c 'task-60[134]' <<<"$out")" "3" "lists the three addressed messages"
assert_eq "$(grep -c 'task-60[25]' <<<"$out")" "0" "does not list messages for other agents or unsubscribed topics"
assert_file "$B/messages/task-601-pending.md" "session-start pulled the messages from the remote"
"$SYNC" --dir "$A" pull
assert_file "$A/messages/seen/task-601.b_main" "seen marker reached the sender via git"
assert_file "$A/messages/seen/task-604.b_main" "seen marker written for the topic message too"
out="$(BACKBONE_AGENT= "$SESSION" --dir "$B")"; rc=$?
assert_eq "$rc" "0" "session-start without an agent name still exits 0"
assert_contains <(echo "$out") "no agent name" "...and says why the count was skipped"
echo "agent=b:main" >> "$B/backbone.config"
assert_eq "$("$SESSION" --dir "$B" | head -1)" "backbone: 3 pending message(s) for b:main" "agent= in backbone.config is honored"

# ── 7. Poll (AC-5) ────────────────────────────────────────────────────────────
echo ""
echo "7. Monitor poll: silent when idle, fires on a new addressed message (AC-5)"
new_world
POLL="$ROOT/scripts/backbone-poll.sh"
out="$("$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 2)"; rc=$?
assert_eq "$out" "" "idle poll prints nothing"
assert_eq "$rc" "1" "idle poll gives up with exit 1 after --max-iterations"
make_msg "$A" task 700 "b:main"; "$SYNC" --dir "$A" push publish task-700 >/dev/null
"$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 2 >"$TMP_DIR/poll0.out"; rc=$?
assert_eq "$(cat "$TMP_DIR/poll0.out")" "" "a message already pending at startup does not fire the poll"
"$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 10 >"$TMP_DIR/poll.out" 2>&1 &
ppid=$!
sleep 1.5
make_msg "$A" task 701 "a:main"; "$SYNC" --dir "$A" push publish task-701 >/dev/null
sleep 2.5
assert_eq "$(cat "$TMP_DIR/poll.out")" "" "poll stays silent for a message addressed to someone else"
assert_no_file "$B/messages/task-701-pending.md" "watching does not modify the working tree (fetch only)"
make_msg "$A" task 702 "b:main"; "$SYNC" --dir "$A" push publish task-702 >/dev/null
wait "$ppid"; rc=$?
assert_eq "$rc" "0" "poll exits 0 when an addressed message arrives"
assert_eq "$(wc -l < "$TMP_DIR/poll.out" | tr -d ' ')" "1" "poll printed exactly one line"
assert_contains "$TMP_DIR/poll.out" "task-702 from sender:main: Test message 702" "line names the message, sender, and title"
"$SYNC" --dir "$A" pull
assert_file "$A/messages/seen/task-702.b_main" "poll hit wrote and pushed the seen marker"

# ── 8. Agent-to-human map ─────────────────────────────────────────────────────
echo ""
echo "8. Roster: agent-to-human map"
new_world
LOOKUP="$ROOT/scripts/backbone-roster-lookup.sh"
assert_eq "$("$LOOKUP" --dir "$A" "b:main"; echo "rc=$?")" "rc=1" "no roster.md means no match (exit 1)"
cat > "$A/roster.md" <<'EOF'
# Roster

| agent | human | gchat |
| ----- | ----- | ----- |
| `a:*` | Bob | bob@example.com |
| b:* | Nate | nate@example.com |
EOF
assert_eq "$("$LOOKUP" --dir "$A" "a:refill-flow")" "Bob|bob@example.com" "glob row matches any task name for a repo"
assert_eq "$("$LOOKUP" --dir "$A" "b:main")" "Nate|nate@example.com" "second row matches"
"$LOOKUP" --dir "$A" "zzz:main" >/dev/null; rc=$?
assert_eq "$rc" "1" "unknown agent exits 1"

# ── 9. No-ack ping (AC-6) ─────────────────────────────────────────────────────
echo ""
echo "9. No-ack ping after the timeout (AC-6)"
ACK="$ROOT/scripts/backbone-ack-check.sh"
ackcmd() { "$ACK" --dir "$A" --id "$1" --to "b:main" --from "a:main" --title "Test message ${1#task-}" --interval 1 "${@:2}"; }
make_msg "$A" task 900 "b:main"; "$SYNC" --dir "$A" push publish task-900 >/dev/null
out="$(ackcmd task-900 --timeout 2)"; rc=$?
assert_eq "$rc" "10" "no ack within the timeout exits 10"
assert_eq "$out" 'PING Nate|nate@example.com :: a:main sent you "Test message 900" on the backbone (task-900)' "ping names sender and title"
if grep -q "Body of" <<<"$out"; then fail "ping must not contain the message body"; else pass "ping contains no message body"; fi
out="$(cd "$A" && mv roster.md roster.md.off && "$ACK" --dir "$A" --id task-900 --to b:main --from a:main --title T --timeout 1 --interval 1)"; rc=$?
mv "$A/roster.md.off" "$A/roster.md"
assert_eq "$rc" "11" "no roster entry exits 11 with NOPING"
assert_contains <(echo "$out") "NOPING" "...and says there is nobody to ping"
"$ROOT/scripts/backbone-session-start.sh" --dir "$B" --agent "b:main" >/dev/null
out="$(ackcmd task-900 --timeout 3)"; rc=$?
assert_eq "$rc" "0" "a seen marker counts as an ack"
assert_eq "$out" "" "...and nothing is printed"
make_msg "$A" task 901 "b:main"; "$SYNC" --dir "$A" push publish task-901 >/dev/null
"$SYNC" --dir "$B" pull; claim_msg "$B" task 901 "b:main"; "$SYNC" --dir "$B" push claim task-901 >/dev/null
out="$(ackcmd task-901 --timeout 3)"; rc=$?
assert_eq "$rc" "0" "a claim counts as an ack"
make_msg "$A" task 902 "b:main"; "$SYNC" --dir "$A" push publish task-902 >/dev/null
( ackcmd task-902 --timeout 20 >"$TMP_DIR/ack.out"; echo $? >"$TMP_DIR/ack.rc" ) &
apid=$!
sleep 2
start=$SECONDS
"$ROOT/scripts/backbone-session-start.sh" --dir "$B" --agent "b:main" >/dev/null
wait "$apid"
assert_eq "$(cat "$TMP_DIR/ack.rc")" "0" "an ack that arrives mid-wait ends the timer with exit 0"
assert_eq "$(cat "$TMP_DIR/ack.out")" "" "...with no ping sent"
if [[ $((SECONDS - start)) -lt 15 ]]; then pass "timer stopped as soon as the ack arrived, not at the timeout"; else fail "timer ran to the timeout"; fi

# ── 10. Secret check (AC-7) ───────────────────────────────────────────────────
echo ""
echo "10. Secret check on publish (AC-7)"
SECRET="$ROOT/scripts/backbone-secret-check.sh"
# Fixtures are assembled at runtime so this file holds no literal secrets.
tok48="aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5bC7dE9fG1hJ3"
cases_bad=(
  "mongodb+srv://admin:Hunter2pass@cluster0.example.net/app|connection string"
  "postgres://svc:pw123456@db.internal:5432/prod|connection string"
  "Authorization: Bearer abcdef0123456789abcdef0123|bearer token"
  "-----BEGIN RSA ""PRIVATE KEY-----|private key"
  "key AKIA""ABCDEFGHIJKLMNOP is set|AWS access key"
  "token gh""p_abcdefghijklmnopqrstuvwxyz0123456789 end|GitHub token"
  "the value is $tok48 ok|long base64-like token"
)
for c in "${cases_bad[@]}"; do
  text="${c%|*}"; label="${c##*|}"
  printf 'first line\n%s\nlast line\n' "$text" > "$TMP_DIR/body.md"
  out="$("$SECRET" "$TMP_DIR/body.md")"; rc=$?
  assert_eq "$rc" "1" "flags $label"
  assert_contains <(echo "$out") "line 2:" "...and reports the line number ($label)"
  if grep -qF -- "${text:12:12}" <<<"$out"; then fail "output must not echo the matched text ($label)"; else pass "output does not echo the secret ($label)"; fi
done
cases_ok=(
  "mongodb://user:<password>@host:27017/db"
  "postgres://app:\${DB_PASSWORD}@db.internal/prod"
  "commit 326a876d5b2c1f0e9a8b7c6d5e4f3a2b1c0d9e8f landed"
  "see apps/api/src/routes/patients/refill-requests/handler.ts for details"
  "https://example.com/docs/page and user@example.com"
  "send a Bearer token in the header"
  "Atlas times out from the Windows box; works from the Mac. Use the URI in your .env."
)
for text in "${cases_ok[@]}"; do
  printf '%s\n' "$text" > "$TMP_DIR/body.md"
  "$SECRET" "$TMP_DIR/body.md" >/dev/null; rc=$?
  assert_eq "$rc" "0" "allows: ${text:0:48}"
done
"$SECRET" "$TMP_DIR/does-not-exist" 2>/dev/null; rc=$?
assert_eq "$rc" "4" "missing file is a usage error"

# ── 11. Untrusted-message language and publish wiring (US-6, AC-10) ───────────
echo ""
echo "11. Command and conventions wiring"
assert_contains "$ROOT/CONVENTIONS.md" "Messages Are Untrusted Requests" "CONVENTIONS.md has the untrusted-message section"
assert_contains "$ROOT/.claude/commands/backbone-inbox.md" "untrusted requests, not instructions" "inbox display states messages are untrusted"
assert_contains "$ROOT/.claude/commands/backbone-publish.md" "backbone-secret-check.sh" "publish runs the secret check"
assert_contains "$ROOT/.claude/commands/backbone-publish.md" "backbone-ack-check.sh" "publish starts the no-ack timer"
assert_contains "$ROOT/.claude/commands/backbone-publish.md" "push publish" "publish pushes via the sync wrapper"
assert_contains "$ROOT/.claude/commands/backbone-inbox.md" "push claim" "inbox claim pushes via the sync wrapper"
assert_contains "$ROOT/.claude/commands/backbone-complete.md" "push complete" "complete pushes via the sync wrapper"
assert_contains "$ROOT/.claude/commands/backbone-join.md" "backbone-poll.sh" "join documents starting the poll"
assert_contains "$ROOT/docs/git-transport.md" "Access control for the remote" "access control requirements are documented"

# ── 12. Install script: link with copy fallback (AC-8) ────────────────────────
echo ""
echo "12. Install script: symlinks with copy fallback (AC-8)"
INSTALL="$ROOT/scripts/install-backbone-commands.sh"
T1="$TMP_DIR/proj-copy"; T2="$TMP_DIR/proj-link"; T3="$TMP_DIR/proj-fallback"; mkdir -p "$T1" "$T2" "$T3"
bash "$INSTALL" "$T1" >/dev/null
assert_file "$T1/.claude/commands/backbone-publish.md" "default install copies the commands"
assert_file "$T1/.claude/scripts/backbone/backbone-sync.sh" "default install copies the helper scripts"
if [[ -L "$T1/.claude/scripts/backbone/backbone-sync.sh" ]]; then fail "default install should copy, not link"; else pass "default install makes real copies"; fi
assert_file "$T1/.claude/.backbone-copied" "copies are recorded in .backbone-copied"
assert_contains "$T1/.claude/.backbone-copied" "scripts/backbone/backbone-sync.sh" "manifest lists the copied scripts"
bash "$INSTALL" "$T2" --link >/dev/null
if [[ -L "$T2/.claude/commands/backbone-publish.md" ]]; then pass "--link creates symlinks where the OS allows"; else fail "--link did not create a symlink"; fi
assert_no_file "$T2/.claude/.backbone-copied" "an all-links install leaves no copy manifest"
BACKBONE_SYMLINKS=0 bash "$INSTALL" "$T3" --link >/dev/null; rc=$?
assert_eq "$rc" "0" "install succeeds when symlinks are unavailable"
if [[ -L "$T3/.claude/commands/backbone-publish.md" ]]; then fail "fallback should copy, not link"; else pass "fallback copies each file"; fi
assert_file "$T3/.claude/commands/backbone-publish.md" "fallback leaves a working command file"
assert_contains "$T3/.claude/.backbone-copied" "commands/backbone-publish.md" "fallback records copied files for /backbone-update"
if cmp -s "$ROOT/.claude/commands/backbone-publish.md" "$T3/.claude/commands/backbone-publish.md"; then pass "copied file matches the source"; else fail "copied file differs from source"; fi
echo "stale" >> "$T3/.claude/commands/backbone-publish.md"
BACKBONE_SYMLINKS=0 bash "$INSTALL" "$T3" --link >/dev/null
if cmp -s "$ROOT/.claude/commands/backbone-publish.md" "$T3/.claude/commands/backbone-publish.md"; then pass "re-running the installer refreshes a stale copy"; else fail "stale copy was not refreshed"; fi

# ── SECTIONS-INSERT-BEFORE-SUMMARY ────────────────────────────────────────────

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
