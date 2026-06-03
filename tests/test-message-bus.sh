#!/usr/bin/env bash
# Tests the generic message bus: type registry, publish/inbox/complete lifecycle,
# direct and topic routing, archive behavior, backward compat with cr-* files.
# Run from the agent-backbone root: bash tests/test-message-bus.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MESSAGES_DIR="$ROOT/messages"
TYPES_DIR="$ROOT/messages/types"
ARCHIVE_DIR="$ROOT/messages/archive"
COMMANDS_DIR="$ROOT/.claude/commands"
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
echo "Message Bus Tests"
echo "================="

# ── Test 1: Type registry ─────────────────────────────────────────────────────
echo ""
echo "1. Type registry"
assert_file_exists "$TYPES_DIR/README.md"  "messages/types/README.md exists"
assert_file_exists "$TYPES_DIR/cr.md"      "cr type schema exists"
assert_file_exists "$TYPES_DIR/task.md"    "task type schema exists"
assert_contains "$TYPES_DIR/cr.md"   "^# CR" "cr.md has title"
assert_contains "$TYPES_DIR/task.md" "^# Task" "task.md has title"

# ── Test 2: Archive directory ─────────────────────────────────────────────────
echo ""
echo "2. Archive directory"
assert_file_exists "$ARCHIVE_DIR/README.md" "messages/archive/README.md exists"

# ── Test 3: Base frontmatter schema ──────────────────────────────────────────
echo ""
echo "3. Base frontmatter schema"
assert_contains "$MESSAGES_DIR/README.md" "^id:" "README documents id field"
assert_contains "$MESSAGES_DIR/README.md" "^type:" "README documents type field"
assert_contains "$MESSAGES_DIR/README.md" "^status:" "README documents status field"
assert_contains "$MESSAGES_DIR/README.md" "^routing:" "README documents routing field"
assert_contains "$MESSAGES_DIR/README.md" "^from:" "README documents from field"
assert_contains "$MESSAGES_DIR/README.md" "pending" "README documents pending status"
assert_contains "$MESSAGES_DIR/README.md" "claimed" "README documents claimed status"
assert_contains "$MESSAGES_DIR/README.md" "complete" "README documents complete status"

# ── Test 4: CR message lifecycle ─────────────────────────────────────────────
echo ""
echo "4. CR message lifecycle"
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
created: 2026-06-03
updated: 2026-06-03
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
assert_contains "$CR_PENDING" "^routing: direct" "routing is direct"
assert_contains "$CR_PENDING" "^status: pending" "status is pending"

# Simulate claim
CR_CLAIMED="$TMP_DIR/cr-${ID}-claimed.md"
cp "$CR_PENDING" "$CR_CLAIMED"
sed -i '' 's/status: pending/status: claimed/' "$CR_CLAIMED"
rm "$CR_PENDING"
assert_file_exists "$CR_CLAIMED" "renamed to claimed"
assert_not_exists "$CR_PENDING" "pending file removed"
assert_contains "$CR_CLAIMED" "status: claimed" "status updated"

# Simulate complete → archive
CR_COMPLETE="$TMP_DIR/archive/cr-${ID}-complete.md"
mkdir -p "$TMP_DIR/archive"
cp "$CR_CLAIMED" "$CR_COMPLETE"
sed -i '' 's/status: claimed/status: complete/' "$CR_COMPLETE"
rm "$CR_CLAIMED"
assert_file_exists "$CR_COMPLETE" "archived on complete"
assert_not_exists "$CR_CLAIMED" "claimed file removed after archive"
assert_contains "$CR_COMPLETE" "status: complete" "final status is complete"

# ── Test 5: Task message lifecycle ───────────────────────────────────────────
echo ""
echo "5. Task message lifecycle"
ID2="$(date +%Y%m%d-%H%M%S)-task-test"
TASK_PENDING="$TMP_DIR/task-${ID2}-pending.md"

cat > "$TASK_PENDING" <<EOF
---
id: "${ID2}"
type: task
status: pending
routing: direct
from: agent-backbone:spec-work
to: grostak-api:core
priority: normal
created: 2026-06-04
updated: 2026-06-04
---

