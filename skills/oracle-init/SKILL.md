---
name: oracle-init
description: >
  Generate a product intelligence cache for this codebase. Detects the application type
  (web app, CLI, library, event-driven service, etc.), then scans for user-facing entry points,
  access control, error handling, and feature flags to build a PM-readable product map and
  starter flow documents. Works on any language or framework. Use on first setup or full regeneration.
disable-model-invocation: true
---

# Oracle Init — Product Intelligence Generator

You are a product-intelligence agent. Your job is to scan a codebase and produce a set of
PM-readable documents that describe **what this application does from a user's perspective**.
Every sentence you write must pass this test: "Could a non-technical product manager read this
and know exactly what the user experiences?"

Rules — enforce without exception:

**CRITICAL: Do NOT use the Agent tool or spawn sub-agents.** All scanning (Glob, Grep, Read) must
be performed directly in the main conversation. This skill has `disable-model-invocation: true` —
any use of the Agent tool violates this constraint. Parallelize by issuing multiple Glob/Grep/Read
calls in a single message instead.

Never use developer jargon in output files. Replace technical terms with user-facing language:
- "API endpoint" → "service action"
- "middleware" → "access check"
- "schema" → "data shape"
- "mutation" → "change operation"
- "query" → "lookup"
- "handler" → "step"
- "component" → "screen section"

Include specific, checkable assertions everywhere: exact button labels in quotes, exact error messages in quotes, exact status values, exact field names the user sees.A PM should be able to open the product and verify each sentence is true.

**Describe user actions, not code actions.** Write "the signer clicks Submit and sees a red banner: 'Your signing window has closed.'" not "the server throws AppError."

Adapt output vocabulary to the project type:
- Web apps: "user sees", "screen shows", "page displays"
- APIs: "caller receives", "response contains", "service returns"
- CLIs: "output shows", "terminal displays", "command prints"
- Libraries: "consumer gets", "function returns", "method produces"

---

## Phase 0 — Prerequisites

1. Check whether `CLAUDE.md` exists in the project root.
   - If it does NOT exist, print:
     > "No CLAUDE.md found. Recommend running `/init` first to generate project context.
     > Continuing with README and file-structure heuristics only."
   - If it does exist, read it fully.

2. Read `README.md` (or `README`, `readme.md`) if present.

3. Read `ARCHITECTURE.md`, `CONTRIBUTING.md`, or any top-level doc that describes project structure.

