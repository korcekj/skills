---
name: build-spec
description: Generate or update a client/FE-facing feature specification (files/<feature>-spec.md) from a technical plan file or the implemented code. Slovak language, no backend internals, endpoint contracts with request/response examples and error tables, syntax-validated mermaid diagrams, ready to paste into Notion.
argument-hint: '<feature-name | path/to/feature-plan.md>'
disable-model-invocation: true
---

# Build Spec

Turn a technical plan (`files/<feature>-plan.md`) or an implemented feature into a **spec the client and FE developers can read** — `files/<feature>-spec.md`. The plan is for backend engineers; the spec is the contract everyone else builds against. Everything in it must be observable from outside the backend.

## Inputs

- A feature name or a path to a plan file. Resolve the plan in the project's `files/` folder (or its equivalent docs folder).
- If a spec for the feature already exists, this is an **update**: sync it with what changed in the plan or implementation, and preserve the user's manual edits — diff mentally against what you would have generated, don't regenerate from scratch.
- If endpoints are already implemented, the code is the source of truth over the plan — verify routes, schemas and error codes against the actual routers/controllers before writing them into the spec.

## House style — read before writing

Before writing, open one or two existing `*-spec.md` files in the same project and mirror their structure, tone and level of detail. The example below shows the shape; the project's own specs always win on specifics.

**Language**: Slovak. Code, JSON, enum values, headers and endpoint paths stay in English.

**Audience**: FE developers and the client. That decides what goes in and what stays out:

Include:

- Short intro: what the feature does from the user's perspective.
- Numbered sections per flow/endpoint, each with a short "Postup" (how FE uses it, step by step).
- Full API contract per endpoint: method + path, required headers, request JSON example, response JSON example, relevant enums as small `tsx` blocks.
- Error table per endpoint (HTTP code, message meaning, cause).
- Mermaid sequence diagram where a flow spans multiple calls or actors — optional, only when it clarifies.

Exclude — this is the most common failure mode:

- DB models, migrations, indexes, table names.
- Repository/service/internal function names, middleware order, JWT payload internals.
- PR numbers, commit references, implementation phases, open questions from the plan.
- Concurrency/caching internals — unless FE must handle a visible consequence (e.g. "list is cached for 5 minutes, changes may appear with a delay" belongs in; "Redis key shape" does not).

**Destination**: the file gets pasted into Notion. Plain markdown only — headings, tables, fenced code blocks, `---` separators. No HTML, no relative links to repo files.

## Mermaid — validate before delivering

Mermaid parse errors are the #1 rework cause for these specs. Sequence diagrams break on innocent-looking message text. Before handing over a diagram:

- No `+`, `(`, `)`, `;`, `:` inside message text after the arrow — rephrase ("pri zlom PIN inkrementuje attempts", not "attempts +1; vráti 422").
- One statement per line; no line breaks inside a message.
- Participant aliases via `participant X as Label` when the label has spaces.
- Keep diagrams small: happy path + at most one error branch. Detail lives in the error tables.

Then verify: if `mmdc` (mermaid-cli) is available, render the block to confirm it parses. Otherwise re-read the diagram line by line against the rules above — every arrow line must be exactly `A->>B: plain text`.

## Example skeleton (concise)

````markdown
# Technická špecifikácia

Krátky odsek: čo funkcia robí z pohľadu používateľa a čo sa mení oproti súčasnému stavu.

## 1. <Prvý flow, napr. Registrácia zariadenia>

Kedy a prečo FE tento endpoint volá. Poznámky k idempotencii alebo platnosti tokenov, ak sú pre FE relevantné.

### Postup

1. Aplikácia vygeneruje `deviceID`.
2. Po úspešnom prihlásení volá tento endpoint.

### API: `POST /auth/device/register`

**Headers:**

```bash
Authorization: Bearer <accessToken>
x-device-id: <deviceID>
```

**Request:**

```json
{ "platform": "IOS", "model": "iPhone 15 Pro" }
```

**Platform:**

```tsx
enum USER_DEVICE_PLATFORM {
  IOS = 'IOS',
  ANDROID = 'ANDROID',
}
```

**Response:**

```json
{ "messages": [{ "message": "...", "type": "SUCCESS" }] }
```

**Errors:**

| HTTP | Správa                  | Príčina                   |
| ---- | ----------------------- | ------------------------- |
| 400  | Validačná chyba         | Nesprávne telo požiadavky |
| 401  | Neoprávnený prístup     | Neplatný `accessToken`    |
| 429  | Príliš veľa požiadaviek | Prekročený limit          |

---

## 2. <Ďalší flow>

...

## Súvisiace endpointy

Odkazy na existujúce endpointy, ktoré flow využíva, len menom a cestou.
````

## Final check

Re-read the finished spec as the FE developer: can they build the screens with only this document and the existing specs? If any step forces them to ask "and what does the backend do here?", either the answer belongs in the spec (add it) or it doesn't concern them (cut the sentence that raised the question).
