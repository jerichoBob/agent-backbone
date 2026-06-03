---
version: 1
name: a2a-coordination-backbone
display_name: "A2A Coordination Backbone"
status: draft
created: 2026-06-03
depends_on: []
tags: [cross-repo, agents, coordination, grostak-v2, stak-app]
---

# A2A Coordination Backbone

## Why (Problem Statement)

> As a developer working across two tightly coupled repos, I want Claude agents in each repo to coordinate change requests through a shared message store so that I can stop copy-pasting context between sessions.

### Context

- `grostak-v2` (platform) and `stak-app` (mobile) share an API contract that is still evolving — schema changes and new endpoints require coordinated changes on both sides
- Currently the workflow is: ask Claude in stak-app to draft a change request → manually copy-paste it into a new Claude Code session in grostak-v2 → implement platform changes → manually relay the "ready" signal back to stak-app → implement mobile changes → run tests
- This manual relay loop loses context, is error-prone, and doesn't scale as the pace of cross-repo changes increases
- Both Claude instances can read/write files, and `agent-backbone` is a shared repo accessible from both project directories (`../agent-backbone/` from either side)
- The coordination problem recurs with every API evolution — it needs a durable, structured solution

---

## What (Requirements)

### User Stories

- **US-1**: As a developer in stak-app, I want to run `/cr-send` to have Claude draft and persist a structured change request without me copy-pasting anything
- **US-2**: As a developer in grostak-v2, I want to run `/cr-inbox` to see pending change requests and claim one for implementation
- **US-3**: As a developer in grostak-v2, I want to run `/cr-ready` to signal that platform changes are complete and document what changed (endpoints, schema, migration notes)
- **US-4**: As a developer in stak-app, I want to run `/cr-inbox` to see platform-ready signals and pick up the implementation notes so I can make the corresponding mobile changes
- **US-5**: As a developer, I want the accumulated change request files to serve as a decision log I can reference later

### Acceptance Criteria

- AC-1: A CR file written by `/cr-send` in stak-app is immediately readable by `/cr-inbox` in grostak-v2 with no manual file transfer
- AC-2: Status transitions (draft → platform-in-progress → awaiting-mobile → complete) are reflected in the CR filename and frontmatter
- AC-3: `/cr-ready` captures enough platform implementation detail (changed endpoints, schema diffs, migration notes) that the stak-app agent can act on it without requiring a separate context transfer
- AC-4: `/cr-inbox` on either side shows only CRs relevant to that repo (pending on platform side, platform-ready on mobile side)
- AC-5: All CR files accumulate in `agent-backbone/messages/` as a persistent audit trail

### Out of Scope

- Automated watchers or push notifications between sessions (human switches tabs to trigger the next side)
- Multi-party CRs involving more than two repos
- CI/CD integration or automated test triggering (handled separately by existing test suites)

---

## How (Approach)

> **Two-file model — no checkboxes here.** Tasks below are plain bullets. Checkboxes (`- [ ]` / `- [x]`) belong only in `specs/README.md`, which is the single source of truth for progress tracking. `specs-parse.sh` counts from README only.

### Phase 1: Message Schema & Storage

- Define the CR markdown file schema (YAML frontmatter + prose sections)
- Frontmatter fields: `id`, `status`, `created`, `updated`, `source_repo`, `title`, `affected_endpoints`, `affected_tables`
- Prose sections: Problem Statement, Solution Recommendation, Platform Implementation Notes (filled in by grostak-v2 side), Mobile Implementation Notes (filled in by stak-app side)
- Filename convention: `cr-{id}-{status}.md` where status is one of `draft`, `platform-in-progress`, `awaiting-mobile`, `complete`
- Create `agent-backbone/messages/` directory with a `README.md` explaining the schema and status lifecycle
- Write an example CR file (`cr-000-example.md`) as documentation

### Phase 2: `/cr-send` Slash Command (stak-app)

- Create `.claude/commands/cr-send.md` in the `stak-app` repo
- Command behavior: Claude drafts a CR by reading current context (what change is needed, which endpoints/tables are affected, why), writes the file to `../agent-backbone/messages/cr-{timestamp}-draft.md`, confirms the path to the user
- Include a pre-flight check that `../agent-backbone/messages/` is accessible (relative path from stak-app)
- Output a human-readable summary of what was written so the developer can verify before switching to the platform side

