# Guide for Content Creators

## The Right Narrative

The story is not "I built a tool." The story is "I found something surprising in a production
codebase that no spec document mentioned." Lead with the finding. The tool is the method.

**Wrong:** "Introducing Codebase Oracle — a three-tier RAG system for product intelligence"
**Right:** "I asked an AI what happens when a signing link expires mid-session. It traced
two code layers and found the user gets a generic error with no recovery path — completely
different from what the backend error message says."

## Best Screenshots to Capture

### The cache miss → enrichment → cache hit sequence

This is the most compelling story arc. Capture:

1. **The cache miss** — `/oracle-ask "your question"` when no L2 doc exists. Show the
   `🔍 LIVE TRACE — no cached analysis existed` prefix and the trace output. This establishes
   the problem: the answer wasn't in any doc, it had to be found in code.

2. **The enrichment** — If the first answer triggered a partial-coverage enrichment, show
   the choice presented to the user (`[1] Answer from cache only / [2] Run a targeted trace`)
   and the enriched result with `✅ VERIFIED — enriched with targeted trace`.

3. **The second query** — Ask the same question again. Show `✅ VERIFIED — from cached analysis`
   and the fast response. This is the self-improving loop made visible.

### The anti-hallucination finding

The `[RENDERED]` vs `[BACKEND-DEFINED]` tags are the most technically interesting screenshot.
Find a flow where the backend defines a specific error but the frontend shows something generic.
The oracle will document both and explain the gap. This is the finding that resonates with
engineers who've been burned by this before.

### The eval report

After a few queries, run `/oracle-eval`. The metrics table — especially the hit rate climbing
from 0% to 62%+ — is a compelling proof of the self-improving loop. Screenshot the whole
`=== Oracle Eval Report ===` output.

## LinkedIn Post Structure

```
[Hook — the surprising finding, not the tool]
I asked an AI what happens when a signing link expires while the user is filling out
fields. The backend says one thing. The frontend does something completely different.
Here's what I found:

[The finding — specific and concrete]
Backend throws: "Recipient signing window has expired"
Frontend displays: "An error occurred while signing the field."

The user is stuck on a broken screen with no recovery path.
No redirect. No "request a new link" button. Nothing.

[The shift — why this is a problem]
This isn't in any spec. It's not in the docs.
It emerged from how two independent error handlers interact.

[The proof — how it was found]
I ran a tool that traces code paths the way a PM would read them:
"what does the user actually see at each step?"

[The invitation — not a sales pitch]
It's a Claude Code skill. Open source. Works on any codebase.
[link to GitHub]

What's your team's process for catching this kind of spec drift?
```

## X Thread Structure

```
Tweet 1: The finding screenshot (cache miss output with the [RENDERED] vs [BACKEND-DEFINED] gap visible)

Tweet 2: "Before/after" — what the spec probably says vs. what the code actually does

Tweet 3: The architecture tweet — the ASCII diagram from docs/architecture.md,
         with caption "Three tiers: L1 routes, L2 caches, L3 traces from code"

Tweet 4: The eval screenshot — cache hit rate climbing, time saved estimate

Tweet 5: GitHub link + "Works on any codebase. Try it on yours."
```

## The Best Proof Metric

The cache hit rate climbing over time is the most compelling metric because it's a
direct measure of the system learning. Start at 0%, hit 62% after a session of real queries.
That's not an artificial benchmark — that's the self-improving loop working.

"First query: 60 seconds, full code trace. Same question two hours later: 10 seconds,
served from cache. Third week: 87% of questions answered without touching the code."

That's the story. Lead with that number.
