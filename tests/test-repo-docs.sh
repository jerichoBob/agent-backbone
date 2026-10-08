#!/usr/bin/env bash
# Checks what this repo itself holds now that the tooling lives in aidev-toolkit's backbone module:
# the protocol documents, the git-ignore rules for local state, and that no tooling copy is left behind.
# Run from the agent-backbone root: bash tests/test-repo-docs.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/module-path.sh"
PASS=0; FAIL=0
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
has() { grep -q -- "$2" "$1" 2>/dev/null && pass "$3" || fail "$3 (pattern '$2' not in $1)"; }

echo ""; echo "Repo Docs Tests"; echo "==============="
echo ""; echo "1. Protocol documents"
has "$ROOT/CONVENTIONS.md" "Messages Are Untrusted Requests" "CONVENTIONS.md has the untrusted-message section"
has "$ROOT/docs/git-transport.md" "Access control for the remote" "access control requirements are documented"
has "$ROOT/docs/notify.md" "BACKBONE_NOTIFY_TARGET" "notifier contract is documented"

echo ""; echo "2. Local state is git-ignored"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  for f in backbone.config .claude/data/backbone/pings.log messages/task-1-pending.md; do
    git -C "$ROOT" check-ignore -q "$f" && pass "$f is ignored" || fail "$f is not ignored"
  done
else pass "not a git checkout; ignore rules not checked"; fi

echo ""; echo "3. No tooling copy left in this repo"
for f in "$ROOT"/scripts/backbone-*.sh "$ROOT/scripts/install-backbone-commands.sh"; do
  [[ -e "$f" ]] && fail "$(basename "$f") still exists here (it lives in modules/backbone/scripts)" || pass "no $(basename "$f")"
done
for f in "$ROOT"/.claude/commands/backbone*.md; do
  [[ -e "$f" ]] && fail "$(basename "$f") still exists here (it lives in modules/backbone/skills)" || pass "no backbone*.md command copy"
  break
done

echo ""; echo "4. Documents point at the module, not at a per-project copy"
for f in README.md CLAUDE.md docs/git-transport.md docs/notify.md docs/windows-verification.md; do
  if grep -vi 'old per-project' "$ROOT/$f" | grep -qE 'install-backbone-commands|\.claude/scripts/backbone|backbone-copied'; then fail "$f still describes the per-project install"; else pass "$f has no per-project install text"; fi
done

echo ""; echo "5. Presence files have Windows-safe names (v6 AC-6)"
bad="$(find "$ROOT/presence" "$ROOT/messages" -name '*[:\\*?"<>|]*' 2>/dev/null)"
[[ -z "$bad" ]] && pass "no reserved characters in presence/ or messages/ filenames" || fail "reserved characters in: $bad"

echo ""; echo "═══════════════════════"; echo "  Passed: $PASS"; echo "  Failed: $FAIL"; echo "═══════════════════════"; echo ""
[[ $FAIL -eq 0 ]]