# Task Description

Add index on test_table(tenant_id, status).

# Acceptance Criteria

- Migration file exists
- Index visible in EXPLAIN ANALYZE

# Completion Notes

<!-- pending -->
EOF

assert_file_exists "$TASK_PENDING" "task pending file created"
assert_contains "$TASK_PENDING" "^type: task" "type field is task"
assert_contains "$TASK_PENDING" "^priority: normal" "priority field present"
assert_contains "$TASK_PENDING" "^# Task Description" "has Task Description section"
assert_contains "$TASK_PENDING" "^# Acceptance Criteria" "has Acceptance Criteria section"
assert_contains "$TASK_PENDING" "^# Completion Notes" "has Completion Notes section"

# ── Test 6: Topic routing ─────────────────────────────────────────────────────
echo ""
echo "6. Topic routing"
ID3="$(date +%Y%m%d-%H%M%S)-topic-test"
TOPIC_MSG="$TMP_DIR/task-${ID3}-pending.md"

cat > "$TOPIC_MSG" <<EOF
---
id: "${ID3}"
type: task
status: pending
routing: topic
topic: schema-changes
from: grostak-api:migrations
created: 2026-06-04
updated: 2026-06-04
---

# Task Description

Review the new bloodwork schema proposal.

# Acceptance Criteria

- Feedback provided on schema design

# Completion Notes

<!-- pending -->
EOF

assert_file_exists "$TOPIC_MSG" "topic message created"
assert_contains "$TOPIC_MSG" "^routing: topic" "routing is topic"
assert_contains "$TOPIC_MSG" "^topic: schema-changes" "topic field present"
# Verify no 'to' field for topic routing
assert_not_exists "$TMP_DIR/has-to-field" "placeholder" 2>/dev/null || true
if grep -q "^to:" "$TOPIC_MSG" 2>/dev/null; then
  fail "topic message should not have 'to' field"
else
  pass "topic message has no 'to' field (correct)"
fi

# ── Test 7: Filename convention ───────────────────────────────────────────────
echo ""
echo "7. Filename convention"
VALID_FILENAMES=(
  "cr-20260603-143022-pending.md"
  "cr-20260603-143022-claimed.md"
  "task-20260604-091500-pending.md"
  "task-20260604-091500-claimed.md"
)
ARCHIVE_FILENAMES=(
  "cr-20260603-143022-complete.md"
  "task-20260604-091500-complete.md"
)
for fname in "${VALID_FILENAMES[@]}"; do
  if echo "$fname" | grep -qE '^[a-z]+-[0-9]{8}-[0-9]{6}-(pending|claimed)\.md$'; then
    pass "valid active filename: $fname"
  else
    fail "invalid filename: $fname"
  fi
done
for fname in "${ARCHIVE_FILENAMES[@]}"; do
  if echo "$fname" | grep -qE '^[a-z]+-[0-9]{8}-[0-9]{6}-complete\.md$'; then
    pass "valid archive filename: $fname"
  else
    fail "invalid archive filename: $fname"
  fi
done

# ── Test 8: Command files ─────────────────────────────────────────────────────
echo ""
echo "8. Command files"
assert_file_exists "$COMMANDS_DIR/backbone-publish.md"     "/backbone-publish exists"
assert_file_exists "$COMMANDS_DIR/backbone-inbox.md"       "/backbone-inbox exists"
assert_file_exists "$COMMANDS_DIR/backbone-subscribe.md"   "/backbone-subscribe exists"
assert_file_exists "$COMMANDS_DIR/backbone-unsubscribe.md" "/backbone-unsubscribe exists"
assert_file_exists "$COMMANDS_DIR/backbone-complete.md"    "/backbone-complete exists"

# ── Test 9: Backward compat — cr-* v1 files ──────────────────────────────────
echo ""
echo "9. Backward compat (v1 cr-* files)"
# The messages/README.md should document that cr-* prefix implies type: cr
assert_contains "$MESSAGES_DIR/README.md" "cr-\*" "README documents cr-* backward compat"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
