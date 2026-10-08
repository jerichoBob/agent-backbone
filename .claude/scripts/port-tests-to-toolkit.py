#!/usr/bin/env python3
"""Derive the toolkit's tests/test-backbone-*.sh from agent-backbone's tooling tests (v6 Phase 5).
Reads the originals from git (default HEAD:tests/...) so it is re-runnable after agent-backbone's own
tests have been cut down. Usage: python3 -I .claude/scripts/port-tests-to-toolkit.py [TOOLKIT_DIR] [REV]"""
import re, subprocess, sys, pathlib
tk = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "../aidev-toolkit")
rev = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
SECTION6 = r'''echo ""
echo "6. The toolkit installer ships every skill and makes every script executable"
INSTALL_SH="$(cd "$MOD/../.." && pwd)/scripts/install.sh"
arr="$(sed -n '/^BACKBONE_SKILLS=(/,/^)/p' "$INSTALL_SH")"
for f in "$SKILLS"/*.md; do
  n="$(basename "$f")"
  grep -q "\"$n\"" <<<"$arr" && pass "install.sh lists $n" || fail "install.sh does not list $n (BACKBONE_SKILLS)"
done
while IFS= read -r listed; do
  [[ -f "$SKILLS/$listed" ]] && pass "$listed is listed and exists" || fail "install.sh lists $listed, which is not in modules/backbone/skills"
done < <(grep -oE '"[a-z-]+\.md"' <<<"$arr" | tr -d '"')
for s in "$MOD"/scripts/*.sh; do
  [[ -x "$s" ]] && pass "$(basename "$s") is executable in the repo" || fail "$(basename "$s") is not executable"
done
grep -q 'modules/backbone/scripts/\*.sh' "$INSTALL_SH" && pass "install.sh chmods the module scripts" || fail "install.sh does not chmod the module scripts"
for t in backbone.config.example roster.md hooks-settings.json; do
  [[ -f "$MOD/templates/$t" ]] && pass "template $t exists" || fail "template $t is missing"
done

echo ""
echo "7. Install into a scratch HOME (never the real ~/.claude): skills land, script paths resolve"
REPO="$(cd "$MOD/../.." && pwd)"
SH="$TMP_DIR/home"; mkdir -p "$SH/.claude"
cp -R "$REPO" "$SH/.claude/aidev-toolkit"
if [[ -z "${GH_TOKEN:-}" ]]; then GH_TOKEN="$(gh auth token 2>/dev/null || true)"; export GH_TOKEN; fi
HOME="$SH" bash "$REPO/scripts/install.sh" --quiet >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && pass "install.sh exits 0 in a scratch HOME" || fail "install.sh exited $rc in a scratch HOME"
for c in "${NEW[@]}" backbone-setup; do
  [[ -f "$SH/.claude/commands/$c.md" ]] && pass "installed commands/$c.md" || fail "install.sh did not install commands/$c.md"
done
[[ -f "$SH/.claude/skills/backbone.md" ]] && pass "installed skills/backbone.md" || fail "install.sh did not install skills/backbone.md"
if find "$SH/.claude/commands" "$SH/.claude/skills" -name 'backbone*.md' -type l | grep -q .; then fail "backbone skills must be real files, not symlinks"; else pass "backbone skills are real files"; fi
[[ -f "$SH/.claude/commands/backbone-setup.md" ]] && ! ls "$SH/.claude/commands" | grep -q '^backbone-setup.md.bak' && pass "backbone-setup is installed from the module" || fail "backbone-setup missing"
# every absolute script path an installed skill names resolves under the scratch HOME
miss=0
for f in "$SH/.claude/commands"/backbone*.md; do
  grep -q 'aidev-toolkit/modules/backbone/scripts' "$f" || continue
  while IFS= read -r sc; do [[ -x "$SH/.claude/aidev-toolkit/modules/backbone/scripts/$sc" ]] || { fail "$(basename "$f") names $sc, not executable after install"; miss=1; }; done < <(grep -oE 'backbone-[a-z-]+\.sh' "$f" | sort -u)
done
[[ $miss -eq 0 ]] && pass "every script an installed skill names is executable under the module path"
[[ -z "$(ls "$SH/.claude/aidev-toolkit/modules/backbone/scripts" | grep -v '^backbone-')" ]] && pass "no stray files in the module scripts dir" || fail "stray files in module scripts"
'''

def strip_aliases(s):
    """The eight old per-project command names are not ported, so drop their checks."""
    s = re.sub(r'^ALIASES=\(.*\)\n', '', s, flags=re.M)
    s = re.sub(r'# alias -> .*?\n\}\n', '', s, flags=re.S)           # declare_target()
    s = s.replace(' "${ALIASES[@]}"', '')
    a = s.index('echo "4. Aliases forward'); b = s.index('for sub in join leave')
    s = s[:a] + 'echo "4. /backbone documents every subcommand"\n' + s[b:]
    s = re.sub(r'(for c in "\$\{NEW\[@\]\}"; do\n  if grep -E .presence)', r'\1', s)
    s = s.replace('for c in backbone backbone-send backbone-inbox backbone-done; do\n  bad=', 'for c in backbone backbone-send backbone-inbox backbone-done; do\n  bad=')
    return s

