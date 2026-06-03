#!/usr/bin/env bash
# Installs CR workflow slash commands into a target repo's .claude/commands/ directory.
# Usage: bash scripts/install-cr-commands.sh <target-repo-path> <role>
#   role: "stak-app" (installs cr-send, cr-inbox-mobile, cr-done)
#         "grostak-v2" (installs cr-inbox-platform, cr-ready)
#         "all" (installs all commands)

set -euo pipefail

BACKBONE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$BACKBONE_DIR/.claude/commands"

usage() {
  echo "Usage: bash scripts/install-cr-commands.sh <target-repo-path> <role>"
  echo "  role: stak-app | grostak-v2 | all"
  exit 1
}

[[ $# -lt 2 ]] && usage

TARGET_REPO="$1"
ROLE="$2"
TARGET_DIR="$TARGET_REPO/.claude/commands"

if [[ ! -d "$TARGET_REPO" ]]; then
  echo "Error: target repo not found: $TARGET_REPO"
  exit 1
fi

mkdir -p "$TARGET_DIR"

install_cmd() {
  local src="$SOURCE_DIR/$1"
  local dst="$TARGET_DIR/$2"
  if [[ ! -f "$src" ]]; then
    echo "  SKIP  $1 (source not found)"
    return
  fi
  cp "$src" "$dst"
  echo "  OK    $1 → $dst"
}

echo ""
echo "Installing CR commands into: $TARGET_DIR"
echo "Role: $ROLE"
echo ""

case "$ROLE" in
  stak-app)
    install_cmd "cr-send.md"         "cr-send.md"
    install_cmd "cr-inbox-mobile.md" "cr-inbox.md"
    install_cmd "cr-done.md"         "cr-done.md"
    ;;
  grostak-v2)
    install_cmd "cr-inbox-platform.md" "cr-inbox.md"
    install_cmd "cr-ready.md"          "cr-ready.md"
    ;;
  all)
    install_cmd "cr-send.md"           "cr-send.md"
    install_cmd "cr-inbox-platform.md" "cr-inbox-platform.md"
    install_cmd "cr-inbox-mobile.md"   "cr-inbox-mobile.md"
    install_cmd "cr-ready.md"          "cr-ready.md"
    install_cmd "cr-done.md"           "cr-done.md"
    ;;
  *)
    echo "Unknown role: $ROLE"
    usage
    ;;
esac

echo ""
echo "Done. Commands installed in $TARGET_DIR"
echo "Note: both repos must have ../agent-backbone/ accessible as a sibling directory."
