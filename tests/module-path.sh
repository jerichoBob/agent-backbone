# Sourced by tests that need the backbone tooling. The tooling lives in aidev-toolkit's backbone module
# (v6 Phase 5); this repo holds no copy. Resolution order: $BACKBONE_MODULE, the installed module,
# then a sibling aidev-toolkit checkout. With none found the test is BLOCKED (exit 2), not faked.
for _c in "${BACKBONE_MODULE:-}" "$HOME/.claude/aidev-toolkit/modules/backbone" "$ROOT/../aidev-toolkit/modules/backbone"; do
  [[ -n "$_c" && -f "$_c/scripts/backbone-sync.sh" ]] && { BB_MODULE="$(cd "$_c" && pwd)"; break; }
done
if [[ -z "${BB_MODULE:-}" ]]; then
  echo "BLOCKED: backbone module not found (set BACKBONE_MODULE, run /aid-update, or check out ../aidev-toolkit)"; exit 2
fi
