# Why This Matters

## The Structural Problem

A product spec describes what the product is *intended* to do. The codebase describes what
it *actually* does. These two descriptions diverge the moment the first commit lands after
the spec is written — and they continue to diverge with every subsequent change.

This isn't a process failure. It's a physics problem. Specs are written before implementation,
and implementation reveals things the spec didn't anticipate: edge cases, error states,
performance constraints, and interactions between features that weren't designed together.
The code becomes the ground truth, but most product people can't read it.

## Four Structural Arguments

### 1. Spec Drift

Spec drift is not a discipline problem — it's structural. The Thoughtworks analysis of
spec-driven development (2025) and the ArXiv paper "Spec-Driven Development: From Code to
Contract" (Tao et al., 2025) both confirm: by Sprint 3, specs no longer match code. The
code becomes the de facto truth. Every refactor, hotfix, and workaround introduces drift that
nobody updates the spec for, because the maintenance cost exceeds the perceived benefit.

Over a 12-month release cycle, a non-trivial product can accumulate dozens of undocumented
behavioral changes — small divergences that are invisible until they cause a support
escalation, a failed integration, or a user complaint that nobody can reproduce because the
documented behavior is wrong.

### 2. Emergent Behavior

Some behaviors aren't specified anywhere because they emerge from the interaction of features
that were designed independently. The Documenso signing flow has a theoretical TOCTOU (time-of-check
to time-of-use) vulnerability: if the same signer submits a non-signature field (text,
checkbox) twice in rapid succession, both submissions pass the `field.inserted` check before
either one sets it — a race condition that isn't in any spec because it emerged from the
intersection of concurrent requests and a check that runs outside the database transaction.
(Fields are permanently bound to one recipient at the data model level, so two *different*
recipients signing the same field is safe by design — the race is same-signer, same field.) The oracle finds these because it traces actual code paths, not intended
design paths.

### 3. Undocumented Error Experiences

Error states are the most under-documented part of any product. Specs typically describe
the happy path and maybe one or two error cases. The actual codebase may have 15-20
distinct error states for a single flow, each with different user experiences.

The Documenso discovery: the backend throws `RECIPIENT_EXPIRED` with the message
`"Recipient signing window has expired"`. The frontend's signing field component catches
errors generically and displays `"An error occurred while signing the field."` These are
completely different user experiences. A PM reading the backend code would think the user
sees a clear, descriptive error. A PM reading the frontend would see the generic message.
Neither is the full picture without tracing both layers.

This is why the oracle has the `[RENDERED]` / `[BACKEND-DEFINED]` tagging system. It's not
a nice-to-have — it prevents a specific class of hallucination that's common when AI systems
analyze fullstack codebases.

### 4. Implementation Constraints

Code contains constraints that specs never mention because they're discovered during
implementation: "we can only do X because Y library doesn't support Z," "this flow
requires N database round-trips so we added a quota check," "this feature is behind a
flag because the migration isn't complete yet." These constraints shape user behavior but
they're invisible to anyone who isn't reading the code.

## A Verification Layer, Not a Documentation Replacement

This system is not a documentation generator. It's a verification layer.

The question it answers is not "what did we intend to build?" but "what did we actually build?"

These are different questions. The first is answered by product specs, PRDs, and design docs.
The second is answered by the codebase. The oracle makes the codebase queryable in the
same language that PMs use — not a replacement for specs, but a way to verify that what's
shipped matches what was specified.

The most useful workflow isn't querying the oracle in isolation. It's querying it alongside
a spec and running `/oracle-ask "compare to spec"` to surface divergences before they become
support tickets.

## The Finding That Prompted This

Running the oracle on Documenso surfaced this in the first session:

> **What happens when a document signing link expires after the signer has opened it
> but before they sign?**

The oracle's response (after tracing both layers):

> The signer clicks a signature field and receives a generic error: "An error occurred
> while signing the document." [RENDERED — toast handler]
>
> The backend defines a more specific error: "Recipient signing window has expired."
> [BACKEND-DEFINED — not surfaced to the user]
>
> The signer is NOT redirected to the expired page. They remain on the signing screen
> with an unhelpful generic error and no clear recovery path.
>
> This is a product risk: a signer who hits this state doesn't know their link is
> expired, can't request a new one from this screen, and may try to sign repeatedly.

This finding came from tracing two separate code layers — something that's invisible if
you read either layer in isolation. The oracle's anti-hallucination system is what made
this findable, because it forced the trace to follow the error from definition to rendering.

That's the value: not that the oracle knows your codebase, but that it knows *which
questions to ask* when reading it.
