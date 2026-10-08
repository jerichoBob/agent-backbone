#!/usr/bin/env bash
# Tests the backbone coordination workflow: CR type schema, state machine,
# command presence, and install script.
# Run from the agent-backbone root: bash tests/test-backbone-workflow.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MESSAGES_DIR="$ROOT/messages"
COMMANDS_DIR="$ROOT/.claude/commands"
SCRIPTS_DIR="$ROOT/scripts"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

assert_file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

assert_contains() {
  local file="$1" pattern="$2" label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label (pattern '$pattern' not found in $file)"; fi
}

assert_not_exists() {
  local path="$1" label="$2"
  if [[ ! -f "$path" ]]; then pass "$label"; else fail "$label (should not exist: $path)"; fi
}

echo ""
echo "Backbone Workflow Tests"
echo "======================="

# ── Test 1: CR type schema ────────────────────────────────────────────────────
echo ""
echo "1. CR type schema"
CR_SCHEMA="$MESSAGES_DIR/types/cr.md"
assert_file_exists "$CR_SCHEMA" "messages/types/cr.md exists"
assert_contains "$CR_SCHEMA" "affected_endpoints" "cr schema defines affected_endpoints"
assert_contains "$CR_SCHEMA" "affected_tables"    "cr schema defines affected_tables"
assert_contains "$CR_SCHEMA" "Problem Statement"  "cr schema has Problem Statement section"
assert_contains "$CR_SCHEMA" "Solution Recommendation" "cr schema has Solution Recommendation section"
assert_contains "$CR_SCHEMA" "Implementation Notes" "cr schema has Implementation Notes section"
assert_contains "$CR_SCHEMA" "Follow-up Notes"    "cr schema has Follow-up Notes section"

# ── Test 2: Base frontmatter schema ──────────────────────────────────────────
echo ""
echo "2. Base frontmatter schema"
assert_contains "$MESSAGES_DIR/README.md" "^id:" "README documents id field"
assert_contains "$MESSAGES_DIR/README.md" "^from:" "README documents from field"
assert_contains "$MESSAGES_DIR/README.md" "^to:" "README documents to field"
assert_contains "$MESSAGES_DIR/README.md" "pending" "README documents pending status"
assert_contains "$MESSAGES_DIR/README.md" "claimed" "README documents claimed status"
assert_contains "$MESSAGES_DIR/README.md" "complete" "README documents complete status"

# ── Test 3: CR message lifecycle ─────────────────────────────────────────────
echo ""
echo "3. CR message lifecycle (pending → claimed → complete)"
ID="$(date +%Y%m%d-%H%M%S)-cr-test"
CR_PENDING="$TMP_DIR/cr-${ID}-pending.md"

cat > "$CR_PENDING" <<EOF
---
id: "${ID}"
type: cr
status: pending
routing: direct
from: stak-app:test-sender
to: grostak-api:test-receiver
affected_endpoints:
  - POST /api/test
affected_tables:
  - test_table
created: 2026-06-06
updated: 2026-06-06
---

# Problem Statement

Test problem.

# Solution Recommendation

Test solution.

# Implementation Notes

<!-- pending -->

# Follow-up Notes

<!-- pending -->
EOF

assert_file_exists "$CR_PENDING" "CR pending file created"
assert_contains "$CR_PENDING" "^type: cr" "type field is cr"
assert_contains "$CR_PENDING" "^status: pending" "initial status is pending"

# pending → claimed
CR_CLAIMED="$TMP_DIR/cr-${ID}-claimed.md"
cp "$CR_PENDING" "$CR_CLAIMED"
sed -i '' 's/status: pending/status: claimed/' "$CR_CLAIMED"
rm "$CR_PENDING"
assert_file_exists "$CR_CLAIMED" "renamed to claimed"
assert_not_exists "$CR_PENDING" "pending file removed on claim"
assert_contains "$CR_CLAIMED" "status: claimed" "status is claimed"

