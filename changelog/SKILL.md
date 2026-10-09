---
name: changelog
description: Generate a per-release changelog of backend API contract changes for FE developers (endpoints, request/response shapes, FE-visible enums, payloads, breaking changes) from the git diff between release tags, link each ticket to Jira and its [BE] Notion spec, then post it to Slack after the user approves the draft — or return it for manual pasting when no channel is given.
argument-hint: '[#slack-channel] [version | from..to]'
disable-model-invocation: true
---

# Changelog

Tell FE developers what a backend release changes **in the contract they build against**. The code diff between two releases is the source of truth, not ticket titles: a ticket can ship zero contract changes, and an "internal" ticket can quietly change a response. The reader is a FE developer scanning Slack — every line should answer "do I need to change something?".

## Inputs

- **Slack channel** — the `#channel` argument. Without it the skill runs in draft-only mode: nothing is posted, the text is returned for manual pasting.
- **Range** — `from..to` as given; a single version or ref is `to`; nothing → the tag `v<package.json version>`, or `HEAD` when that tag does not exist yet (mention it in the review). A missing `from` is the previous tag (`git describe --tags --abbrev=0 <to>^`). Fetch tags first; diffing tag to tag stays correct even when release branches merge into each other.
- **Title** — `[BE] v<X.Y.Z>` from the `to` version.

## Workflow

### 1. Find contract changes

Read the project's architecture notes to learn where routes, request/response schemas, shared schemas, enums and push/deeplink payloads live, then read the diff of those paths.

Report a change only when a client can observe it:

- **Endpoints** — added, removed or renamed paths and methods; changed auth or permissions.
- **Request** (body, query, params, headers) — fields added, removed or renamed; required ↔ optional; type, format, nullability, allowed values, limits, defaults.
- **Response** — the same, plus status codes and error codes the client can branch on.
- **Shared schemas** — report the change on every endpoint that uses the schema, because FE thinks in endpoints, not in backend modules.
- **Enums** — only when they reach the wire (request, response, push payload, deeplink); report the changed values on the affected endpoints.
- **Push and deeplinks** — only when the client must parse or route something new.
- **Behaviour with the same schema** — e.g. new sorting or pagination defaults, different filter semantics, `404` instead of an empty list.

Leave out anything the client does not handle: refactors, logging, monitoring, DB, third-party internals, tests, tooling, internal renames with an identical wire shape, notifications or emails sent on a new trigger, and server-rendered copy.

**Breaking** means an existing client request can now fail, or an existing client can misread a response: a removed or renamed field, endpoint or enum value; optional → required in a request; required → optional or nullable in a response; a type change; narrowed allowed values; stricter auth.

### 2. Attribute to tickets and specs

- Map each change to its commits (`git log <from>..<to> -- <file>`) and read the ticket key from the commit subject (`ABC-123: …`). Changes without a key go under `Other`; tickets without contract changes are dropped.
- Fetch summaries, issue types and descriptions in one Jira query (Atlassian MCP). Without Jira, fall back to the commit subjects.
- The spec link lives on that same ticket: look for Notion URLs in its remote links and description, fetch them (Notion MCP), and keep the pages titled `[BE] …` — the prefix marks backend technical specs; other pages (business specs, change requests) are not what FE should build against. No `[BE]` page → no spec line; flag the ticket in the review so the link can be added.

### 3. Draft

Slack mrkdwn in English:

```
*[BE] v1.4.0*

🆕 *<https://jira/browse/ABC-101|ABC-101> – Order filters*
  • `GET /api/v1/orders/filters`, `GET /api/web/orders/filters` – new endpoint, returns `statuses[]`, `types[]`
  • `GET /api/v1/orders` – new query param `type` (optional, one or more `ORDER_TYPE` values)
  📄 Spec: <https://notion/...|[BE] Orders>

🔧 *<https://jira/browse/ABC-102|ABC-102> – Profile cleanup*
  • `GET /api/v1/profile` – removed `nickname` ⚠️

⚠️ Breaking:
  • `GET /api/v1/profile` – removed `nickname`
```

- One block per ticket; title = the Jira summary as short English, without bracket prefixes.
- Emoji reflects the contract change, not the Jira type: 🐛 for a Jira Bug, 🆕 when the ticket only adds, 🔧 otherwise. Order 🆕, 🔧, 🐛.
- One bullet per endpoint, merging all its changes; a handler exposed on several surfaces lists every path in the same bullet.
- Use wire names exactly as the client sees them.
- Breaking bullets get ⚠️ and are repeated in the closing `⚠️ Breaking:` section (`none` when there are none).
- Nothing else — no intro, no "no FE impact" list, no footer. If the release has no contract changes, tell the user instead of drafting.

### 4. Review and deliver

Show the draft in chat with anything uncertain: unclassified changes, a missing tag, tickets without a Jira match or `[BE]` spec link.

- **With a channel** — ask post / edit / cancel and post only the approved text, unchanged, through the Slack MCP as the user. A post is public and hard to take back, so explicit approval of the final wording is the gate. Return the permalink.
- **Draft-only** — the Slack composer does not render pasted mrkdwn, but it keeps formatting copied from a rendered web page. Write the final draft as HTML to `changelog-v<X.Y.Z>.html` in the session scratchpad (or the OS temp dir): `<meta charset="utf-8">` first, then `<b>` for bold, `<a href>` for links, `<code>` for paths and fields, `<ul><li>` for bullets, `<br>` between blocks. Open it in the browser (`open` / `xdg-open`) and tell the user to select all, copy, and paste into Slack. Return the file path as well.

## Rules

- Every bullet traces back to a concrete diff hunk — re-read it before writing; a ticket title is never evidence.
- The skill is read-only toward the repository: no edits, commits or pushes. The draft-only HTML file goes outside the repo.

## Usage

- `/changelog 1.4.0` — draft only
- `/changelog #slack-channel` — current `package.json` version vs the previous tag
- `/changelog #slack-channel v1.3.0..v1.4.0`
