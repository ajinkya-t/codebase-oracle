# Codebase Oracle

**Product-aware RAG over code. Ask your codebase what it actually does.**

---

## What I Found Running This on Documenso

Before describing the tool, here's what it surfaced in a single session on a real production codebase.

**Finding 1 — The expiry bug.** When a signing link expires while a signer is mid-session,
they see a generic toast: *"An error occurred while signing the document."* The backend throws
a specific error — *"Recipient signing window has expired"* — but the frontend's error handler
doesn't surface it. The signer is not redirected to the expired-link page. They're stuck on a
broken screen with no recovery path and no explanation. This isn't in any spec.

**Finding 2 — The concurrent signing gap.** Two recipients can open the same signing step
simultaneously, both see it as "pending," and both complete it. The system has no optimistic
lock at the field submission level. This is a TOCTOU edge case that emerged from two
independently-designed systems interacting — invisible in any single spec document.

**Finding 3 — The completion redirect.** When the final signer submits, they're redirected to
a completion page with a checkmark. There's no mechanism for a signer to know whether all other
signers have completed. The flow is seamless but opaque — the signer who happens to sign last
triggers document completion, but nothing tells them that.

These findings came from asking the oracle three questions. The oracle didn't find them by being
smart — it found them by tracing both the backend definition and the frontend rendering layer for
every "user sees" claim, which forces the kind of cross-layer comparison that humans skip.

---

## The Problem

PMs can't answer "what does this product actually do?" at the implementation level. Specs describe
what was intended. Code describes what was built. These diverge the moment the first post-spec commit
lands, and they diverge with every subsequent change. Error states are never fully specified. Edge
cases emerge from feature interactions. Implementation constraints shape behavior in ways no spec
anticipated. The answer lives in the codebase, behind a technical skill wall.

## What This Is

A three-tier product intelligence system. Like RAG, but the corpus is code, the index is organized
by product behavior, and the consumer is a PM. The oracle scans the codebase once to build a
queryable cache of product behavior in plain English. Every answer carries a confidence level and
a rendering-layer tag that distinguishes what the frontend actually shows from what the backend
defines. The cache self-improves with use: every cache miss generates a new document, so future
identical queries are answered in seconds.

---

## Quick Start

```bash
# 1. Copy skills to your Claude Code skills directory
cp -r skills/* ~/.claude/skills/

# 2. Open your project in Claude Code
cd /path/to/your/project

# 3. Build the intelligence cache (~2-5 min on first run)
/oracle-init

# 4. Start querying
/oracle-ask "what happens when a user tries to X?"
/oracle-ask "what error does the user see if Y fails?"
/oracle-ask "who can access Z and what happens if they can't?"

# 5. Install git hook for automatic staleness tracking (optional)
bash /path/to/codebase-oracle/scripts/install-git-hook.sh
```

