#!/usr/bin/env bash
# Installs CR workflow slash commands into a target repo's .claude/commands/ directory.
# All commands are generic (agent-name-based routing via presence records) — install the
# same set into any repo that participates in the backbone.
#
# Usage: bash scripts/install-cr-commands.sh <target-repo-path>

set -euo pipefail

BACKBONE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$BACKBONE_DIR/.claude/commands"

usage() {
  echo "Usage: bash scripts/install-cr-commands.sh <target-repo-path>"
  exit 1
}

[[ $# -lt 1 ]] && usage

TARGET_REPO="$1"
TARGET_DIR="$TARGET_REPO/.claude/commands"

if [[ ! -d "$TARGET_REPO" ]]; then
  echo "Error: target repo not found: $TARGET_REPO"
  exit 1
fi

mkdir -p "$TARGET_DIR"

install_cmd() {
  local name="$1"
  local src="$SOURCE_DIR/$name"
  local dst="$TARGET_DIR/$name"
  if [[ ! -f "$src" ]]; then
    echo "  SKIP  $name (source not found)"
    return
  fi
  cp "$src" "$dst"
  echo "  OK    $name → $dst"
}

echo ""
echo "Installing CR commands into: $TARGET_DIR"
echo ""

install_cmd "cr-send.md"
install_cmd "cr-inbox.md"
install_cmd "cr-ready.md"
install_cmd "cr-done.md"

echo ""
echo "Done. Run /backbone-join in the target session to register the agent before using these commands."
echo "Note: ../agent-backbone/ must be accessible as a sibling directory from the target repo."