### Phase 3: `/cr-inbox` and `/cr-ready` Slash Commands (grostak-v2)

- Create `.claude/commands/cr-inbox.md` in the `grostak-v2` repo
- `/cr-inbox` behavior: scans `../agent-backbone/messages/` for CRs with status `draft`, displays a summary list, lets developer choose one to claim (renames file to `cr-{id}-platform-in-progress.md`, updates frontmatter status and `updated` date)
- Create `.claude/commands/cr-ready.md` in the `grostak-v2` repo
- `/cr-ready` behavior: finds the in-progress CR owned by this session, prompts Claude to fill in the Platform Implementation Notes section (changed endpoints, schema diff summary, migration notes, any breaking changes), renames file to `cr-{id}-awaiting-mobile.md`

### Phase 4: `/cr-inbox` Slash Command (stak-app)

- Create a second `.claude/commands/cr-inbox.md` in the `stak-app` repo (separate from grostak-v2's version)
- Behavior: scans `../agent-backbone/messages/` for CRs with status `awaiting-mobile`, displays the Platform Implementation Notes section, lets developer claim one (renames to `cr-{id}-mobile-in-progress.md`)
- Include a `/cr-done` companion command that marks the CR complete (`cr-{id}-complete.md`) and writes a brief Mobile Implementation Notes summary

### Phase 5: Tests & Validation

- Add `tests/test-cr-workflow.sh` to `agent-backbone` that exercises the full lifecycle: create a CR file in draft state, verify it parses correctly, simulate status transitions, verify filenames and frontmatter stay consistent
- Manual walkthrough: use a real stak-app ↔ grostak-v2 change as the first live CR to validate the workflow end-to-end

---

## Technical Notes

### Architecture Decisions

- **File-based over API-based**: No server required. Both Claude instances already have filesystem access. The shared repo is the message bus.
- **Status encoded in filename**: Makes `ls messages/` immediately informative without parsing frontmatter. Also makes transitions atomic — rename is a single operation.
- **Slash commands, not automation**: The developer remains in the loop at each transition (stak-app → platform, platform → mobile). This is intentional — the coordination is about human-paced review, not automated handoffs.
- **Markdown + YAML frontmatter**: Readable by both humans and Claude. The prose sections carry the context that a raw diff cannot — the "why" and implementation decisions.
- **Relative path `../agent-backbone/`**: Both repos sit under the same parent directory. This assumption is encoded in the slash commands and should be documented.

### Dependencies

- `agent-backbone` must be a sibling directory to both `grostak-v2` and `stak-app` (i.e., all three under the same parent)
- No new npm packages, services, or infra required

### Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| Relative path assumption breaks if repos are in different locations | Document the assumed layout in CLAUDE.md and the messages/README.md; add a pre-flight check in each slash command |
| CR files accumulate indefinitely | Add a `/cr-archive` command (future) that moves completed CRs to `messages/archive/`; for now, `complete` status CRs are visually filtered by the inbox commands |
| Two developers claim the same CR simultaneously | Acceptable for now (solo dev workflow); file rename is effectively a lock for single-developer use |
| Platform implementation notes are too terse for mobile side to act on | Slash command prompt should explicitly ask Claude to include endpoint signatures, request/response shapes, and any auth changes |

---

## Open Questions

1. Should the CR ID be a timestamp (`20260603-143022`) or a short sequential slug (`cr-001`)? Timestamp is collision-free but less readable in filenames.
2. Should `/cr-send` in stak-app also read the current git diff to auto-populate affected files/endpoints, or is manual description sufficient for the first version?
3. Is there value in a `/cr-status` command that shows the full lifecycle view (all CRs by status) from either repo?

---

## Security

### Authentication

Not applicable — this is an internal developer tooling system. All access is via local filesystem reads/writes by Claude Code running in authenticated developer sessions. No network endpoints are exposed.

### Authorization

Not applicable — single-developer workflow. CR files in `agent-backbone/messages/` are local files with standard OS-level permissions. No multi-user access control needed at this stage.

### Audit Logging

The CR file lifecycle itself serves as an audit trail. Each status transition updates the `updated` field in frontmatter and renames the file, creating an implicit history. All CR files accumulate in `messages/` (and eventually `messages/archive/`) as a permanent record of what changed, why, and when.

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| 2026-06-03 | Initial draft |
