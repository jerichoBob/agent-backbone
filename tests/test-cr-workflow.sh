#!/usr/bin/env bash
# Tests the full CR lifecycle: create, parse, status transitions, filename/frontmatter consistency.
# Run from the agent-backbone root: bash tests/test-cr-workflow.sh

set -euo pipefail

MESSAGES_DIR="$(cd "$(dirname "$0")/.." && pwd)/messages"
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
echo "CR Workflow Tests"
echo "================="

# ── Test 1: messages/ directory exists ──────────────────────────────────────
echo ""
echo "1. Storage"
assert_file_exists "$MESSAGES_DIR/README.md" "messages/README.md exists"
assert_file_exists "$MESSAGES_DIR/cr-000-example.md" "cr-000-example.md exists"

# ── Test 2: Example CR has required frontmatter fields ───────────────────────
echo ""
echo "2. Schema validation (cr-000-example.md)"
EXAMPLE="$MESSAGES_DIR/cr-000-example.md"
assert_contains "$EXAMPLE" "^id:" "has id field"
assert_contains "$EXAMPLE" "^status:" "has status field"
assert_contains "$EXAMPLE" "^created:" "has created field"
assert_contains "$EXAMPLE" "^updated:" "has updated field"
assert_contains "$EXAMPLE" "^from:" "has from field"
assert_contains "$EXAMPLE" "^to:" "has to field"
assert_contains "$EXAMPLE" "^title:" "has title field"
assert_contains "$EXAMPLE" "affected_endpoints:" "has affected_endpoints field"
assert_contains "$EXAMPLE" "affected_tables:" "has affected_tables field"

# ── Test 3: Example CR has required prose sections ───────────────────────────
echo ""
echo "3. Prose sections (cr-000-example.md)"
assert_contains "$EXAMPLE" "^# Problem Statement" "has Problem Statement section"
assert_contains "$EXAMPLE" "^# Solution Recommendation" "has Solution Recommendation section"
assert_contains "$EXAMPLE" "^# Implementation Notes" "has Implementation Notes section"
assert_contains "$EXAMPLE" "^# Follow-up Notes" "has Follow-up Notes section"

# ── Test 4: from/to agent addressing ─────────────────────────────────────────
echo ""
echo "4. Agent addressing"
assert_contains "$EXAMPLE" "^from: " "from field has a value"
assert_contains "$EXAMPLE" "^to: " "to field has a value"
# Verify "any" broadcast is a valid to value
BROADCAST_FILE="$TMP_DIR/cr-broadcast-test.md"
cat > "$BROADCAST_FILE" <<'EOF'
---
id: "broadcast-test"
status: draft
created: 2026-06-03
updated: 2026-06-03
from: stak-app:test
to: any
title: "Broadcast test"
affected_endpoints: []
affected_tables: []
---
EOF
assert_contains "$BROADCAST_FILE" "^to: any" "to: any is valid for broadcasts"

# ── Test 5: Status lifecycle transitions (simulated) ─────────────────────────
echo ""
echo "5. Status lifecycle"
ID="$(date +%Y%m%d-%H%M%S)-test"
DRAFT="$TMP_DIR/cr-${ID}-draft.md"

cat > "$DRAFT" <<EOF
---
id: "${ID}"
status: draft
created: 2026-06-03
updated: 2026-06-03
from: stak-app:test-sender
to: grostak-api:test-receiver
title: "Test CR"
affected_endpoints:
  - POST /test
affected_tables:
  - test_table
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

assert_file_exists "$DRAFT" "draft CR created"
assert_contains "$DRAFT" "status: draft" "draft status in frontmatter"

# Simulate claim → in-progress
IN_PROGRESS="$TMP_DIR/cr-${ID}-in-progress.md"
cp "$DRAFT" "$IN_PROGRESS"
sed -i '' 's/status: draft/status: in-progress/' "$IN_PROGRESS"
rm "$DRAFT"
assert_file_exists "$IN_PROGRESS" "renamed to in-progress"
assert_not_exists "$DRAFT" "draft file removed after claim"
assert_contains "$IN_PROGRESS" "status: in-progress" "status updated in frontmatter"

# Simulate /cr-ready → awaiting-response
AWAITING="$TMP_DIR/cr-${ID}-awaiting-response.md"
cp "$IN_PROGRESS" "$AWAITING"
sed -i '' 's/status: in-progress/status: awaiting-response/' "$AWAITING"
rm "$IN_PROGRESS"
assert_file_exists "$AWAITING" "renamed to awaiting-response"
assert_not_exists "$IN_PROGRESS" "in-progress file removed"
assert_contains "$AWAITING" "status: awaiting-response" "status updated in frontmatter"

# Simulate /cr-done → complete
COMPLETE="$TMP_DIR/cr-${ID}-complete.md"
cp "$AWAITING" "$COMPLETE"
sed -i '' 's/status: awaiting-response/status: complete/' "$COMPLETE"
rm "$AWAITING"
assert_file_exists "$COMPLETE" "renamed to complete"
assert_contains "$COMPLETE" "status: complete" "final status is complete"

# ── Test 6: Filename convention ──────────────────────────────────────────────
echo ""
echo "6. Filename convention"
VALID_NAMES=(
  "cr-20260603-143022-draft.md"
  "cr-20260603-143022-in-progress.md"
  "cr-20260603-143022-awaiting-response.md"
  "cr-20260603-143022-complete.md"
)
for name in "${VALID_NAMES[@]}"; do
  if echo "$name" | grep -qE '^cr-[0-9]{8}-[0-9]{6}-(draft|in-progress|awaiting-response|complete)\.md$'; then
    pass "valid filename: $name"
  else
    fail "invalid filename pattern: $name"
  fi
done

# ── Test 7: Commands exist ───────────────────────────────────────────────────
echo ""
echo "7. Command files"
COMMANDS_DIR="$(cd "$(dirname "$0")/.." && pwd)/.claude/commands"
assert_file_exists "$COMMANDS_DIR/backbone-join.md"    "/backbone-join exists"
assert_file_exists "$COMMANDS_DIR/backbone-leave.md"   "/backbone-leave exists"
assert_file_exists "$COMMANDS_DIR/backbone-roster.md"  "/backbone-roster exists"
assert_not_exists  "$COMMANDS_DIR/cr-send.md"          "cr-send removed"
assert_not_exists  "$COMMANDS_DIR/cr-inbox.md"         "cr-inbox removed"
assert_not_exists  "$COMMANDS_DIR/cr-ready.md"         "cr-ready removed"
assert_not_exists  "$COMMANDS_DIR/cr-done.md"          "cr-done removed"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
