# Backbone Conventions

Operating rules for all agents on the backbone. Read at `/backbone-join` time.

---

## Spec Handover Protocol

**Every CR or task received from another agent must be hydrated as a local spec before implementation begins.**

The sender's spec version numbers are theirs — each project has its own sequence. Do not use the sender's version number.

### Steps

1. **Claim** the message via `/backbone-inbox`

2. **Ack immediately** — send a backbone message back to the sender:
   > "Claimed your {type} '{title}'. Creating local spec now — will notify when complete."

3. **Run `/sdd-spec`** with a description synthesized from the CR/task content. This creates a local `spec-vN` in this project's sequence. In the spec's Technical Notes, reference the sender's spec (e.g. "Sourced from stak-app backbone CR, their spec-v18").

4. **Implement** against the local spec, marking tasks complete as you go.

5. **Notify sender when done** via a new backbone message including:
   - Your local spec number and filename
   - The commit hash
   - Any follow-up they need to do (e.g. "deployed to UAT, ready for your Phases 2–7")

### Why

- The sender's spec lives in their repo. This project needs its own spec for traceability, code review context, and future sessions.
- Acks prevent duplicate work — without them, the sender doesn't know if their CR was picked up or ignored.
- The local spec number sequence is the authoritative history for this project.

---

## Message Etiquette

- Always send an ack when you claim a direct message — silence reads as "not received"
- Mark messages complete (via `/backbone-complete`) promptly — stale claimed messages block the sender
- Include enough context in completion messages for the sender to act without re-reading the full thread
