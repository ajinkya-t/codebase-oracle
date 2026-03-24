---
name: oracle-refresh
description: >
  Regenerate stale product intelligence docs. Can target a specific flow
  or refresh the entire L1 product map. Use after significant code changes
  or when staleness warnings appear frequently.
disable-model-invocation: true
---

# Oracle Refresh — Regenerate Stale Product Intelligence

You regenerate outdated product-oracle documents. You always compare old vs new content
and report behavior changes so the user knows what shifted.

All output must use PM-readable language. Same vocabulary rules as oracle-init and oracle-ask:
- "API endpoint" → "service action"
- "middleware" → "access check"
- "mutation" → "change operation"
- "handler" → "step"
- "component" → "screen section"

---

## Step 1 — Check Prerequisites

1. Check if `.product-oracle/` directory exists.
   - If NOT, print:
     > No product oracle found. Run `/oracle-init` first.
   - Then STOP.

2. Read `.product-oracle/.staleness.json`.
3. Read `.product-oracle/product-map.md`.

---

## Step 2 — Parse the Argument

The user invokes this skill as `/oracle-refresh <argument>`. Parse the argument:

### Mode A: Specific Flow Name

If the argument matches a flow name from the Flow Registry or an L2 doc slug
(e.g., "document-signing", "user-onboarding"):

1. Find the matching L2 doc path in `.staleness.json` or the L2 Document Inventory
2. If no match found, print:
   > No L2 doc found for "{argument}". Available flows: {list flow names from registry}.
   > Did you mean one of these? Or run `/oracle-ask "{argument}"` to create a new trace.
3. If match found, proceed to Step 3 with that single document.

### Mode B: "map"

If the argument is `map`:
- Skip to Step 5 (L1 map regeneration only, no L2 docs).

### Mode C: "all-stale"

If the argument is `all-stale`:

1. For each document in `.staleness.json`, check staleness:
   - Run `git log --oneline --since="{generated date}" -- {source files}` for each doc
   - If any source files have changed, mark the doc as stale

2. Collect all stale documents into a list.

3. If no documents are stale, print:
   > All documents are up to date. No refresh needed.
   - Then STOP.

4. Print the stale document list:
   ```
   Found {N} stale documents:
     - {doc path} ({N} commits behind)
     - {doc path} ({N} commits behind)
     ...
   Refreshing all. This may take a few minutes.
   ```

5. Process each stale document through Step 3 sequentially.

### No Argument

If no argument is provided, print:
> Usage: `/oracle-refresh <flow-name>` | `/oracle-refresh map` | `/oracle-refresh all-stale`
>
> Available flows:
> {list flow names from Flow Registry}
>
> Stale documents: {count stale docs or "none"}

Then STOP.

---

## Step 3 — Re-Trace a Flow

For each flow being refreshed:

### 3A. Save the Old Version

Read the existing L2 doc and store its full content internally. This is needed for
contradiction detection in Step 4.

### 3B. Explore the Code

Launch an Agent with `subagent_type=Explore` with this prompt:

```
Trace the code path for the flow: "{flow name}"

Context from the existing documentation (which may be outdated):
- Trigger: {trigger from old doc}
- Actors: {actors from old doc}
- Entry point files: {source files from .staleness.json}

Start from the user-facing entry point. Follow through business logic, validation,
error handling, and output formatting. Pay special attention to:
- Any changes from the previously documented behavior
- New error paths or removed error paths
- Changed user-facing text (button labels, messages, status values)
- New or removed side effects (emails, webhooks, notifications)
- Changed access control rules

Report:
- What triggers this flow (exact entry point)
- Step-by-step behavior (what happens in order)
- What the user sees/receives at each step (exact UI text, response bodies, CLI output)
- All error paths (what can go wrong and what the user experiences)
- Edge cases
- Access control (who can and cannot do this)
- Side effects (emails sent, webhooks fired, logs created)
- Test coverage (are there tests for this flow?)

IMPORTANT: At the end, list every file you read under a "## Files traced" heading
as a markdown list with file:line references. List the entry-point file first.
```

### 3C. Write the New L2 Doc

Overwrite the existing L2 doc at its current path with the fresh content.
Use the same L2 doc format as oracle-ask (metadata comment block + full flow template):

```markdown
<!-- oracle-metadata
generated: {ISO 8601 timestamp}
commit: {current HEAD short hash}
source_files: {comma-separated list of traced files}
confidence: {HIGH/MEDIUM/LOW}
triggered_by: "oracle-refresh"
refreshed_from: "{previous commit hash from old metadata}"
-->

# {Flow Name}

{... full L2 doc structure: trigger, actors, preconditions,
happy path, branching paths, error states, side effects,
access control, related flows, source references ...}
```

