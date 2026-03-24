---
name: oracle-eval
description: >
  Analyze oracle usage and performance. Reads the eval log and produces
  a summary of cache hit rates, confidence distribution, cost estimates,
  and most-queried flows. Use to assess how well the oracle is working.
disable-model-invocation: true
---

# Oracle Eval — Usage and Performance Summary

You are a product-oracle analytics agent. Your job is to read the eval log and produce
a clear, actionable summary of how well the oracle is serving product questions.

---

## Step 1 — Check Prerequisites

1. Check if `.product-oracle/.eval-log.jsonl` exists.
   - If it does NOT exist or is empty, print:
     > No eval log found. Run `/oracle-ask` to start logging queries, then come back here.
   - Then STOP.

2. Read the entire `.product-oracle/.eval-log.jsonl` file. Each line is a JSON object with:
   ```
   timestamp, question, resolution, l2_doc_used, globals_loaded,
   confidence, has_test_coverage, response_length_chars, write_back, stale_warning
   ```

3. Also read `.product-oracle/product-map.md` to cross-reference the flow registry.

---

## Step 2 — Compute Metrics

Calculate the following from the eval log entries:

### 2A. Volume

- **Total queries**: count of all log entries
- **Date range**: earliest timestamp to latest timestamp
- **Queries per day** (average): total queries / number of distinct days

### 2B. Cache Performance

- **L2 cache hit rate**: count of `L2_HIT` / total queries (as percentage)
- **Stale rate**: count of `L2_STALE` / total queries (as percentage)
- **Cache miss rate**: count of `L3_MISS` / total queries (as percentage)
- **Write-back count**: count of entries where `write_back` is true
  (these are cache misses that generated new L2 docs)

### 2C. Confidence Distribution

- **HIGH**: count and percentage
- **MEDIUM**: count and percentage
- **LOW**: count and percentage

### 2D. Test Coverage

- **Queries with test coverage**: count where `has_test_coverage` is true (percentage)
- **Queries without test coverage**: count where `has_test_coverage` is false (percentage)

### 2E. Most-Queried Flows

- Group queries by `l2_doc_used` (normalize null to "no L2 doc")
- Rank by frequency
- For each of the top 10 flows: query count, cache hit ratio, average confidence

### 2F. Stale Hotspots

- List all queries where `stale_warning` is true
- Group by `l2_doc_used` to find which docs go stale most often

### 2G. Cost Estimate

Estimate the cost savings from caching:

- **Cache hits saved**: count of `L2_HIT` entries. Each cache hit avoids a full code
  exploration that would otherwise use an Explore subagent. Estimate ~30 seconds saved
  per cache hit (conservative).
- **Time saved**: cache hits × 30 seconds
- **Cache misses cost**: count of `L3_MISS` entries. Each miss triggers a live trace.
  Estimate ~60 seconds per miss.
- **Total query time**: (L2_HIT × 5s) + (L2_STALE × 10s) + (L3_MISS × 60s)
- **Hypothetical no-cache time**: total queries × 60s
- **Time savings**: hypothetical - actual

---

## Step 3 — Generate Report

Print the report in this exact format:

```
=== Oracle Eval Report ===
Period: {earliest date} → {latest date}
Total queries: {N}  |  Avg: {N}/day

── Cache Performance ──────────────────────────
  Hit rate:    {N}% ({count} queries answered from verified L2 cache)
  Stale rate:  {N}% ({count} queries answered from outdated L2 cache)
  Miss rate:   {N}% ({count} queries required live code trace)
  Write-backs: {count} new L2 docs generated from misses

── Confidence Distribution ────────────────────
  HIGH:   {N}% ({count})
  MEDIUM: {N}% ({count})
  LOW:    {N}% ({count})

── Test Coverage ──────────────────────────────
  Covered:   {N}% ({count} queries about tested flows)
  Uncovered: {N}% ({count} queries about untested flows)

── Most-Queried Flows ─────────────────────────
  Rank  Flow                          Queries  Hit Rate  Confidence
  1.    {flow name}                   {N}      {N}%      {avg}
  2.    {flow name}                   {N}      {N}%      {avg}
  ...   (up to 10)

── Stale Hotspots ─────────────────────────────
  {doc path} — stale {N} times
  {doc path} — stale {N} times
  ...
  (These docs should be prioritized for refresh)

── Cost Estimate ──────────────────────────────
  Estimated time saved by caching: ~{N} minutes
  Cache hit queries:  ~{N}s avg response (vs ~60s without cache)
  Cache miss queries: ~{N}s avg response
  Overall efficiency: {N}% of queries served from cache

── Recommendations ────────────────────────────
```

---

## Step 4 — Generate Recommendations

Based on the metrics, generate 3-5 actionable recommendations. Use these rules:

**If cache hit rate < 50%:**
> "Low cache hit rate. Consider running `/oracle-init` to regenerate the full cache,
> or run `/oracle-ask` on your most common questions to build up coverage."

**If stale rate > 25%:**
> "High stale rate ({N}%). The codebase is changing faster than the cache.
> Stale hotspots: {list top 3 stale docs}. Run `/oracle-ask` with 'refresh'
> on these flows to update them."

**If LOW confidence > 20%:**
> "Many low-confidence answers ({N}%). Common in flows with complex branching
> or cross-module dependencies. Review these L2 docs for accuracy:
> {list flows with LOW confidence}."

**If test coverage < 50%:**
> "{N}% of queried flows lack test coverage. These flows have higher risk
> of undocumented behavior changes: {list uncovered flows}."

**If any flow queried > 5 times:**
> "'{flow name}' is queried frequently ({N} times). Ensure its L2 doc is
> thorough and up to date — this is a high-value cache entry."

**If write-back count is high (> 50% of misses result in write-back):**
> "Cache is growing organically. {N} new L2 docs were auto-generated.
> Review them for accuracy: {list write-back doc paths}."

**If total queries < 5:**
> "Limited data — only {N} queries logged. Use the oracle more to build
> meaningful performance metrics."

Print each applicable recommendation as a bullet point under the Recommendations section.

---

## Step 5 — Offer Next Actions

After the report, print:

```
── Next Actions ───────────────────────────────
  /oracle-ask "your question"  — query the oracle (builds cache on miss)
  /oracle-init                 — full cache regeneration
  /oracle-eval                 — run this report again after more usage
```
