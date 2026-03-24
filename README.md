# Codebase Oracle

**Ask your codebase what your product actually does. Get PM-language answers with confidence levels, not code dumps.**

A product-aware RAG system where the corpus is code, the index is organized by product behavior, and the consumer is a PM.

[![Claude Code](https://img.shields.io/badge/Claude_Code-Skills-blue)](#installation)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tested on](https://img.shields.io/badge/Tested_on-Documenso_50K_LOC-orange)](#what-i-found)

---

## What I found when I ran this on a real codebase

I pointed the oracle at [Documenso](https://github.com/documenso/documenso), an open-source e-signature platform (~50K lines of code). Here's what it found that no spec, user manual, or dashboard could tell me:

**A signer whose deadline expires mid-session gets a generic error with no explanation.**

The backend defines a specific, helpful message: *"Recipient signing window has expired."* But the frontend error handler doesn't inspect the error code — it displays *"An error occurred while signing the document."* The signer has no idea what went wrong. They'll retry, fail again, and contact support. The backend team built the right error. The frontend never wires it up.

The oracle caught this because it traces to the **rendering layer**, not just the backend. Every user-facing claim is tagged:

```
"An error occurred while signing the document."  [RENDERED — traced to document-signing-text-field.tsx]
"Recipient signing window has expired"            [BACKEND-DEFINED — frontend does not surface this]
```

**Two other findings from the same codebase:**

→ When two signers try to sign the same field simultaneously, the system is safe by design — fields are permanently bound to one recipient at the data model level. But there's a theoretical TOCTOU race condition for same-signer double-submits on non-signature fields (text, checkboxes) because the `field.inserted` check runs outside the database transaction.

→ When a signer opens a link for an already-completed document, there's no error — they're silently redirected to a "Document Signed" completion page. The experience is seamless, but confusing if the signer didn't actually sign. A removed-and-re-added recipient would see "Everyone has signed" without ever having signed themselves.

None of these are in any spec. None show up in any dashboard. They live in the code, and until now, only engineers could find them.

---

## What this is

A Claude Code toolkit with six skills that build a **product intelligence cache** on top of any codebase:

```
You ask:     "What happens when a signing link expires mid-session?"
Oracle reads: 14 source files across 3 modules
Oracle answers: PM-formatted behavior with exact UI text, edge cases,
                risk ratings, and confidence level
Oracle caches: Answer saved — next time anyone asks, instant response
```

The system has three tiers (think CPU cache hierarchy):

```
L1  Product Map     ~2K tokens    Routes questions        Always loaded
L2  Flow Documents  1-3K each     Answers from cache      On-demand, growing
L3  Live Trace      75-100K       Explores codebase       Fallback, writes back to L2
```

Every query that hits L3 writes back to L2. The system gets faster and more comprehensive with every question asked.

---

## Installation

**Prerequisites:** Claude Code ([install guide](https://code.claude.com/docs/en/setup)) with a Claude Pro ($20/month) or Max subscription.

```bash
# Clone the repo
git clone https://github.com/ajinkya-t/codebase-oracle

# Run the setup script (symlinks skills into ~/.claude/skills/)
cd codebase-oracle
./setup

# Verify the installation
./setup --verify

# Navigate to any codebase
cd your-project

# Recommended: run /init first for better results
claude
/init

# Build the product intelligence cache
/oracle-init

# Start asking questions
/oracle-ask What happens when a user tries to sign an expired document?
```

> **Updating:** Just run `git pull` inside your clone — the setup script installs a `post-merge` hook that re-runs automatically, so new and updated skills are always reflected.

**Optional: install the git hook for automatic staleness tracking**
```bash
bash ~/path/to/codebase-oracle/scripts/install-git-hook.sh
```
> Run this from inside the project you want to track (not the oracle repo). Replace the path with wherever you cloned codebase-oracle.

---

## Available skills

| Skill | Purpose | When to use |
|---|---|---|
| `/oracle-init` | Scan the codebase, build L1 product map + starter L2 flow docs | First time setup on any project (~8 min) |
| `/oracle-ask` | Ask product behavior questions with cached answers | Daily PM work — "what does X actually do?" |
| `/oracle-refresh` | Regenerate stale docs or refresh the product map | After significant code changes |
| `/oracle-eval` | View cache hit rates, usage patterns, cost savings | Weekly review of oracle performance |
| `/oracle-diagram` *(planned)* | Generate PM-readable mermaid flowcharts from cache | When you need a visual for a stakeholder brief |
| `/oracle-review-spec` *(planned)* | Cross-reference a new spec against known product behavior | Before engineering starts on a new feature |

---

## How it works

### The query flow

```
Question asked
     │
     ▼
  Load L1 product map → route to relevant flow
     │
     ├── L2 doc exists + fresh ──────► Answer from cache (42s)
     │
     ├── L2 doc exists + partial ────► Ask user: [1] cache-only or [2] trace?
     │                                  └─► [2]: targeted trace → merge → answer
     │
     ├── L2 doc exists + stale ──────► Answer with ⚠ warning
     │
     └── No L2 doc (cache miss) ─────► Full trace → write new L2 doc → answer
```

### Cache discipline

The oracle does NOT re-read code on every question. Cache hits answer exclusively from stored docs. The Explore subagent only launches on genuine cache misses or when the user explicitly approves an enrichment trace. This is enforced through explicit prohibition rules in the skill, not left to the model's judgment.

### Anti-hallucination

For fullstack apps, the backend may define one error message while the frontend displays a completely different one. The oracle traces user-facing text to the **rendering layer** (the React component, toast handler, or error boundary that actually displays it) and tags every claim:

- `[RENDERED]` — traced to the frontend component that displays this text
- `[BACKEND-DEFINED]` — found only in backend code; what the user actually sees may differ

This prevents the most dangerous class of AI hallucination: stating technically-grounded but user-invisible text as fact.

### Self-improving loop

Every L3 trace and every user-approved enrichment writes findings back to the L2 cache. The cache grows with use:

```
After oracle-init:        5-8 starter flow docs
After 8 queries:          3 additional docs, 87.5% cache-served rate
After enrichment cycle:   Same question → instant cache hit (42s vs 3 min)
```

---

## Observed performance

Tested on Documenso (~50K LOC, TypeScript/Remix) with Claude Opus 4.6:

| Metric | Observed |
|---|---|
| oracle-init time | 8m 17s (4 parallel Explore agents, ~356K tokens) |
| Cache hit response | 42-47s wall time |
| Cache miss response | 2-3 min (includes write-back) |
| Enrichment response | ~3 min (targeted trace + merge) |
| Cache-served ratio (8 queries) | 87.5% (62.5% full hits + 25% enriched) |
| Self-improving loop | Confirmed — enrichments persist across sessions |

**From the eval report (8 queries):**

```
Actual time:      (5 × 5s) + (2 × 10s) + (1 × 60s) = 105s
Without cache:    8 × 60s = 480s
Time saved:       375s (~6 minutes)
```

> Note: the 5s/10s per-query figures in this calc represent answer generation time only. Full wall time per cache hit (including staleness check, L2 doc read, and formatting) is 42-47s.

---

## Confidence levels

Every answer includes a confidence indicator so you know how much to trust it:

| Level | Meaning |
|---|---|
| **✅ VERIFIED** | Fresh L2 doc, all source files unchanged since analysis |
| **⚠ LIKELY ACCURATE** | L2 doc exists, minor source files changed (not the entry-point) |
| **⚠ NEEDS VERIFICATION** | Primary entry-point file changed, or complex multi-module trace |
| **⚠ LOW CONFIDENCE** | No test coverage on this code path, or dynamic behavior that can't be statically resolved |

**Calibration note:** Any answer where a user-facing text claim is tagged `[BACKEND-DEFINED]` should be treated as LIKELY ACCURATE at most — the frontend rendering layer was not verified. HIGH confidence is only warranted when all "what the user sees" claims carry `[RENDERED]` tags.

---

## Directory structure generated

```
.product-oracle/
├── product-map.md              # L1: Feature domains, flows, roles, error codes
├── .staleness.json             # Tracks which L2 docs need refreshing
├── .eval-log.jsonl             # Query-by-query usage metrics
├── flows/                      # L2: One doc per product flow
│   ├── recipient-signing.md
│   ├── document-sending.md
│   └── ...
├── globals/                    # L2: Cross-cutting behaviors
│   ├── authentication.md
│   ├── error-formatting.md
│   └── notification-triggers.md
├── diagrams/                   # Generated mermaid diagrams
└── reviews/                    # Spec review reports
```

---

## Framework agnostic

The oracle detects your application type and adapts its scanning strategy:

| Application type | Entry points scanned | Output vocabulary |
|---|---|---|
| Web app (SPA, SSR, API) | Routes, page components, API handlers | "User sees," "page displays" |
| CLI tool | Command definitions, argument parsers | "Output shows," "terminal displays" |
| Library / SDK | Public API surface, exported functions | "Consumer gets," "function returns" |
| Event-driven service | Event handlers, queue consumers | "System processes," "handler produces" |
| Data pipeline | Pipeline stages, transformations | "Stage outputs," "pipeline produces" |

Works with any language or framework. Tested on TypeScript/Remix. Designed to work on Python, Go, Java, Rust, and anything else Claude Code can read.

---

## Known limitations

1. **Initial L2 docs can contain hallucinated behavior.** The [RENDERED]/[BACKEND-DEFINED] tagging mitigates this for user-facing text. Enrichment traces are more accurate than init scans. For production use, add a "PM verified" flag for human-checked docs.

2. **Source file dependency tracking is best-effort.** If the Explore subagent reads a file but doesn't list it in structured output, the staleness checker won't track it. Consequence: some stale docs may appear fresh.

3. **Doesn't trace non-code product logic.** Feature flags in a config service, business rules in a database, or behavior from environment variables won't be found unless they're visible in the source code.

4. **Cache discipline depends on skill instruction quality.** Claude may occasionally auto-escalate on ambiguous partial-coverage scenarios. The explicit prohibition language reduces this significantly but doesn't eliminate it.

5. **Token usage on init is substantial.** oracle-init uses ~356K tokens on a 50K LOC codebase. On a Pro subscription this may consume a significant portion of your usage window. Plan accordingly.

6. **Git hook is not installed automatically.** You must run `install-git-hook.sh` manually. Without it, stale L2 docs won't be flagged after code changes.

7. **Enrichment traces are expensive.** A user-approved enrichment (Path A-Enrich) costs ~104K tokens — comparable to a full cache miss. The user-gating mechanism ensures this cost is intentional, not accidental.

---

## Roadmap

- [ ] **`/oracle-diagram`** — Generate PM-readable mermaid flowcharts from L2 cache with risk color-coding
- [ ] **`/oracle-review-spec`** — Cross-reference new specs against accumulated oracle knowledge
- [ ] **Playwright validation** — Runtime verification via browser automation, DOM text extraction for ground-truth checking
- [ ] **PM verified flag** — Human toggle on L2 docs after manual spot-checking
- [ ] **Cross-codebase testing** — Verify framework-agnostic claims on Python CLI, Go API, React component library
- [ ] **Confidence calibration tightening** — Cap confidence at MEDIUM when any user-facing claim is [BACKEND-DEFINED]

---

## How this was built

Designed and tested in one intensive day. Five design iterations, each driven by specific evaluation findings — not assumptions:

| Version | What changed | What broke that led to this |
|---|---|---|
| V1 | Flat product directory | Too expensive to load and maintain |
| V2 | Three-tier cache | Cache hits were auto-escalating to live traces |
| V3 | Cache discipline + write-back | Enrichments weren't persisting across sessions |
| V4 | User-gated escalation (interrupt before answer) | Trace offers after the answer were being ignored |
| V5 | Anti-hallucination ([RENDERED] tags) | Backend-defined error text stated as user-visible |

The full design document, evaluation framework, and iteration history are available at: [link to reference doc / blog post]

---

## Architecture deep dive

See [docs/architecture.md](docs/architecture.md) for the complete technical design including the three-tier cache, cache invalidation via git hooks, the fork/write-back constraint, and the anti-hallucination system.

See [docs/why-this-matters.md](docs/why-this-matters.md) for the structural argument: why specs, user manuals, and dashboards systematically fail to capture actual product behavior.

---

## Using this for content

If you're building in public and want to create content from your oracle findings, see [docs/for-content-creators.md](docs/for-content-creators.md) for guidance on capturing compelling screenshots, structuring LinkedIn posts, and framing the narrative around information asymmetry rather than tool usage.

---

## Contributing

Issues and PRs welcome. The most valuable contributions:

- **Test on different codebases** — especially non-TypeScript, non-web-app projects. The framework-agnostic claims need broader validation.
- **Improve skill instructions** — if the oracle misbehaves on your codebase (breaks cache discipline, misformats answers, misidentifies entry points), the fix is usually in the SKILL.md instructions.
- **Add to the eval framework** — new test questions, new failure types, regression test cases.

---

## License

MIT — see [LICENSE](LICENSE)

---

*Built with [Claude Code](https://code.claude.com) by [Ajinkya](https://github.com/ajinkya-t). The oracle is a Claude Code toolkit — it uses Claude's intelligence but the architecture, cache design, eval framework, and anti-hallucination system are original work.*
