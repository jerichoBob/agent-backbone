#!/usr/bin/env bash
# Installs backbone slash commands into a target repo's .claude/commands/ directory.
# Globs backbone-*.md — no explicit list to maintain.
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

echo ""
echo "Installing backbone commands into: $TARGET_DIR"
echo ""

for src in "$SOURCE_DIR"/backbone-*.md; do
  name="$(basename "$src")"
  cp "$src" "$TARGET_DIR/$name"
  echo "  OK    $name → $TARGET_DIR/$name"
done

echo ""
echo "Done. Run /backbone-join to register this session."
echo "Note: ../agent-backbone/ must be accessible as a sibling directory from the target repo."