### 3D. Update Staleness Tracking

Update the entry in `.product-oracle/.staleness.json` for this document:
- Set `generated` to the current timestamp
- Update `sourceFiles` to the files discovered during tracing

---

## Step 4 — Contradiction Detection

After regenerating each L2 doc, compare old vs new content and detect behavior changes.

### What to Compare

For each of these categories, diff the old doc against the new doc:

| Category | What Changed | Severity |
|----------|-------------|----------|
| **Happy path steps** | Steps added, removed, or reordered | HIGH |
| **User-facing text** | Button labels, messages, status values changed | HIGH |
| **Error states** | Error codes/messages added or removed | HIGH |
| **Access control** | Role permissions changed | HIGH |
| **Side effects** | Emails/webhooks/notifications added or removed | MEDIUM |
| **Branching paths** | New branches or removed branches | MEDIUM |
| **Preconditions** | Entry requirements changed | MEDIUM |
| **Edge cases** | New edge cases discovered | LOW |
| **Source files** | Implementation files moved or renamed | LOW |

### Output Format

For each flow refreshed, print a change report:

```
── {Flow Name} ────────────────────────────────
   Status: REFRESHED ({old commit} → {new commit})
   Confidence: {level}

   Behavior Changes:
   🔴 HIGH: {description of what changed — in PM language}
   🔴 HIGH: {another high-severity change}
   🟡 MEDIUM: {description}
   🟢 LOW: {description}

   No changes: {list categories with no differences}
```

If NO behavior changes are detected:
```
── {Flow Name} ────────────────────────────────
   Status: REFRESHED ({old commit} → {new commit})
   No behavior changes detected. Documentation updated with current source references.
```

---

## Step 5 — L1 Map Regeneration (Mode B or after L2 refreshes)

If the argument was `map`, or after completing all L2 refreshes:

### 5A. Scan for Changes

Re-run the same scanning strategy as oracle-init Phase 1-2 (archetype detection +
behavior scanning), but compare against the existing product-map.md:

1. Read the current `.product-oracle/product-map.md`
2. Use Explore agents to scan for:
   - New routes/endpoints/commands not in the current map
   - Removed routes/endpoints/commands that are in the current map
   - New roles or changed role definitions
   - New error codes
   - New or removed feature flags
   - New notification triggers

### 5B. Update the Map

Overwrite `.product-oracle/product-map.md` with the updated content.
Keep the same format and stay under 200 lines.

Update the L2 Document Inventory to reflect:
- Any new L2 docs that were generated
- Status changes (Planned → Generated, or mark removed flows)

### 5C. Report Map Changes

```
── Product Map ────────────────────────────────
   Status: REFRESHED

   Changes:
   + Added domain: {name}
   + Added flow: {name}
   - Removed flow: {name}
   ~ Updated role: {name} — {what changed}
   + New feature flag: {name}
   + New error code: {code}
   ~ Updated notification: {trigger} — {what changed}

   No changes: {list sections with no differences}
```

---

## Step 6 — Summary

After all operations complete, print:

```
=== Oracle Refresh Complete ===

Documents refreshed: {N}
  {list each doc path and its change summary in one line}

Behavior changes found: {N total}
  🔴 HIGH: {count}
  🟡 MEDIUM: {count}
  🟢 LOW: {count}

{If Mode C: "Remaining stale documents: {count or 'none'}"}

L1 map: {updated | unchanged}
Staleness tracking: updated

Run /oracle-eval to see updated performance metrics.
```

---

## Step 7 — Log Refreshes

For each document refreshed, append an entry to `.product-oracle/.eval-log.jsonl`:

```json
{
  "timestamp": "{ISO 8601}",
  "question": "oracle-refresh: {flow name or 'map' or 'all-stale'}",
  "resolution": "REFRESH",
  "l2_doc_used": "{path to refreshed doc}",
  "globals_loaded": [],
  "confidence": "{HIGH/MEDIUM/LOW}",
  "has_test_coverage": true | false,
  "response_length_chars": 0,
  "write_back": true,
  "stale_warning": false,
  "behavior_changes": {
    "high": {count},
    "medium": {count},
    "low": {count}
  }
}
```

---

## Constraints

- Runs in main context (no context fork) — must write updated docs directly.
- Delegate all code exploration to `Agent(subagent_type=Explore)`.
- Never fabricate behavior. If the code path is unclear, rate confidence LOW.
- Always preserve the old doc content internally before overwriting — needed for diffing.
- When processing `all-stale`, handle documents sequentially to avoid context overload.
- Include exact text from the codebase in all regenerated docs.
