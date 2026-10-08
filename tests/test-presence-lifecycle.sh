#!/usr/bin/env bash
# Checks this repo's presence/ docs and example record. The presence tooling (lifecycle, TTL, safe names,
# lookups, migration) is tested in aidev-toolkit: tests/test-backbone-presence.sh.
# Run from the agent-backbone root: bash tests/test-presence-lifecycle.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRESENCE_DIR="$ROOT/presence"
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

assert_not_contains() {
  local file="$1" pattern="$2" label="$3"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label (pattern '$pattern' unexpectedly found in $file)"; fi
}

echo ""
echo "Presence Lifecycle Tests"
echo "========================"

# ── Test 1: presence/ directory and docs exist ───────────────────────────────
echo ""
echo "1. Storage"
assert_file_exists "$PRESENCE_DIR/README.md" "presence/README.md exists"
assert_file_exists "$PRESENCE_DIR/presence-example.md" "presence-example.md exists"

# ── Test 2: Example presence file has required frontmatter ───────────────────
echo ""
echo "2. Schema validation (presence-example.md)"
EXAMPLE="$PRESENCE_DIR/presence-example.md"
assert_contains "$EXAMPLE" "^agent_name:" "has agent_name field"
assert_contains "$EXAMPLE" "^repo:" "has repo field"
assert_contains "$EXAMPLE" "^status:" "has status field"
assert_contains "$EXAMPLE" "^joined:" "has joined field"
assert_contains "$EXAMPLE" "^updated:" "has updated field"
assert_contains "$EXAMPLE" "^ttl_hours:" "has ttl_hours field"
assert_contains "$EXAMPLE" "^capabilities:" "has capabilities field"

# ── Test 3: Example presence file has required prose sections ────────────────
echo ""
echo "3. Prose sections (presence-example.md)"
assert_contains "$EXAMPLE" "^# Current Task" "has Current Task section"
assert_contains "$EXAMPLE" "^# Architectural Knowledge" "has Architectural Knowledge section"
assert_contains "$EXAMPLE" "^# Learned" "has Learned section"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
