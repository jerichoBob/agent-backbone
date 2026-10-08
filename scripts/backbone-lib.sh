#!/usr/bin/env bash
# Shared helpers for the backbone git-transport scripts. Source this file; do not execute it.

# bb_config_get <dir> <key> — read key=value from <dir>/backbone.config (last wins, CR/space tolerant)
bb_config_get() {
  local f="$1/backbone.config"
  [[ -f "$f" ]] || return 0
  grep -E "^[[:space:]]*$2[[:space:]]*=" "$f" | tail -1 | sed -E "s/^[^=]*=[[:space:]]*//; s/[[:space:]\r]+\$//"
}

# bb_transport <dir> — print effective transport (local|git). Default local. Invalid value is an error.
bb_transport() {
  local v
  v="$(bb_config_get "$1" transport)"
  v="${v:-local}"
  case "$v" in
    local|git) echo "$v" ;;
    *) echo "backbone: invalid transport '$v' in $1/backbone.config (expected local or git)" >&2; return 4 ;;
  esac
}

# bb_fm_get <key> — read a scalar frontmatter value from stdin
bb_fm_get() {
  awk -v k="$1" '
    /^---[ \t\r]*$/ { n++; if (n == 2) exit; next }
    n == 1 && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v)
      gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^"|"$/, "", v)
      print v; exit
    }'
}

# bb_fm_list <key> — read a frontmatter list (inline [a, b] or "- a" block) from stdin, one item per line
bb_fm_list() {
  awk -v k="$1" '
    /^---[ \t\r]*$/ { n++; if (n == 2) exit; next }
    n != 1 { next }
    inlist && /^[ \t]*-[ \t]+/ { v = $0; sub(/^[ \t]*-[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v); gsub(/^"|"$/, "", v); print v; next }
    inlist { inlist = 0 }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^\[/) { gsub(/[\[\]]/, "", v); m = split(v, a, ","); for (i = 1; i <= m; i++) { gsub(/^[ \t"]+|[ \t"]+$/, "", a[i]); if (a[i] != "") print a[i] } }
      else if (v == "") inlist = 1
    }'
}

# bb_agent_subs <dir> <agent> — print the agent's topic subscriptions from its presence record
bb_agent_subs() {
  local f="$1/presence/presence-$2.md"
  [[ -f "$f" ]] && bb_fm_list subscriptions < "$f"
  return 0
}

# bb_safe_name <agent> — filesystem-safe form of an agent name (colons break on Windows)
bb_safe_name() { echo "$1" | tr ':/\\' '___'; }

# bb_for_agent <agent> <subs-newline-list> — stdin is a message; exit 0 if it is addressed to the agent
bb_for_agent() {
  local agent="$1" subs="$2" fm routing to topic
  fm="$(cat)"
  routing="$(bb_fm_get routing <<<"$fm")"
  to="$(bb_fm_get to <<<"$fm")"
  topic="$(bb_fm_get topic <<<"$fm")"
  if [[ "$routing" == "direct" && ( "$to" == "$agent" || "$to" == "any" ) ]]; then return 0; fi
  if [[ "$routing" == "topic" && -n "$topic" ]] && grep -qxF "$topic" <<<"$subs"; then return 0; fi
  return 1
}

# bb_pending_for <dir> <agent> [ref] — print basenames of pending messages addressed to agent.
# With <ref> (e.g. origin/main) read from that git ref instead of the working tree.
bb_pending_for() {
  local dir="$1" agent="$2" ref="${3:-}" subs f name
  subs="$(bb_agent_subs "$dir" "$agent")"
  if [[ -n "$ref" ]]; then
    while IFS= read -r f; do
      name="$(basename "$f")"
      git -C "$dir" show "$ref:$f" 2>/dev/null | bb_for_agent "$agent" "$subs" && echo "$name"
    done < <(git -C "$dir" ls-tree --name-only "$ref" messages/ 2>/dev/null | grep -E -- '-pending\.md$')
  else
    for f in "$dir"/messages/*-pending.md; do
      [[ -f "$f" ]] || continue
      bb_for_agent "$agent" "$subs" < "$f" && basename "$f"
    done
  fi
  return 0
}

# bb_msg_summary <dir> <basename> [ref] — one line: "<type-id> from <from>: <title>"
bb_msg_summary() {
  local dir="$1" name="$2" ref="${3:-}" fm from title base
  if [[ -n "$ref" ]]; then fm="$(git -C "$dir" show "$ref:messages/$name" 2>/dev/null)"; else fm="$(cat "$dir/messages/$name")"; fi
  from="$(bb_fm_get from <<<"$fm")"
  title="$(bb_fm_get title <<<"$fm")"
  base="${name%-pending.md}"
  echo "$base from ${from:-unknown}${title:+: $title}"
}

# bb_resolve_agent <dir> <flag-value> — agent name from flag, BACKBONE_AGENT, or backbone.config agent=
bb_resolve_agent() {
  local a="${2:-${BACKBONE_AGENT:-}}"
  [[ -n "$a" ]] || a="$(bb_config_get "$1" agent)"
  echo "$a"
}

# bb_mark_seen <dir> <message-basename> <agent> — write the receiver's seen marker; prints 1 if newly created
# Marker: messages/seen/<type>-<id>.<agent-safe>  (the sender's ack check looks for it)
bb_mark_seen() {
  local dir="$1" base="${2%-pending.md}" agent="$3" f
  f="$dir/messages/seen/$base.$(bb_safe_name "$agent")"
  [[ -f "$f" ]] && return 0
  mkdir -p "$dir/messages/seen"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$f"
  echo 1
}

# bb_default_dir <script-dir> — $BACKBONE_DIR, else ../agent-backbone from the cwd, else the script's repo
bb_default_dir() {
  if [[ -n "${BACKBONE_DIR:-}" ]]; then echo "$BACKBONE_DIR"
  elif [[ -d ../agent-backbone ]]; then echo ../agent-backbone
  else echo "$1/.."; fi
}
