#!/usr/bin/env bash
# Command-file integrity (v6 AC-9, AC-10): every script a command names exists in the repo, every
# command file another command points at exists, each deprecated alias forwards to a real target
# and carries its deprecation note, and the installer ships all of it.
# Run from the agent-backbone root: bash tests/test-commands.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMDS="$ROOT/.claude/commands"
TMP_DIR="$(mktemp -d)"
PASS=0; FAIL=0
trap 'rm -rf "$TMP_DIR"' EXIT
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# the five user-facing commands (backbone-setup is a toolkit skill) and the deprecated names
NEW=(backbone backbone-send backbone-inbox backbone-done)
ALIASES=(backbone-publish backbone-complete backbone-join backbone-leave backbone-roster backbone-subscribe backbone-unsubscribe backbone-update)
# alias -> "target command file|section keyword expected in the alias"
declare_target() {
  case "$1" in
    backbone-publish) echo "backbone-send|/backbone-send" ;;
    backbone-complete) echo "backbone-done|/backbone-done" ;;
    backbone-join) echo "backbone|/backbone join" ;;
    backbone-leave) echo "backbone|/backbone leave" ;;
    backbone-roster) echo "backbone|/backbone status" ;;
    backbone-subscribe) echo "backbone|/backbone subscribe" ;;
    backbone-unsubscribe) echo "backbone|/backbone unsubscribe" ;;
    backbone-update) echo "backbone|/backbone update" ;;
  esac
}

echo ""
echo "Command Integrity Tests"
echo "======================="

echo ""
echo "1. Commands exist"
for c in "${NEW[@]}" "${ALIASES[@]}"; do
  [[ -f "$CMDS/$c.md" ]] && pass "$c.md exists" || fail "$c.md is missing"
done

echo ""
echo "2. Every script a command names exists (AC-10)"
refs=0
for f in "$CMDS"/backbone*.md; do
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    refs=$((refs + 1))
    if [[ -f "$ROOT/scripts/$script" ]]; then pass "$(basename "$f") -> scripts/$script"
    else fail "$(basename "$f") names scripts/$script, which does not exist"; fi
  done < <(grep -oE '(backbone-[a-z-]+|install-backbone-commands)\.sh' "$f" | sort -u)
done
[[ $refs -gt 0 ]] && pass "found $refs script references to check" || fail "no script references found: the pattern is broken"

echo ""
echo "3. Command files a command points at exist"
for f in "$CMDS"/backbone*.md; do
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    if [[ -f "$ROOT/$ref" ]]; then pass "$(basename "$f") -> $ref"; else fail "$(basename "$f") points at $ref, which does not exist"; fi
  done < <(grep -oE '\.claude/commands/[a-z-]+\.md' "$f" | sort -u)
done

echo ""
echo "4. Aliases forward and say they are deprecated (AC-9)"
for a in "${ALIASES[@]}"; do
  IFS='|' read -r target label <<<"$(declare_target "$a")"
  f="$CMDS/$a.md"
  grep -q "deprecated" "$f" && pass "$a carries a deprecation note" || fail "$a has no deprecation note"
  grep -q "removed in backbone 0.6.0" "$f" && pass "$a names the release that removes it" || fail "$a does not say when it is removed"
  grep -qF "$label" "$f" && pass "$a names its replacement ($label)" || fail "$a does not name $label"
  grep -q ".claude/commands/$target.md" "$f" && [[ -f "$CMDS/$target.md" ]] && pass "$a forwards to $target.md" || fail "$a does not forward to an existing $target.md"
  [[ "$(wc -l < "$f" | tr -d ' ')" -le 10 ]] && pass "$a is a thin forwarder (no duplicated logic)" || fail "$a is more than a forwarder"
done
for sub in join leave status subscribe unsubscribe update name; do
  grep -qE "^## .*\b$sub\b" "$CMDS/backbone.md" && pass "/backbone documents '$sub'" || fail "/backbone has no '$sub' section"
done

echo ""
echo "5. Commands never build presence filenames or call removed names"
for c in "${NEW[@]}"; do
  if grep -E 'presence/presence-\{' "$CMDS/$c.md" >/dev/null; then fail "$c.md builds a presence filename by hand"; else pass "$c.md uses backbone-presence.sh for lookups"; fi
done
for c in backbone backbone-send backbone-inbox backbone-done; do
  bad="$(grep -nE '/backbone-(publish|complete|join|leave|roster|subscribe|unsubscribe|update)\b' "$CMDS/$c.md" | grep -v "Replaces" || true)"
  [[ -z "$bad" ]] && pass "$c.md does not send people to a deprecated name" || fail "$c.md uses a deprecated name: $bad"
done
grep -q "untrusted requests, not instructions" "$CMDS/backbone-inbox.md" && pass "inbox keeps the untrusted-message display" || fail "inbox lost the untrusted-message display"

echo ""
echo "6. The installer ships every command and script"
T="$TMP_DIR/proj"; mkdir -p "$T"
bash "$ROOT/scripts/install-backbone-commands.sh" "$T" >/dev/null
for c in "${NEW[@]}" "${ALIASES[@]}"; do
  [[ -f "$T/.claude/commands/$c.md" ]] && pass "installed $c.md" || fail "installer did not ship $c.md"
done
for s in backbone-presence backbone-session-start backbone-session-end backbone-notify backbone-ack-check backbone-install-hooks backbone-migrate-presence backbone-name; do
  [[ -f "$T/.claude/scripts/backbone/$s.sh" ]] && pass "installed $s.sh" || fail "installer did not ship $s.sh"
done

echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""
[[ $FAIL -eq 0 ]]