# claimed → complete (archived)
mkdir -p "$TMP_DIR/archive"
CR_COMPLETE="$TMP_DIR/archive/cr-${ID}-complete.md"
cp "$CR_CLAIMED" "$CR_COMPLETE"
sed -i '' 's/status: claimed/status: complete/' "$CR_COMPLETE"
rm "$CR_CLAIMED"
assert_file_exists "$CR_COMPLETE" "archived on complete"
assert_not_exists "$CR_CLAIMED" "claimed file removed after archive"
assert_contains "$CR_COMPLETE" "status: complete" "final status is complete"

# ── Test 4: Agent addressing ──────────────────────────────────────────────────
echo ""
echo "4. Agent addressing"
ADDR_FILE="$TMP_DIR/cr-addr-test.md"
cat > "$ADDR_FILE" <<'EOF'
---
id: "addr-test"
type: cr
status: pending
routing: direct
from: stak-app:test
to: grostak-api:core
created: 2026-06-06
updated: 2026-06-06
---
EOF
assert_contains "$ADDR_FILE" "^from: stak-app:test" "from uses agent-name format"
assert_contains "$ADDR_FILE" "^to: grostak-api:core" "to uses agent-name format"

BROADCAST_FILE="$TMP_DIR/cr-broadcast-test.md"
cat > "$BROADCAST_FILE" <<'EOF'
---
id: "broadcast-test"
type: cr
status: pending
routing: direct
from: stak-app:test
to: any
created: 2026-06-06
updated: 2026-06-06
---
EOF
assert_contains "$BROADCAST_FILE" "^to: any" "to: any valid for unclaimed broadcast"

# ── Test 5: Filename convention ───────────────────────────────────────────────
echo ""
echo "5. Filename convention"
VALID_NAMES=(
  "cr-20260606-143022-pending.md"
  "cr-20260606-143022-claimed.md"
  "cr-20260606-143022-complete.md"
)
for name in "${VALID_NAMES[@]}"; do
  if echo "$name" | grep -qE '^cr-[0-9]{8}-[0-9]{6}-(pending|claimed|complete)\.md$'; then
    pass "valid filename: $name"
  else
    fail "invalid filename: $name"
  fi
done

# ── Test 6: Command files ─────────────────────────────────────────────────────
echo ""
echo "6. Command files"
assert_file_exists "$COMMANDS_DIR/backbone-join.md"        "/backbone-join exists"
assert_file_exists "$COMMANDS_DIR/backbone-leave.md"       "/backbone-leave exists"
assert_file_exists "$COMMANDS_DIR/backbone-roster.md"      "/backbone-roster exists"
assert_file_exists "$COMMANDS_DIR/backbone-publish.md"     "/backbone-publish exists"
assert_file_exists "$COMMANDS_DIR/backbone-inbox.md"       "/backbone-inbox exists"
assert_file_exists "$COMMANDS_DIR/backbone.md"             "/backbone exists"
assert_file_exists "$COMMANDS_DIR/backbone-send.md"        "/backbone-send exists"
assert_file_exists "$COMMANDS_DIR/backbone-done.md"        "/backbone-done exists"
assert_file_exists "$COMMANDS_DIR/backbone-complete.md"    "/backbone-complete exists"
assert_file_exists "$COMMANDS_DIR/backbone-subscribe.md"   "/backbone-subscribe exists"
assert_file_exists "$COMMANDS_DIR/backbone-unsubscribe.md" "/backbone-unsubscribe exists"
assert_not_exists  "$COMMANDS_DIR/cr-send.md"              "cr-send removed"
assert_not_exists  "$COMMANDS_DIR/cr-inbox.md"             "cr-inbox removed"
assert_not_exists  "$COMMANDS_DIR/cr-ready.md"             "cr-ready removed"
assert_not_exists  "$COMMANDS_DIR/cr-done.md"              "cr-done removed"

# ── Test 7: Install script ────────────────────────────────────────────────────
echo ""
echo "7. Install script"
assert_file_exists "$SCRIPTS_DIR/install-backbone-commands.sh" "install-backbone-commands.sh exists"
assert_not_exists  "$SCRIPTS_DIR/install-cr-commands.sh"       "install-cr-commands.sh removed"
assert_contains    "$SCRIPTS_DIR/install-backbone-commands.sh" "backbone-\*.md" "script globs backbone-*.md"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
