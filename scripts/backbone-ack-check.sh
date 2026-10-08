#!/usr/bin/env bash
# Sender-side no-ack timer. After publishing a direct message, watch for the receiver to
# acknowledge it (claim it, or write a seen marker). If nothing arrives within the timeout,
# print a PING line for the sender's session to deliver over Google Chat.
#
# The ping names the sender and the title only — never the message body.
# Limit: this runs in the sender's session. If that session closes first, no ping is sent.
#
# Usage: backbone-ack-check.sh [--dir DIR] --id <type-id> --to AGENT --from AGENT --title TEXT
#                              [--timeout 300] [--interval 15]
# Output (stdout), only on timeout:
#   PING <human>|<gchat> :: <from> sent you "<title>" on the backbone (<type-id>)
#   NOPING no roster entry for <to>
# Exit: 0 acknowledged in time (silent) · 10 timed out, PING printed · 11 timed out, no roster entry
#       · 4 usage
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=backbone-lib.sh
source "$SELF_DIR/backbone-lib.sh"

DIR=""; ID=""; TO=""; FROM=""; TITLE=""; TIMEOUT=300; INTERVAL=15
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) echo "backbone-ack-check: unknown argument $1" >&2; exit 4 ;;
  esac
done
[[ -n "$ID" && -n "$TO" && -n "$FROM" ]] || { echo "usage: backbone-ack-check.sh --id <type-id> --to AGENT --from AGENT --title TEXT" >&2; exit 4; }
[[ -n "$DIR" ]] || DIR="$(bb_default_dir "$SELF_DIR")"
DIR="$(cd "$DIR" && pwd)"
MODE="$(bb_transport "$DIR")" || exit 4

REF=""
if [[ "$MODE" == "git" ]]; then
  REF="origin/$(git -C "$DIR" rev-parse --abbrev-ref HEAD)"
fi

# acked — true when the message was claimed/completed, or any seen marker exists for it
acked() {
  local names
  if [[ -n "$REF" ]]; then
    git -C "$DIR" fetch -q origin 2>/dev/null || true
    names="$(git -C "$DIR" ls-tree -r --name-only "$REF" messages/ 2>/dev/null)"
  else
    names="$(cd "$DIR" && find messages -type f 2>/dev/null)"
  fi
  grep -qE "(^|/)($ID-(claimed|complete|archived)\.md|seen/$ID\.[^/]+)$" <<<"$names"
}

deadline=$((SECONDS + TIMEOUT))
while :; do
  acked && exit 0
  [[ $SECONDS -ge $deadline ]] && break
  sleep "$INTERVAL"
done

entry="$(bash "$SELF_DIR/backbone-roster-lookup.sh" --dir "$DIR" "$TO")" || {
  echo "NOPING no roster entry for $TO"
  exit 11
}
echo "PING $entry :: $FROM sent you \"$TITLE\" on the backbone ($ID)"
exit 10