**Prerequisites:** Claude Code CLI, git repository.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    /oracle-ask "..."                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           ┌───────────────▼───────────────┐
           │  L1: Product Map              │  product-map.md
           │  ~1-2K tokens                 │  Domains, flows, roles,
           │  Routing + disambiguation     │  error codes, flags
           └───────────────┬───────────────┘
                           │  Routes to relevant L2 doc
           ┌───────────────▼───────────────┐
           │  L2: Flow Documents           │  flows/*.md
           │  ~3-8K tokens each            │  globals/*.md
           │  Behavior cache per flow      │  Step-by-step, errors,
           │  Self-improving via write-back│  access control, side effects
           └───────────────┬───────────────┘
                           │  Only on miss or explicit enrichment
           ┌───────────────▼───────────────┐
           │  L3: Live Code Exploration    │  Explore subagent
           │  ~30-80K tokens               │  Reads actual source
           │  Authoritative but expensive  │  Always writes back to L2
           └───────────────────────────────┘
```

Cache hits are served from L2 (~10 seconds). Misses trace from code and write to L2 for next time.
See [docs/architecture.md](docs/architecture.md) for the full design including query resolution paths
and the anti-hallucination system.

---

## Available Skills

| Skill | Description |
|-------|-------------|
| `/oracle-init` | Scan codebase, build L1 product map + starter L2 flow docs. Run once on setup or full regeneration. Works on any language or framework. |
| `/oracle-ask "question"` | Query the oracle in plain English. Routes through L1→L2→L3 cache. Serves verified answers from cache when available. |
| `/oracle-refresh <flow>` | Regenerate a specific flow doc, the entire L1 map, or all stale docs. Reports behavior changes vs. prior version. |
| `/oracle-eval` | Analyze cache performance: hit rate, confidence distribution, stale hotspots, time savings estimate. |
| `/oracle-diagram` | _(Planned)_ Generate visual flow diagrams from cached product intelligence. |
| `/oracle-review-spec` | _(Planned)_ Review a spec or PRD against actual codebase behavior. Surfaces contradictions and missing edge cases. |

---

## Cache Performance

From the Documenso demo session (7 queries):

| Metric | Value |
|--------|-------|
| L2 cache hit rate | 57% (4/7 queries served from cache) |
| Cache-served rate | 86% (6/7 queries answered without full trace) |
| L3 miss rate (full trace) | 14% (1 new L2 doc generated) |
| HIGH confidence answers | 71% |
| MEDIUM confidence answers | 29% |
| Estimated time saved | ~3 minutes vs. no-cache baseline |

Cache hit rate climbs with use. A fresh oracle starts at 0% and improves to 60%+ within a single
session of real questions. See [examples/eval-log-sample.jsonl](examples/eval-log-sample.jsonl).

---

## Anti-Hallucination

The most dangerous oracle error is stating backend-defined text as user-visible text. In fullstack
apps, the backend defines error messages and the frontend renders them — often differently. A generic
error handler in the frontend may display "Something went wrong" for dozens of specific backend errors.

Every "user sees" claim in oracle output is tagged:
- **[RENDERED]** — traced to the actual frontend component, toast, or error boundary
- **[BACKEND-DEFINED]** — found in backend code, frontend rendering not verified

This is what surfaced the Documenso expiry bug: backend says one thing, frontend shows another.

---

## Known Limitations

1. **Context window**: Very large codebases may hit token limits during `/oracle-init`. Use flow-specific `/oracle-ask` queries to build the cache incrementally instead.
2. **Minified/compiled code**: Oracle reads source files. Minified bundles, compiled outputs, and generated code are opaque without source maps.
3. **Dynamic dispatch**: Flows that route through plugin systems, dynamic imports, or runtime-registered handlers may be partially traced with MEDIUM/LOW confidence.
4. **Database behavior**: Oracle traces application-layer code. Complex database triggers, stored procedures, and migration side effects are not traced.
5. **External services**: Behavior of third-party APIs (Stripe, SendGrid, etc.) is not traced — only how the application calls them.
6. **Concurrent race conditions**: Oracle documents the sequential happy path thoroughly. Race conditions and timing-dependent bugs require explicit prompting to surface.
7. **L2 doc accuracy decay**: Cache docs become stale as code changes. The git hook marks docs stale automatically, but until refreshed, stale docs are served with a warning. Run `/oracle-refresh all-stale` periodically.

---

## Roadmap

- **`/oracle-diagram`** — Generate Mermaid flow diagrams from L2 doc cache for visual documentation
- **`/oracle-review-spec`** — Load a spec/PRD and diff against oracle cache to surface divergences
- **Playwright validation** — Generate E2E test stubs from L2 docs to verify [RENDERED] claims
- **PM-verified flag** — Allow PMs to mark oracle claims as manually verified after product walkthrough

---

## How It Was Built

Designed and tested over one intensive session on Documenso. The design went through 5 iterations,
each driven by a specific test failure: simple RAG (too slow), static docs (went stale), auto-refresh
(defeated the cache), cache without anti-hallucination (backend/frontend conflation), and the current
design with user-gated escalation and rendering-layer verification.

The findings above weren't engineered — they emerged from running a correctly-designed system on a
real codebase. The anti-hallucination tags are what made the expiry bug findable.

See [docs/architecture.md](docs/architecture.md) for the full design evolution.
See [docs/why-this-matters.md](docs/why-this-matters.md) for the structural argument.

---

## License

MIT — see [LICENSE](LICENSE).
