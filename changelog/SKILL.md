---
name: changelog
description: Generate a per-release changelog of backend API contract changes for FE developers (endpoints, request/response shapes, FE-visible enums, payloads, breaking changes) from the git diff between release tags, link each ticket to Jira and its [BE] Notion spec, then post it to Slack after the user approves the draft.
argument-hint: '<#slack-channel> [version | from..to]'
disable-model-invocation: true
---

# Changelog

Tell FE developers what a backend release changes **in the contract they build against**. The source of truth is the code diff between two releases, not ticket titles — a ticket can ship zero contract changes, and an "internal" ticket can quietly change a response.

## Inputs

Resolve each value; ask only for what cannot be found.

- **Slack channel** (required): the `#channel` argument. Missing → ask before drafting.
- **Range**
  - `from..to` argument (git range syntax, either side a tag or any ref) → use both as given.
  - Single `vX.Y.Z` / `X.Y.Z` / ref argument → that is `to`. No argument → tag `v<package.json version>`; if that tag does not exist yet, use `HEAD` and say so in the draft review.
  - `from` when not given: the previous tag, `git describe --tags --abbrev=0 <to>^`.
  - Run `git fetch --tags origin` first. Diffing tag to tag stays correct when release branches merge into each other.
- **Version label**: the title is always `[BE] v<X.Y.Z>`, taken from the `to` tag (or the `package.json` version when `to` is not a tag).

## Workflow

### 1. Collect the diff

```bash
git log --no-merges --format='%h %s' <from>..<to>
git diff --stat <from>..<to>
git diff <from>..<to> -- <API, schema, enum, payload paths>
```

Read the project's architecture notes first so you know where routes, request/response schemas, shared schemas, enums and push/deeplink payloads live. For Express + Joi projects that is typically router `index.ts` files, the `requestSchema` / `responseSchema` exports of each handler, shared schema modules and the enums file.

### 2. Find contract changes

Report a change only when a client can observe it:

- **Endpoints**: added, removed, renamed paths or methods; changed auth or permission requirements.
- **Request** (body, query, params, headers): fields added, removed or renamed; required ↔ optional; type, format, nullability, allowed values, limits, defaults.
- **Response**: the same, plus changed status codes and new error codes or messages the client can branch on.
- **Shared schemas**: trace every endpoint that uses a changed shared schema (search the imports) and report the change **on each endpoint**, not on the schema.
- **Enums**: only when the enum is (directly or through a shared schema) part of a request or response, push payload or deeplink. Then report the added or removed values on the affected endpoints. Enums used only internally are not mentioned.
- **Push notifications, deeplinks, emailed links pointing to FE routes**: added or removed types, changed payload fields, new or changed URL shapes.
- **Behaviour with the same schema**: new pagination or sorting defaults, filter semantics, `404` instead of an empty list, and similar. One short line describing the observable difference.

Skip everything else: refactors, logging, monitoring, DB, CRM/third-party internals, tests, tooling, renamed internals with an identical wire shape, and server-side side effects the client does not handle — a notification, email or in-app item now sent on another trigger, or server-rendered copy changes. Push and deeplink changes count only when the client must parse or route something new.

If a handler is mounted under several surfaces (for example mobile and web), list every exposed path in one bullet.

**Breaking** = an existing client request can now fail, or an existing client can misread a response: removed or renamed field, endpoint or enum value; optional → required in a request; required → optional or nullable in a response; type change; narrowed allowed values; stricter auth.

### 3. Attribute to tickets

- Map each change to its commits: `git log --no-merges --format='%h %s' <from>..<to> -- <file>`, and read the ticket key from the commit subject (`ABC-123: …`).
- Fetch summaries, issue types and descriptions in one Jira query (Atlassian MCP, `key in (…)`). If Jira is unavailable, fall back to the commit subjects.
- Block title = the Jira summary translated to short English, without bracket prefixes like `[BE]`.
- Changes without a ticket key go under an `Other` group.
- Tickets without contract changes are left out entirely.

### 4. Link specs

The spec link lives on the ticket from the commit subject itself — no parent or epic lookup.

1. Collect Notion URLs from the ticket's remote links ("Link web page", Atlassian MCP) and its description.
2. Fetch each candidate page (Notion MCP) and keep the one whose title starts with `[BE]`. Several `[BE]` pages → link all of them.
3. Ticket without a `[BE]` link → leave the spec line out and list the ticket in the draft review, so the link can be added. Never link a non-`[BE]` page or a search guess.

### 5. Draft

Slack mrkdwn — `*bold*`, `<url|text>` links, backticks for paths and fields. English.

```
*[BE] v0.0.1*

🆕 *<https://jira/browse/ACLD-1016|ACLD-1016> – Transaction filters*
  • `GET /api/mobile/v1/transactions/filters` – new endpoint
  • `GET /api/mobile/v1/transactions` – new query param `productType` (optional, values `FUND`, `BOND`)
  📄 Spec: <https://notion/...|[BE] Transactions>

🐛 *<https://jira/browse/ACLD-1020|ACLD-1020> – Fix investor detail*
  • `GET /api/mobile/v1/investor` – `phone` is now `null` when missing (was empty string) ⚠️

⚠️ Breaking:
  • `GET /api/mobile/v1/investor` – `phone` nullable
```

- One block per ticket. The emoji follows the contract change, not the Jira issue type: 🐛 Jira Bug; otherwise 🆕 when the ticket only adds endpoints, fields or values; otherwise 🔧. Order 🆕, 🔧, 🐛.
- One bullet per endpoint; combine several changes on the same endpoint into one bullet.
- Mark breaking bullets with ⚠️ and repeat them in the `⚠️ Breaking:` section at the end. No breaking changes → `⚠️ Breaking: none`.
- No release contract changes at all → say so to the user and do not post.
- No intro text, no "no FE impact" list, no footer.

### 6. Review, then post

1. Show the draft in chat, together with what you are unsure of (a change you could not classify, a missing tag, a ticket without a Jira match, a ticket without a `[BE]` spec link).
2. Ask: post / edit / cancel. **Never post without explicit approval** of the final text.
3. Post through the Slack MCP as the user: resolve the channel ID by name, send the approved text unchanged, and return the message permalink.

## Rules

- Every bullet must trace back to a concrete diff hunk. Re-read the hunk before writing a bullet; never infer a contract change from a ticket title.
- Use the wire names (JSON keys, query params, enum values) exactly as the client sees them.
- Never edit, commit or push anything in the repository.

## Usage Examples

- `/changelog #slack-channel` — current `package.json` version vs the previous tag
- `/changelog #slack-channel 0.7.1`
- `/changelog #slack-channel v0.6.7..v0.7.1`
