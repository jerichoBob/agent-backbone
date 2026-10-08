#!/usr/bin/env bash
# End-to-end check in a scratch project: install commands + hooks with the real installer, then run the
# hook commands EXACTLY as written into the project's settings.json (read back with jq, executed with
# `bash -c` from the project dir, session JSON on stdin), as Claude Code would. Scratch HOME throughout;
# the real ~/.claude is never read or written. The backbone module is copied to <scratch HOME>/.claude/aidev-toolkit/
# modules/backbone, so the ~ path in the generated hook commands resolves for real. Does NOT launch a Claude Code session — see docs/e2e-check.md.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
MODSRC=""
for c in "${BACKBONE_MODULE:-}" "$HOME/.claude/aidev-toolkit/modules/backbone" "$ROOT/../aidev-toolkit/modules/backbone"; do
  [[ -n "$c" && -f "$c/scripts/backbone-sync.sh" ]] && { MODSRC="$(cd "$c" && pwd)"; break; }
done
[[ -n "$MODSRC" ]] || { echo "BLOCKED: backbone module not found"; exit 2; }
export HOME="$W/home"; mkdir -p "$HOME/.claude/aidev-toolkit/modules"; cp -R "$MODSRC" "$HOME/.claude/aidev-toolkit/modules/backbone"
MOD="$HOME/.claude/aidev-toolkit/modules/backbone"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_AUTHOR_NAME=T GIT_COMMITTER_NAME=T GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_EMAIL=t@e
F=0; ok(){ echo "ok:   $*"; }; bad(){ echo "FAIL: $*"; F=$((F+1)); }

mkdir -p "$W/work"; cp -R "$ROOT" "$W/work/agent-backbone"; rm -rf "$W/work/agent-backbone/.git"; rm -rf "$W/work/agent-backbone/scripts"
git init -q -b main "$W/work/agent-backbone"
printf 'agent=demo:e2e\n' > "$W/work/agent-backbone/backbone.config"
P="$W/work/proj"; mkdir -p "$P"; git -C "$P" init -q -b main; git -C "$P" config user.name E2E
echo '{"model":"keep-me","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo existing"}]}]}}' > /dev/null
mkdir -p "$P/.claude"; echo '{"model":"keep-me","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo existing"}]}]}}' > "$P/.claude/settings.json"

bash "$MOD/scripts/backbone-install-hooks.sh" "$P" </dev/null >"$W/install.out" 2>&1; echo "hook installer rc=$? (no terminal, no --yes: expect consent withheld, rc 5)"
grep -q "modules/backbone" "$P/.claude/settings.json" && bad "hooks added without consent" || ok "no consent, no change to settings.json"
bash "$MOD/scripts/backbone-install-hooks.sh" "$P" --yes >"$W/hooks.out" 2>&1; rc=$?; [[ $rc -eq 0 ]] && ok "installer with --yes" || bad "installer rc=$rc: $(cat "$W/hooks.out")"
bash "$MOD/scripts/backbone-install-hooks.sh" "$P" --yes >/dev/null 2>&1
[[ "$(jq '[.hooks.SessionStart[].hooks[].command | select(contains("modules/backbone"))] | length' "$P/.claude/settings.json")" == 1 ]] && ok "idempotent: one backbone SessionStart hook after two runs" || bad "duplicate hook"
[[ "$(jq -r .model "$P/.claude/settings.json")" == keep-me && "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$P/.claude/settings.json")" == "echo existing" ]] && ok "existing settings and hook kept" || bad "existing settings lost"

START="$(jq -r '.hooks.SessionStart[].hooks[].command | select(contains("modules/backbone"))' "$P/.claude/settings.json")"
END="$(jq -r '.hooks.SessionEnd[].hooks[].command' "$P/.claude/settings.json")"
echo "start hook: $START"
OUT="$(cd "$P" && echo '{"session_id":"e2e-1"}' | CLAUDE_PROJECT_DIR="$P" bash -c "$START" 2>&1)"; echo "$OUT" | sed 's/^/   | /'
[[ "$(head -1 <<<"$OUT")" == "backbone: 0 pending message(s) for demo:e2e~"* ]] && ok "count is the first line" || bad "first line wrong"
NAME="$(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-presence.sh --dir ../agent-backbone me)"; ok "me -> $NAME"
grep -l "status: active" "$W/work/agent-backbone"/presence/*.md >/dev/null 2>&1 && ok "presence file active" || bad "no active presence"
OUT2="$(cd "$P" && echo '{"session_id":"e2e-1"}' | CLAUDE_PROJECT_DIR="$P" bash -c "$START" 2>&1)"
ls "$W/work/agent-backbone"/presence/; [[ "$(grep -l "^agent_name: demo:e2e~" "$W/work/agent-backbone"/presence/*.md | wc -l | tr -d " ")" == 1 ]] && ok "resume with the same session_id re-joins (one session record)" || bad "resume created another session record"
(cd "$P" && echo '{"session_id":"e2e-1"}' | CLAUDE_PROJECT_DIR="$P" bash -c "$END" >"$W/end.out" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "end hook exit 0" || bad "end hook rc=$rc"
grep -q "status: inactive" "$W/work/agent-backbone"/presence/*.md && ok "presence marked inactive" || { bad "not inactive"; cat "$W/work/agent-backbone"/presence/*.md; }
(cd "$P" && echo 'not json' | CLAUDE_PROJECT_DIR="$P" bash -c "$START" >/dev/null 2>&1); [[ $? -eq 0 ]] && ok "hook exits 0 on garbage stdin" || bad "hook failed on garbage"
(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-start.sh --dir /nonexistent </dev/null >/dev/null 2>&1); [[ $? -eq 0 ]] && ok "hook exits 0 with missing backbone dir" || bad "hook failed on missing dir"
C="$(find "$W/work" -path "*/.git" -prune -o -name "*:*" -print)"; [[ -z "$C" ]] && ok "no colon filenames" || bad "colon filenames: $C"
[[ "$HOME" == "$W/home" ]] && ok "ran under the scratch HOME ($HOME); the real ~/.claude was never touched"
echo; [[ $F -eq 0 ]] && echo "E2E OK" || echo "E2E: $F failure(s)"; exit $((F>0))