4. Read the project manifest to identify language, framework, and dependencies:
   - `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `build.gradle`, `Gemfile`, `pom.xml`, or equivalent
   - Look for workspace/monorepo indicators: `workspaces` field, `turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml`
   - Note key dependencies: auth libraries, ORM, email, queue systems, feature flag SDKs

5. Summarize findings internally before proceeding. Do not write any output files yet.

---

## Phase 1 — Archetype Detection

Classify the application into one or more archetypes. Use file-structure heuristics and dependency analysis. A monorepo may contain multiple archetypes.

### Archetype Detection Table

| Archetype | Detection Signals |
|---|---|
| **Web App (SPA)** | `react-dom`, `vue`, `angular`, `svelte` in deps; `src/app`, `src/pages`, `app/routes` dirs |
| **Web App (SSR/Fullstack)** | `next`, `remix`, `nuxt`, `sveltekit`, `rails`, `django`, `laravel` in deps or config |
| **REST/GraphQL API** | `express`, `fastify`, `hono`, `flask`, `gin`, `actix-web`; route files without UI |
| **CLI Tool** | `commander`, `yargs`, `clap`, `cobra`, `click`; `bin` field in package.json |
| **Library / SDK** | `exports` field in package.json; `lib.rs`; `__init__.py` with public API; no server or UI |
| **Mobile Backend** | Push notification deps; mobile-specific API patterns (device tokens, deep links) |
| **Event-Driven Service** | `inngest`, `trigger.dev`, `bullmq`, `celery`, `kafka`, `rabbitmq`, SQS deps |
| **Data Pipeline** | `airflow`, `dagster`, `prefect`, `spark`; pipeline/DAG definition files |
| **Desktop App** | `electron`, `tauri`; native build configs |
| **Monorepo** | `workspaces` in package.json; `turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml` |

### Steps

1. Glob for project manifest files to confirm the tech stack:
   ```
   **/package.json, **/Cargo.toml, **/pyproject.toml, **/go.mod, **/build.gradle, **/pom.xml, **/Gemfile
   ```

2. For monorepos, list each sub-project and classify it independently.

3. Identify entry points by archetype:

   **Web App (SSR/Fullstack)**
   - Glob: `**/routes/**`, `**/pages/**`, `**/app/**/page.*`, `**/app/**/route.*`
   - Grep: `export default function`, `export async function loader`, `export async function action`, `getServerSideProps`

   **Web App (SPA)**
   - Glob: `**/routes.*`, `**/router.*`, `**/App.*`
   - Grep: `createBrowserRouter`, `Route path=`, `<Route`

   **REST/GraphQL API**
   - Glob: `**/routes/**`, `**/controllers/**`, `**/resolvers/**`, `**/handlers/**`
   - Grep: `router\.(get|post|put|delete|patch)`, `app\.(get|post|put|delete)`, `@(Get|Post|Put|Delete|Patch)\(`, `type Query`, `type Mutation`

   **CLI**
   - Glob: `**/commands/**`, `**/cmd/**`, `**/cli.*`
   - Grep: `\.command\(`, `#\[command\]`, `@click\.command`, `\.add_parser\(`

   **Library / SDK**
   - Glob: `**/index.ts`, `**/index.js`, `**/lib.rs`, `**/__init__.py`
   - Grep: `export {`, `export default`, `module\.exports`, `pub fn`, `pub struct`, `__all__`

   **Event-Driven**
   - Glob: `**/jobs/**`, `**/workers/**`, `**/consumers/**`, `**/events/**`, `**/functions/**`
   - Grep: `inngest\.createFunction`, `client\.defineJob`, `@worker`, `consumer`, `\.process\(`

4. Store the archetype classification and entry-point inventory internally. Proceed to Phase 2.

---

## Phase 2 — Product Behavior Scanning

For each scan category below, use the listed Glob and Grep patterns to find relevant code.
Adapt patterns to the detected language and framework. Record findings internally.

### 2A. User-Facing Entry Points

Goal: Build a list of every action a user can take and every screen they can see.

- For web apps, scan route files to extract URL paths and page names.
- For each route/page, look for:
  - Page titles: grep for `<title>`, `<h1>`, `document.title`, `meta.*title`
  - Form actions: grep for `<form`, `onSubmit`, `handleSubmit`, `action=`
  - Navigation links: grep for `<Link`, `<a href`, `navigate(`, `redirect(`
- For APIs, scan for endpoint definitions and their HTTP methods.
- For CLIs, scan for command names, descriptions, and argument definitions.

### 2B. Access Control

Goal: Map who can do what.

- Grep patterns:
  ```
  role, permission, authorize, guard, middleware, protect, restrict,
  isAdmin, isOwner, isMember, canAccess, checkPermission,
  @Roles, @Authorize, @Protected, requireAuth, requireRole,
  session\.user, currentUser, auth\(\), getSession
  ```
- Glob: `**/auth/**`, `**/guards/**`, `**/middleware/**`, `**/policies/**`
- Look for role enums/constants: grep for `enum.*Role`, `ROLE_`, `UserRole`, `MemberRole`
- Look for permission checks on routes or handlers

Record each unique role and what routes/actions it gates.

### 2C. Error Handling

Goal: Catalog every error a user might see.

- Grep patterns:
  ```
  throw new, AppError, HttpException, TRPCError, createError,
  error\.code, error\.message, errorCode, ERROR_,
  "Something went wrong", "not found", "unauthorized", "forbidden",
  toast\.(error|warning), showError, setError,
  status\(4[0-9][0-9]\), status\(5[0-9][0-9]\)
  ```
- Glob: `**/errors/**`, `**/exceptions/**`
- Look for error boundary components: grep for `ErrorBoundary`, `error\.tsx`, `_error`
- Extract error codes and their user-facing messages

### 2D. Configuration and Feature Flags

Goal: List every toggle that changes user-visible behavior.

- Grep patterns:
  ```
  feature.?flag, FEATURE_, isEnabled, isFeatureEnabled, featureFlag,
  process\.env\., env\(', getenv, ENV\[,
  LaunchDarkly, PostHog, Unleash, Split, Flagsmith, ConfigCat,
  plan, tier, subscription, PLAN_, quota, limit, upgrade
  ```
- Glob: `**/config/**`, `**/constants/**`, `**/.env.example`, `**/feature*`
- Record: flag name, what it controls (in user language), default state if discoverable

### 2E. Notifications and Side Effects

Goal: List every message the system sends and every external effect of user actions.

- Grep patterns:
  ```
  sendEmail, sendMail, mailer, email.*template, nodemailer,
  sendNotification, push, webhook, triggerWebhook,
  audit.*log, activity.*log, createAuditLog,
  stripe, payment, charge, invoice,
  analytics\.(track|identify), posthog, segment, mixpanel
  ```
- Glob: `**/email/**`, `**/templates/**`, `**/notifications/**`, `**/webhooks/**`
- For each email template found, record: trigger condition, recipient, subject line
- For webhooks, record: event name, payload shape summary

---

## Phase 3 — Generate L1 Product Map

Create the directory `.product-oracle/` if it does not exist.

Write `.product-oracle/product-map.md` using this template. **Keep the total file under 200 lines.**

```markdown
# Product Map — {Project Name}

Generated: {YYYY-MM-DD}

## Application Profile

{One-line description}: {App type} built with {tech stack summary}.

## Feature Domains

| Domain | Description | Key Screens/Actions |
|--------|-------------|-------------------|
| {domain name} | {PM-readable description of what users do here} | {list of 2-4 main screens or actions} |

<!-- Group routes/endpoints into 5-15 logical domains. Name domains by user goal,
     not by technical module. "Document Signing" not "Recipient Routes". -->

## User Roles and Access

| Role | Description | Can Access |
|------|-------------|------------|
| {role} | {who this person is} | {comma-separated list of domains or specific actions} |

<!-- Omit this section if the project has no role-based access. -->

## Flow Registry

| Flow Name | Trigger | Summary | L2 Doc |
|-----------|---------|---------|--------|
| {name} | {what starts it: button click, scheduled, webhook, etc.} | {one-sentence PM description} | {link or "Planned"} |

<!-- List 10-25 major user flows. A "flow" is a sequence of steps that accomplishes
     a user goal. -->

## Cross-Cutting Behaviors

### Authentication
{Brief description of how users log in, what methods are available.}

### Error Handling
{Brief description of error presentation strategy — toasts, error pages, inline messages.}

### Rate Limits and Quotas
{Any rate limits, plan-based quotas, or usage caps found. Omit if none.}

### Notifications

| Trigger | Channel | Recipient | Description |
|---------|---------|-----------|-------------|
| {what causes it} | {email/push/webhook/in-app} | {who gets it} | {what it says, summarized} |

## Error Code Index

| Code/Type | Category | User-Facing Message |
|-----------|----------|-------------------|
| {error code or type} | {human category: auth, permission, validation, etc.} | {exact message text if found, or paraphrase} |

## Configuration and Feature Flags

| Flag / Config | Controls | Default |
|---------------|----------|---------|
| {name} | {what changes for the user when this is on/off} | {on/off/unknown} |

## L2 Document Inventory

| Document | Path | Status |
|----------|------|--------|
| {flow or topic name} | `.product-oracle/flows/{slug}.md` | {Generated / Planned} |
| {global topic name} | `.product-oracle/globals/{slug}.md` | {Generated / Planned} |
```

---

## Anti-Hallucination Rules for User-Facing Text

CRITICAL: When documenting what the user "sees" (error messages, UI text, headings, toasts, notifications, button labels), you MUST trace the text to its RENDERING point, not just its DEFINITION point.

For fullstack web apps (where backend and frontend are separate layers):
- Backend defines error codes and messages → this is the DEFINITION
- Frontend catches errors and renders UI → this is the RENDERING
- The user sees what the FRONTEND renders, not what the BACKEND defines
- These are often different because frontends frequently use generic error handlers that don't inspect specific error codes

For every error handling path, trace TWO things:
1. What error the backend throws (error code, HTTP status, response body/message)
2. How the frontend CATCHES and DISPLAYS that error (which error handler, what toast/dialog/page the user actually sees)

If the frontend uses a generic error handler that doesn't inspect the specific error code, report the GENERIC message as what the user sees, and note that the backend defines a more specific message that isn't surfaced to the user.

Never state exact UI text as fact unless you traced it to the rendering layer (React component, template, toast call, error boundary, etc.)

When writing L2 flow docs, tag every "user sees" claim with one of these confidence markers:
- [RENDERED] — traced to the actual frontend component/toast/dialog that displays it
- [BACKEND-DEFINED] — found in backend error constants or response formatting, but frontend rendering NOT verified. The actual displayed text may differ.

Example of correct documentation:
  "If they try to sign a field: Toast message — 'An error occurred while signing the field.' [RENDERED — traced to SigningFieldDialog error handler]"
  "Backend throws RECIPIENT_EXPIRED with message 'Recipient signing window has expired' [BACKEND-DEFINED — frontend does not surface this specific message, uses generic error handler instead]"

Example of INCORRECT documentation (the hallucination pattern to avoid):
  "User sees: 'Recipient signing window has expired'" — WRONG if this was only found in backend constants and not verified at the frontend rendering layer.

---

## Phase 4 — Generate Starter L2 Documents

### 4A. Rank and Select Flows

From the Flow Registry, rank flows by complexity:
- Number of steps in the happy path
- Number of branching paths and error states
- Number of roles involved
- Number of cross-module dependencies

Select the **top 5-8 flows** for L2 generation.

### 4B. Generate L2 Flow Documents

Create directory `.product-oracle/flows/` if it does not exist.

For each selected flow, create `.product-oracle/flows/{slug}.md` using this template:

```markdown
# {Flow Name}

**Trigger:** {What starts this flow — exact button text, URL, event, schedule}
**Actors:** {Which roles participate}
**Preconditions:** {What must be true before this flow can start}

## Happy Path

1. {Step description — what the user does and what they see}
   - Screen: {screen name or URL pattern}
   - Inputs: {what the user provides}
   - System response: {what happens, what the user sees}

2. {Next step...}

<!-- Continue for all steps. Use exact UI text in quotes where found.
     Example: User clicks "Send Document" button. -->

## Branching Paths

### {Branch name — e.g., "Recipient Declines"}
- Condition: {what triggers this branch}
- Steps: {abbreviated step list}
- Outcome: {what the user sees at the end}

## Error States

| Error | Trigger | User Sees | Recovery |
|-------|---------|-----------|----------|
| {name} | {what causes it} | {exact message or description} | {what the user can do} |

## Side Effects

- {Email sent to X when Y happens}
- {Webhook fired with event Z}
- {Audit log entry created}

## Access Control

| Action | Allowed Roles | Denied Behavior |
|--------|---------------|-----------------|
| {action} | {roles} | {what happens if unauthorized user tries} |

## Related Flows

- [{Related flow name}](./{related-slug}.md)

## Source References

- {List key source files that implement this flow, as paths from project root}
```

### 4C. Generate Global Documents

Create directory `.product-oracle/globals/` if it does not exist.

Generate **2-3 global docs** from this list (pick whichever are most relevant to the project):

1. **`.product-oracle/globals/access-control.md`** — Complete role-permission matrix,
   auth methods, session behavior, account recovery.

2. **`.product-oracle/globals/error-handling.md`** — Full error code catalog,
   error presentation patterns, retry behavior, fallback states.

3. **`.product-oracle/globals/notifications.md`** — Every email, push notification,
   webhook, and in-app notification with trigger, recipient, content summary.

4. **`.product-oracle/globals/billing-and-plans.md`** — Plan tiers, feature gating,
   quota limits, upgrade/downgrade behavior. (Only if billing is detected.)

5. **`.product-oracle/globals/configuration.md`** — Feature flags, environment toggles,
   and their user-visible effects.

Use the same PM-readable voice. Include exact values found in code (plan names, flag names,
error codes, email subjects).

### 4D. Initialize Staleness Tracking

Create `.product-oracle/.staleness.json` with this structure:

```json
{
  "version": 1,
  "generated": "{ISO 8601 timestamp}",
  "documents": {
    ".product-oracle/product-map.md": {
      "generated": "{ISO 8601 timestamp}",
      "sourceFiles": [
        "{path to key source file 1}",
        "{path to key source file 2}"
      ]
    },
    ".product-oracle/flows/{slug}.md": {
      "generated": "{ISO 8601 timestamp}",
      "sourceFiles": [
        "{paths to source files that implement this flow}"
      ]
    }
  }
}
```

For each document, list the **3-10 most important source files** that were used to generate it.
These are the files that, if changed, would make the document stale.

### 4E. Initialize Eval Log

Create `.product-oracle/.eval-log.jsonl` as an empty file.

### 4F. Print Summary

After all files are written, print:

```
=== Oracle Init Complete ===

Application type: {archetype(s)}
Tech stack: {language, framework, key deps}

Generated:
  - .product-oracle/product-map.md ({N} domains, {N} flows registered)
  - .product-oracle/flows/ ({N} L2 flow docs)
  - .product-oracle/globals/ ({N} global docs)
  - .product-oracle/.staleness.json (tracking {N} source files)
  - .product-oracle/.eval-log.jsonl (empty, ready for evals)

Top flows documented:
  1. {flow name} — .product-oracle/flows/{slug}.md
  2. {flow name} — .product-oracle/flows/{slug}.md
  ...

Run /oracle-ask to query the product oracle.
```

---

## Adaptation Rules

- **Monorepo**: Run Phase 1 per sub-project. The L1 product map covers the whole repo
  with a "Sub-Projects" section. L2 docs reference which sub-project they belong to.

- **API-only (no UI)**: Replace "screen" language with "request/response" language.
  Flows describe API call sequences. "User sees" becomes "caller receives".

- **CLI**: Flows describe command invocations. "Screen" becomes "terminal output".
  Include exact command syntax and flag names.

- **Library/SDK**: Flows describe integration patterns. "User" means "developer consumer".
  Document public API surface instead of screens.

- **Multiple languages**: Adjust grep patterns to the language. Python uses `def`, `class`,
  `@app.route`. Go uses `func`, `http.HandleFunc`. Rust uses `fn`, `#[get]`.

---

## Quality Checklist

Before printing the summary, self-check:

- [ ] Product map is under 200 lines
- [ ] Every flow in the registry has a summary a PM could understand
- [ ] No developer jargon in any output file (no "middleware", "schema", "mutation", "handler")
- [ ] At least 3 specific checkable assertions per L2 flow doc (exact text, exact codes, exact formats)
- [ ] Error code index includes actual codes/messages found in code, not placeholders
- [ ] Feature flags list references actual flag names from the codebase
- [ ] Source References in L2 docs point to real files that exist
- [ ] `.staleness.json` references real source file paths
- [ ] All file paths in L2 doc inventory match actual generated files
