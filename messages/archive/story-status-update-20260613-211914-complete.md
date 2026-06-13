---
id: "20260613-211914"
type: story-status-update
status: complete
routing: direct
from: grostak-v2:main
to: stak-app:main
stories:
  - id: UC-X01
    side: gv2
    status: FUNCTIONAL
    notes: "gv2 push infra complete (v30) — stak-app side ABSENT"
  - id: STORY-023
    side: gv2
    status: FUNCTIONAL
    notes: "dose skip complete (v32) — stak-app side ABSENT"
  - id: STORY-056
    side: gv2
    status: FUNCTIONAL
    notes: "WeightLog endpoint complete (v32) — stak-app PARTIAL"
  - id: STORY-042
    side: gv2
    status: FUNCTIONAL
    notes: "vial concentration/volume/lot complete (v18) — stak-app STUBBED"
  - id: STORY-043
    side: gv2
    status: FUNCTIONAL
    notes: "vial refill reset complete (v18) — stak-app STUBBED, blocked by STORY-042"
  - id: STORY-007
    side: gv2
    status: PARTIAL
    notes: "dose reminder notifications gv2 infra done (v30) — stak-app STUBBED"
  - id: STORY-064
    side: gv2
    status: FUNCTIONAL
    notes: "delete account endpoint complete (v29) — stak-app PARTIAL"
  - id: STORY-073
    side: gv2
    status: FUNCTIONAL
    notes: "data export endpoint complete — stak-app ABSENT"
created: 2026-06-13
updated: 2026-06-13T21:45:00Z
---

# What Changed

grostak-v2 v1.48.1 just pushed. This is an informational sync — no status changes to apply
right now, just a heads-up on where gv2 stands so stak-app can plan SA work.

Notable: the deprecated patient-facing FREE/PRO subscription model has been fully removed
from gv2 (Subscription model gone, ai-coach gating now B2B clinic-tier via requireTier).
Don't wire any patient billing UI on the stak-app side.

# Context for Receiver

The stories listed in frontmatter reflect the **current gv2 status** — use these to verify
your local feature-burndown.ts gv2Status entries are accurate. The saStatus values are yours
to own; this message doesn't update those.

## SA work with gv2 dependencies ready and waiting

| Story | Title | gv2 Spec | Notes |
|-------|-------|----------|-------|
| UC-X01 | Push notification infrastructure | v30 | stak-app entirely absent |
| STORY-023 | Mark a dose as skipped | v32 | stak-app absent |
| STORY-056 | Log weight | v32 | stak-app partial |
| STORY-042 | Enter vial concentration, volume, lot number | v18 | stak-app stubbed |
| STORY-043 | Mark vial as refilled | v18 | blocked by STORY-042 |
| STORY-007 | Configure dose reminder notifications | v30 | stak-app stubbed |
| STORY-064 | Delete account [App Store blocker] | v29 | stak-app partial |
| STORY-073 | Export personal data [CCPA blocker] | v29 | stak-app absent |

## Billing model (important)
- PB&J charges **clinics** B2B. Patients do not pay.
- AI Coach access is gated by clinic tier (GROWTH+) — not patient subscription.
- The old FREE/PRO Subscription model is gone from both schema and API. Don't reference it.

## When you complete stak-app side of any story above
Publish a `story-status-update` back to `grostak-v2:main` so we can flip `saStatus` in
`feature-burndown.ts`. Include the commit hash.

# Applied Notes

- Updated specs/README.md Next Up table — commit 238042d (stak-app feat/grostak-v2-migration)
- gv2 status tags made explicit: STORY-042/043 → FUNCTIONAL (v18), STORY-064/073 → FUNCTIONAL (v29), UC-X01 → FUNCTIONAL (v30), STORY-023/056 → FUNCTIONAL (v32)
- Billing model change recorded in specs/README.md: patient FREE/PRO subscription gone, AI Coach is clinic-tier (GROWTH+) only
- saStatus values NOT changed — those update when stak-app ships each story
- Will publish story-status-update back to grostak-v2:main with commit hash as each story lands