def orig(name): return subprocess.check_output(["git", "show", f"{rev}:tests/{name}"], text=True)
HDR = 'MOD="$(cd "$(dirname "$0")/../modules/backbone" && pwd)"\nSKILLS="$MOD/skills"\n'
def common(s):
    # run-all.sh feeds its script list through stdin; the session hooks read stdin, so shield it
    s = re.sub(r'^(set -[a-z]+[^\n]*\n)', r'\1exec </dev/null   # hooks read stdin; do not eat the script list that run-all.sh pipes in\n', s, count=1, flags=re.M)
    s = s.replace('ROOT="$(cd "$(dirname "$0")/.." && pwd)"\n', HDR)
    s = s.replace("$ROOT/scripts/", "$MOD/scripts/").replace("$ROOT/.claude/commands/", "$SKILLS/")
    s = s.replace("Run from the agent-backbone root: bash tests/", "Run from the aidev-toolkit root: bash tests/")
    return s
def cut(s, start_marker, end_marker):
    a = s.index(start_marker); b = s.index(end_marker) if end_marker else len(s)
    return s[:a] + s[b:]

# git transport: drop CONVENTIONS/docs asserts (repo content) and the per-project installer section
s = common(orig("test-git-transport.sh"))
s = re.sub(r'assert_contains "\$ROOT/(CONVENTIONS|docs/)[^\n]*\n', '', s)
s = cut(s, "# ── 12. Install script", "# ── 13. Notifier")
s = re.sub(r'if git -C "\$A" check-ignore[^\n]*\n', '', s)
s = s.replace('"bash .claude/scripts/backbone/backbone-session-start.sh --dir ../agent-backbone"', '"bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-start.sh --dir ../agent-backbone"')
s = s.replace('"bash .claude/scripts/backbone/backbone-session-end.sh --dir ../agent-backbone"', '"bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-end.sh --dir ../agent-backbone"')
s = cut(s, 'INST="$MOD/scripts/install-backbone-commands.sh"', "# ── SECTIONS-INSERT-BEFORE-SUMMARY")
(tk / "tests/test-backbone-git-transport.sh").write_text(s)

# presence: sections 1-3 check the repo's own presence/ docs and stay in agent-backbone
s = common(orig("test-presence-lifecycle.sh"))
s = cut(s, "# ── Test 1: presence/ directory and docs exist", "# ── Test 4")
s = s.replace('PRESENCE_DIR="$ROOT/presence"\n', '').replace('--dir "$ROOT" safe', '--dir "$TMP_DIR" safe')
s = s.replace('source "$ROOT/scripts/backbone-lib.sh"', 'source "$MOD/scripts/backbone-lib.sh"')
s = s.replace('COMMANDS_DIR="$(cd "$(dirname "$0")/.." && pwd)/.claude/commands"', 'COMMANDS_DIR="$SKILLS"')
s = re.sub(r'assert_file_exists "\$COMMANDS_DIR/backbone-(join|leave|roster)\.md"[^\n]*\n', '', s)
s = s.replace('COMMANDS_DIR="$SKILLS"\n', 'COMMANDS_DIR="$SKILLS"\nassert_file_exists "$COMMANDS_DIR/backbone.md" "/backbone (status, join, leave) exists"\n', 1)
(tk / "tests/test-backbone-presence.sh").write_text(s)

# commands: the installer section becomes a check of the toolkit installer (written by hand, see below)
s = common(orig("test-commands.sh"))
s = s.replace('CMDS="$ROOT/.claude/commands"', 'CMDS="$SKILLS"').replace('CMDS="$ROOT/.claude/commands"', 'CMDS="$SKILLS"')
s = strip_aliases(s)
s = s.replace('[[ "$(wc -l < "$f" | tr -d \' \')" -le 10 ]]', '[[ "$(awk \'f{n++} /^---$/{c++; if(c==2)f=1} END{print n+0}\' "$f")" -le 10 ]]')
s = s.replace('if [[ -f "$ROOT/$ref" ]]; then', 'if [[ -f "$SKILLS/$(basename "$ref")" ]]; then')
s = cut(s, 'echo "6. The installer ships every command and script"', 'echo ""\necho "═══"') if False else s
a = s.index('echo ""\necho "6. The installer ships')
b = s.index('echo ""\necho "═══')
s = s[:a] + SECTION6 + s[b:]
(tk / "tests/test-backbone-commands.sh").write_text(s)
for f in ("git-transport", "presence", "commands"):
    (tk / f"tests/test-backbone-{f}.sh").chmod(0o755)
print("ported")
