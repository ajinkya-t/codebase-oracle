> [Example output — what /oracle-review-spec would produce for a hypothetical spec]
> Skill status: Planned (oracle-review-spec not yet implemented)
> This demonstrates the intended output format.

---

# Spec Review: "Add Team Billing"

**Spec summary:** Teams should be able to have their own Stripe subscription, separate from
organisation-level billing. Team admins can upgrade/downgrade their team's plan, and document
quotas apply at the team level rather than the organisation level.

---

## Dependencies Found in Codebase

### 1. Existing Billing System (Organisation-Level)
The current billing system is entirely organisation-scoped. Stripe customer IDs are stored on
the Organisation model. The `NEXT_PUBLIC_FEATURE_BILLING_ENABLED` flag gates all billing UI.
Plan limits are checked against the organisation's subscription, not individual teams.

**Impact on spec:** The spec requires a second billing entity type (Team). This is a data model
change — `Team` needs a Stripe customer ID and subscription fields. The existing billing
abstractions (`getOrganisationSubscription`, `checkOrganisationQuota`) would need team
equivalents or to be generalized.

**Source:** `packages/lib/server-only/organisation/get-organisation-subscription.ts`,
`packages/prisma/schema.prisma` (Organisation model)

### 2. Team Roles and Permission Gating
Team billing management (upgrade/downgrade) should only be accessible to Team Admins.
The existing team role system (`TeamMemberRole.ADMIN`, `TeamMemberRole.MANAGER`) is
already implemented and enforced via tRPC procedures.

**Impact on spec:** No new roles needed. The spec should explicitly state that Team Managers
cannot manage billing — currently, Managers can do everything except delete the team. Billing
management should be Admin-only, which requires adding a new permission check.

**Source:** `packages/lib/types/team.ts`, `packages/trpc/server/routers/team/`

### 3. Document Quota Enforcement
The current quota check (`checkDocumentCreationLimit`) reads the organisation's plan tier.
If quotas should apply at the team level, this function must be updated to check the team's
subscription when the document is created within a team context.

**Impact on spec:** The spec says "quotas apply at the team level" but doesn't define what
happens when a team has no subscription (free tier). Does it inherit the organisation's quota,
or is it capped at the free tier independently?

**Source:** `packages/lib/server-only/document/check-document-creation-limit.ts`

---

## Edge Cases Surfaced

### 1. Org-Billed vs Team-Billed Documents
What happens to documents created before team billing was enabled? They were created under
the organisation quota. When team billing activates, do historical documents count against
the team quota, the org quota, or neither?

**Spec gap:** No migration strategy defined for existing documents.

### 2. Team Deletion with Active Subscription
The current team deletion flow sends a notification email and removes all members but has
no billing cleanup. If a team has an active Stripe subscription and is deleted, the
subscription would continue billing the Stripe customer.

**Spec gap:** Add cancellation behavior: "When a team is deleted, its Stripe subscription
is automatically cancelled."

### 3. Free Organisation + Paid Team
Can a team have a higher plan than its parent organisation? For example: organisation on
Free tier (5 doc limit), team on Pro tier (unlimited). If the org's free-tier limit is
checked first, the team upgrade becomes meaningless.

**Spec gap:** Spec must define the precedence rule: team plan OR org plan, whichever is higher.

### 4. Team Transfer Between Organisations
Documenso supports transferring teams between organisations (admin feature). If a team
has its own Stripe subscription, what happens on transfer? The new org may have different
billing settings or the Stripe customer may be tied to the old org's account.

**Spec gap:** Out of scope, but worth flagging as a future incompatibility.

---

## Contradiction Detected

**Spec says:** "Team admins can upgrade or downgrade their team's plan independently."

**Code shows:** The current Stripe webhook handler (`handleStripeWebhook`) updates billing
state on the Organisation model. If team billing fires the same Stripe events, the webhook
handler will route updates to the wrong entity unless explicitly updated.

**Resolution needed:** The spec must either (a) define a new Stripe product/price structure
for team subscriptions, or (b) specify that team billing reuses the org webhook handler with
a new entity type discriminator.

---

## Suggested Spec Additions

1. **Define free-tier behavior for teams without a subscription.** Recommended: inherit
   organisation quota until the team upgrades.

2. **Add subscription cancellation to the team deletion flow.** One sentence: "Deleting a
   team with an active subscription automatically cancels the subscription via Stripe."

3. **Define quota precedence.** Recommended: "Document quotas use the higher of the team's
   plan limit or the organisation's plan limit."

4. **Specify the Stripe product structure.** Are team subscriptions a separate Stripe product,
   or a quantity-based extension of the org product? This affects the webhook handler design.

---

*Generated by /oracle-review-spec (planned). Source refs verified against Documenso codebase.*
