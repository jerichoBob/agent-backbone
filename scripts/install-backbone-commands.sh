#!/usr/bin/env bash
# Installs backbone slash commands and helper scripts into a target repo.
#   commands: <target>/.claude/commands/backbone-*.md
#   scripts:  <target>/.claude/scripts/backbone/backbone-*.sh
# Globs the sources — no explicit list to maintain.
#
# Usage: bash scripts/install-backbone-commands.sh <target-repo-path> [--link]
#
#   (default)  copy every file. Works everywhere, including Windows without symlink support.
#   --link     symlink instead, so edits to agent-backbone show up immediately. If a symlink
#              cannot be created (Windows without developer mode, some filesystems) that file
#              falls back to a copy. Set BACKBONE_SYMLINKS=0 to skip the symlink attempt and
#              exercise that fallback on any OS.
#
# Every file that was copied (not linked) is listed in <target>/.claude/.backbone-copied so
# /backbone-update knows which files are snapshots that need refreshing.

set -euo pipefail

BACKBONE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMD_SRC="$BACKBONE_DIR/.claude/commands"
SCRIPT_SRC="$BACKBONE_DIR/scripts"

usage() {
  echo "Usage: bash scripts/install-backbone-commands.sh <target-repo-path> [--link]"
  exit 1
}

[[ $# -lt 1 ]] && usage
TARGET_REPO="$1"; shift
LINK=0
for arg in "$@"; do
  case "$arg" in
    --link) LINK=1 ;;
    *) usage ;;
  esac
done

if [[ ! -d "$TARGET_REPO" ]]; then
  echo "Error: target repo not found: $TARGET_REPO"
  exit 1
fi

TARGET_REPO="$(cd "$TARGET_REPO" && pwd)"
CMD_DST="$TARGET_REPO/.claude/commands"
SCRIPT_DST="$TARGET_REPO/.claude/scripts/backbone"
MANIFEST="$TARGET_REPO/.claude/.backbone-copied"
mkdir -p "$CMD_DST" "$SCRIPT_DST"
: > "$MANIFEST"

# install_one <src> <dst> — link if asked and possible, otherwise copy and record in the manifest
install_one() {
  local src="$1" dst="$2" how="COPY"
  rm -f "$dst"
  if [[ $LINK -eq 1 && "${BACKBONE_SYMLINKS:-1}" != "0" ]] && ln -s "$src" "$dst" 2>/dev/null; then
    how="LINK"
  else
    cp "$src" "$dst"
    echo "${dst#"$TARGET_REPO/.claude/"}" >> "$MANIFEST"
  fi
  [[ "$src" == *.sh ]] && chmod +x "$src" 2>/dev/null || true
  echo "  $how  $(basename "$src") → $dst"
}

echo ""
echo "Installing backbone into: $TARGET_REPO/.claude"
echo ""

for src in "$CMD_SRC"/backbone-*.md; do
  install_one "$src" "$CMD_DST/$(basename "$src")"
done
for src in "$SCRIPT_SRC"/backbone-*.sh; do
  install_one "$src" "$SCRIPT_DST/$(basename "$src")"
done

copied="$(wc -l < "$MANIFEST" | tr -d ' ')"
[[ "$copied" -eq 0 ]] && rm -f "$MANIFEST"

echo ""
echo "Done. Run /backbone-join to register this session."
echo "Note: ../agent-backbone/ must be accessible as a sibling directory from the target repo."
[[ $LINK -eq 1 && "$copied" -gt 0 ]] && echo "Note: $copied file(s) were copied, not linked — re-run /backbone-update to refresh them."
exit 0
