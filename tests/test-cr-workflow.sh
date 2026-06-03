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
assert_contains "$EXAMPLE" "^source_repo:" "has source_repo field"
assert_contains "$EXAMPLE" "^title:" "has title field"
assert_contains "$EXAMPLE" "affected_endpoints:" "has affected_endpoints field"
assert_contains "$EXAMPLE" "affected_tables:" "has affected_tables field"

# ── Test 3: Example CR has required prose sections ───────────────────────────
echo ""
echo "3. Prose sections (cr-000-example.md)"
assert_contains "$EXAMPLE" "^# Problem Statement" "has Problem Statement section"
assert_contains "$EXAMPLE" "^# Solution Recommendation" "has Solution Recommendation section"
assert_contains "$EXAMPLE" "^# Platform Implementation Notes" "has Platform Implementation Notes section"
assert_contains "$EXAMPLE" "^# Mobile Implementation Notes" "has Mobile Implementation Notes section"

# ── Test 4: Status lifecycle transitions (simulated) ─────────────────────────
echo ""
echo "4. Status lifecycle"
ID="$(date +%Y%m%d-%H%M%S)-test"
DRAFT="$TMP_DIR/cr-${ID}-draft.md"

cat > "$DRAFT" <<EOF
---
id: "${ID}"
status: draft
created: 2026-06-03
updated: 2026-06-03
source_repo: stak-app
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

# Platform Implementation Notes

<!-- pending -->

# Mobile Implementation Notes

<!-- pending -->
EOF

assert_file_exists "$DRAFT" "draft CR created"
assert_contains "$DRAFT" "status: draft" "draft status in frontmatter"

# Simulate platform claim
PLATFORM_IP="$TMP_DIR/cr-${ID}-platform-in-progress.md"
cp "$DRAFT" "$PLATFORM_IP"
sed -i '' 's/status: draft/status: platform-in-progress/' "$PLATFORM_IP"
rm "$DRAFT"
assert_file_exists "$PLATFORM_IP" "renamed to platform-in-progress"
assert_not_exists "$DRAFT" "draft file removed after claim"
assert_contains "$PLATFORM_IP" "status: platform-in-progress" "status updated in frontmatter"

# Simulate platform ready
AWAITING="$TMP_DIR/cr-${ID}-awaiting-mobile.md"
cp "$PLATFORM_IP" "$AWAITING"
sed -i '' 's/status: platform-in-progress/status: awaiting-mobile/' "$AWAITING"
rm "$PLATFORM_IP"
assert_file_exists "$AWAITING" "renamed to awaiting-mobile"
assert_not_exists "$PLATFORM_IP" "platform-in-progress file removed"
assert_contains "$AWAITING" "status: awaiting-mobile" "status updated in frontmatter"

# Simulate mobile claim
MOBILE_IP="$TMP_DIR/cr-${ID}-mobile-in-progress.md"
cp "$AWAITING" "$MOBILE_IP"
sed -i '' 's/status: awaiting-mobile/status: mobile-in-progress/' "$MOBILE_IP"
rm "$AWAITING"
assert_file_exists "$MOBILE_IP" "renamed to mobile-in-progress"
assert_not_exists "$AWAITING" "awaiting-mobile file removed"

# Simulate complete
COMPLETE="$TMP_DIR/cr-${ID}-complete.md"
cp "$MOBILE_IP" "$COMPLETE"
sed -i '' 's/status: mobile-in-progress/status: complete/' "$COMPLETE"
rm "$MOBILE_IP"
assert_file_exists "$COMPLETE" "renamed to complete"
assert_contains "$COMPLETE" "status: complete" "final status is complete"

# ── Test 5: Filename convention ──────────────────────────────────────────────
echo ""
echo "5. Filename convention"
VALID_NAMES=(
  "cr-20260603-143022-draft.md"
  "cr-20260603-143022-platform-in-progress.md"
  "cr-20260603-143022-awaiting-mobile.md"
  "cr-20260603-143022-mobile-in-progress.md"
  "cr-20260603-143022-complete.md"
)
for name in "${VALID_NAMES[@]}"; do
  if echo "$name" | grep -qE '^cr-[0-9]{8}-[0-9]{6}-(draft|platform-in-progress|awaiting-mobile|mobile-in-progress|complete)\.md$'; then
    pass "valid filename: $name"
  else
    fail "invalid filename pattern: $name"
  fi
done

# ── Test 6: Commands exist ───────────────────────────────────────────────────
echo ""
echo "6. Command files"
COMMANDS_DIR="$(cd "$(dirname "$0")/.." && pwd)/.claude/commands"
assert_file_exists "$COMMANDS_DIR/cr-send.md"           "/cr-send command exists"
assert_file_exists "$COMMANDS_DIR/cr-inbox-platform.md" "/cr-inbox-platform command exists"
assert_file_exists "$COMMANDS_DIR/cr-ready.md"          "/cr-ready command exists"
assert_file_exists "$COMMANDS_DIR/cr-inbox-mobile.md"   "/cr-inbox-mobile command exists"
assert_file_exists "$COMMANDS_DIR/cr-done.md"           "/cr-done command exists"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
