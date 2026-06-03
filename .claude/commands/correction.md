---
name: correction
description: Capture hard-won lessons from the current session into .claude/learnings.md
argument-hint: <brief description of what went wrong>
allowed-tools: Read, Write, Edit, AskUserQuestion
model: inherit
---

# Correction — Capture a Lesson Learned

You just went through something expensive: time, tokens, money, or frustration. This command extracts the lessons from the current conversation so they aren't lost.

## Arguments

- **$ARGUMENTS**: Optional hint describing what went wrong (e.g. "CDK loop", "wrong test approach"). If empty, infer from context.

## Instructions

### Step 1: Extract Candidate Learnings

Review the current conversation history. Look for:

- Mistakes Claude made that the user had to correct
- Approaches that failed before finding one that worked
- Assumptions that turned out to be wrong
- Patterns the user explicitly flagged ("don't do that", "that's wrong", "remember this")
- Expensive detours — loops, retries, wasted work
- Things that worked well that weren't obvious (confirmed non-obvious approaches)

If `$ARGUMENTS` is non-empty, use it as a hint to focus the extraction.

Draft a list of candidate learnings. Each learning should have:

- A **title** (short, imperative, specific)
- A **Rule** (the concrete behavior going forward — what to do or not do)
- A **Why** (the cost that was paid — what went wrong, why it matters)
- A **How to apply** (when this rule kicks in, edge cases)

Aim for 1–5 learnings. Don't manufacture learnings that aren't supported by the conversation. Quality over quantity.

### Step 2: Confirm With User

Present the candidate learnings to the user using AskUserQuestion with this structure:

```
I found N lesson(s) from this session. Does this capture what you wanted to preserve?

[List each learning with its title and Rule line]
```

Options:

- "Yes, save these" (recommended if list looks right)
- "Some need changes — I'll tell you"
- "These aren't what I meant — start over"

If user selects "Some need changes": ask them to describe the changes in a follow-up message, incorporate them, and re-confirm.

If user selects "start over": ask the user what specifically they wanted to capture, then re-draft.

### Step 3: Read Existing Learnings

Read `.claude/learnings.md` to check for duplicates or learnings that should be merged/updated rather than appended.

### Step 4: Write to learnings.md

For each confirmed learning:

- Check if a closely related entry already exists in `.claude/learnings.md`
  - If yes: update or extend the existing entry rather than duplicating
  - If no: append as a new `##` section

Format for each entry:

```markdown
## {Title}

**Rule:** {The concrete rule — specific enough to apply without context}

**Why:** {The cost paid — what went wrong, what it took to learn this}

**How to apply:** {When this rule kicks in; how to recognize the situation}

---
```

Append new entries after the last `---` in the file.

### Step 5: Report

Tell the user:

- How many learnings were saved
- Whether any were merged with existing entries
- "Run `/commit` to lock these in." (learnings only matter if they travel with the repo)

## Important Notes

- Never water down a lesson to be polite. If something cost $400 and a week of time, say so in the Why.
- The Rule must be specific enough that a future Claude with no memory of this conversation can follow it correctly.
- Learnings should be durable — avoid referencing ephemeral details like specific PR numbers or dates unless they're meaningful context.
- If the user says the list is wrong, don't argue. Adjust and re-confirm.
