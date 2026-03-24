# Codebase Oracle — Architecture

## Overview

The Oracle is a three-tier product intelligence cache. Each tier trades accuracy for speed:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Query Entry Point                            │
│                    /oracle-ask "..."                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           ┌───────────────▼───────────────┐
           │  L1: Product Map              │  product-map.md
           │  ~1-2K tokens                 │  Domains, flows, roles,
           │  Routing + disambiguation     │  error codes, flags
           └───────────────┬───────────────┘
                           │  Routes question to relevant L2 doc(s)
           ┌───────────────▼───────────────┐
           │  L2: Flow Documents           │  flows/*.md
           │  ~3-8K tokens each            │  globals/*.md
           │  Behavior cache per flow      │  Full step-by-step,
           │  Written by oracle-init and   │  errors, access control
           │  self-improved by oracle-ask  │  side effects
           └───────────────┬───────────────┘
                           │  Only on miss or explicit enrichment
           ┌───────────────▼───────────────┐
           │  L3: Live Code Exploration    │  Explore subagent
           │  ~30-80K tokens               │  Reads actual source
           │  Authoritative but expensive  │  Always writes back to L2
           └───────────────────────────────┘
```

## Query Resolution Paths

### Path A — Full Cache Hit
- L2 doc exists, source files unchanged since generation
- Answer served exclusively from L2 doc
- Cost: ~4K tokens, ~10 seconds
- Prefix: `✅ VERIFIED — from cached analysis`

### Path A-Partial — Partial Coverage
- L2 doc exists, but the user's specific nuance isn't fully documented
- User is presented a choice: fast partial answer or targeted trace
- If they choose trace: runs A-Enrich
- **Cache discipline**: no automatic escalation — user decides when to pay trace cost

### Path A-Enrich — User-Requested Enrichment
- User explicitly chose deeper trace on a partial-coverage question
- Explore subagent runs ONLY for the specific uncovered aspect
- New findings are MERGED into the existing L2 doc (not replaced)
- Staleness JSON updated with new source files
- Logged as `L2_ENRICHED`

### Path B — Stale Cache
- L2 doc exists but source files changed since generation
- Stale doc is still served (structure remains valuable) with a warning
- User can say "refresh" to trigger Path C re-trace

### Path C — Cache Miss
- No L2 doc exists for this question
- Explore subagent runs full live trace
- Always writes back to a new L2 doc — no trace runs without persisting
- Logged as `L3_MISS`

## Cache Discipline (Critical)

The caching system only works if hits are actually served from cache. Violations:

**Never** run Explore on a verified cache hit. A fast partial answer from cache is more
valuable than a slow complete answer from live tracing. Let the user decide when to
pay the trace cost (Path A-Partial).

**Always** write back after any live trace (Path C). The rule: if you read code, you write cache.

**Escalation is user-gated**. The oracle never silently escalates from L2 to L3.

## Anti-Hallucination System

The most dangerous error is stating backend-defined text as user-visible text.

In fullstack apps, the backend may define `"Recipient signing window has expired"` but
the frontend may display `"Something went wrong."` These are different user experiences.

Every "user sees" claim must be tagged:

- **[RENDERED]** — traced to the actual frontend component, toast handler, or error boundary
  that displays it. This is what the user actually sees.
- **[BACKEND-DEFINED]** — found in backend error constants or response formatting, but
  frontend rendering was not verified. The actual displayed text may differ.

This was discovered empirically on Documenso: the backend throws `RECIPIENT_EXPIRED` with
message `"Recipient signing window has expired"` but the signing field component displays
a generic `"An error occurred while signing the field."` — completely different user experience.

## Self-Improving Loop

The oracle grows more useful with every query:
1. Cache miss → Explore trace → L2 doc written
2. Next identical query → L2 hit, no trace needed
3. Partial hit + user enrichment → L2 doc expanded
4. Over time: cache hit rate climbs, cost per query falls

The `/oracle-eval` skill measures this: hit rate, cost savings, stale hotspots.

## Cache Invalidation via Git Hook

The `scripts/install-git-hook.sh` script installs a `post-commit` hook that:
1. Gets the list of files changed in the commit
2. Runs `check-staleness.py` with those file paths
3. Marks any L2 docs whose `sourceFiles` overlap with the changed files as `stale: true`
4. On next query, stale docs are served with a warning (Path B) until refreshed

This is zero-cost: no tokens, no Claude invocation. Pure filesystem + JSON.

## Fork / Write-Back Constraint

**Explore subagent** — reads code, searches files, returns findings. Cannot write files.
Used in Paths A-Enrich, C, and oracle-refresh.

**Main context** — writes all oracle files (L2 docs, staleness JSON, eval log). This is
required because file writes need the main conversation's tool permissions.

The oracle-init skill runs entirely in main context (no subagents) to preserve write access.
oracle-ask and oracle-refresh use Explore subagents for reads, write results in main context.

## File Structure

```
.product-oracle/
├── product-map.md          L1 index (~100-200 lines)
├── .staleness.json         Source file tracking per document
├── .eval-log.jsonl         Query log (one JSON object per line)
├── flows/                  L2 flow documents
│   ├── recipient-signing.md
│   ├── document-creation.md
│   └── ...
└── globals/                L2 global reference documents
    ├── access-control.md
    ├── notifications.md
    └── billing-and-plans.md
```

## Design Evolution

The current design went through 5 iterations driven by specific test failures:

1. **v1**: Simple RAG over code. Failed: too slow, no caching.
2. **v2**: Static docs generated once. Failed: became stale immediately.
3. **v3**: Cache with auto-refresh on every query. Failed: defeated the cache (50K tokens every time).
4. **v4**: Cache with staleness detection. Failed: hallucination — backend error messages reported as UI text.
5. **v5** (current): Cache + anti-hallucination tags + user-gated escalation + self-improving write-back.

For deeper detail on the design rationale, see `docs/why-this-matters.md`.
