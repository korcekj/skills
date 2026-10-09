---
name: build-plan
description: Create or update a technical implementation plan (files/<feature>/<feature>-plan.md) for a feature, by first gathering every fact from JIRA, Notion and the codebase, then grilling the user round by round until no architectural, data-contract, failure-mode or security question is left unanswered. Writes the plan as decisions land; never implements.
argument-hint: '<feature-name> [JIRA keys | Notion links | project dir]'
disable-model-invocation: true
---

# Build Plan

Produce the document a backend engineer reads **before** writing a line of code: `files/<feature>/<feature>-plan.md`. It is a **design record**, not a mirror of the code. Code can always tell you *what* it does; the plan keeps what code cannot — the client's decisions, why each one beat the alternative, what was verified against real data, and what is still open and who owns it.

Two things make or break it:

1. **Every fact is yours to find.** The user should never be asked something a JIRA ticket, a Notion page, the repo or a live DEV record already answers. Asking them wastes the one resource the plan depends on — their attention for the questions only they can answer.
2. **Every corner gets visited before implementation starts.** A plan that reads well but leaves the concurrency story, the failure path or the PII exposure unexamined is worse than no plan: it grants false confidence. The grilling phase exists to make the unexamined branch impossible to miss.

**Scale to the change.** A new subsystem earns several rounds. A one-field contract fix gets one round, plus a single line naming the checklist domains that don't apply. Rigour means no unexamined branch, not ceremony proportional to the template.

## Inputs

The argument is a feature name, optionally with JIRA keys, Notion links, or a project directory. Resolve what is missing:

- **Project dir** — default to the current working directory. If the user named another project, work there.
- **Docs folder** — look for the project's actual convention (`files/`, `docs/`, `doc/`) before assuming, and mirror the existing layout: a folder per feature (`files/notifications/notifications-plan.md`) or a flat file (`files/notifications-plan.md`) — whichever the neighbours use.
- **Existing plan** — if one exists, this is an **update**, not a rewrite. Preserve the user's edits and the audit trail; a decision that changed moves to `## Resolved` with its date and reason, it is never silently overwritten. Grill only the new frontier.
  The plan's own structure wins over the template below. Do not restructure a working document to match a skeleton — add a missing section only when this change gives it something to hold (a first `## Sources` table when you have just gathered five links worth citing, yes; an empty `## Rollout` on a feature that shipped last month, no).

## Phase 1 — Research before asking anything

Gather in parallel, then state what you found in a few lines so the user can correct a wrong reading early.

**JIRA** (Atlassian MCP if available, otherwise ask for the ticket text): fetch every referenced key plus its subtasks and linked issues. Read the **comments**, not only the description — in practice the real decisions live there, often as a client's one-line answer that overrides the acceptance criteria above it. Note the comment id of anything decisive; the plan cites it.

**Notion** (Notion MCP if available): business specs, status/copy matrices, data dictionaries. These are the client's truth about behaviour; the repo is the truth about what exists.

**Prior design docs for the same problem.** If an earlier plan, sitemap or superseded design already solved a piece of this, it is the default — the team argued it once and FE may already be building against it. Departing from it is a decision like any other: it needs the reason, and it needs an `## Open` row for rewriting or retiring the old document, because two live designs for one mechanism is how the next person gets it wrong.

**Existing specs for the contract you change.** If an FE/client spec already documents the endpoint, payload or behaviour this change touches, updating it is a Rollout item in this plan. Otherwise the spec goes on describing the old contract.

**Design screenshots**, when given: map every visible element to the field or source that fills it, as a table in `## Context`. Gaps (a row with no source, a marker such as `~` with no flag behind it) become the scope. Fields returned but not displayed are worth a line too.

**The codebase**: the services, repositories, schemas, enums, jobs and routes the feature will touch or extend. What already exists decides half the plan — reuse-first means the plan must name the existing util, schema or job pattern the feature extends, not invent a parallel one. Read one or two neighbouring `*-plan.md` files too: they set the house style and often already answer a cross-cutting question.

**Live data**, when it is cheap and decisive: a DEV record from the integrated system, a table's actual contents, a real payload. A verified fact retires a whole question branch. Record what you probed and when — the plans carry these as dated verification notes because the next person cannot re-derive them.

**Fan the searching out.** Dispatch several search subagents in one turn — a typical split is one per area the feature touches (the flow it extends, the integration it talks to, the platform patterns and plan house style) — and keep only their conclusions. This is not just speed: the grilling needs the main thread's context for the design tree, and reading twenty files yourself spends it on material you will never quote.

## Phase 2 — Write the skeleton immediately

Before the first question, create the plan file with `## Context`, `## Sources` and empty `## Decisions` / `## Open` / `## Rollout` / `## Verification` sections. Two reasons: the user sees what you understood the feature to be and can correct the framing before answering twenty questions about the wrong thing, and nothing is lost if the session ends mid-grill.

Tell them the path in one line, then start round 1.

## Phase 3 — Grill, round by round

Map the feature as a **design tree**: each decision branches into the decisions that only exist once it is made. The **frontier** is the set of questions whose prerequisites are already settled — asking past the frontier produces answers that get invalidated by the round above.

**One round = the whole current frontier, asked at once.** Number the questions, and give each a **recommended answer with the reason and the fact it rests on**. A user who agrees can reply "1-6 yes, 7 no because…" in thirty seconds; a bare question list forces them to do your thinking. Then wait — do not answer your own questions and move on.

For each question make explicit:

- **Why it matters** — one clause. What breaks, or what stays unbuildable, if it is left open.
- **Your recommendation** and the alternative you rejected, with the reason. A decision recorded without its rejected alternative gets re-litigated in three months.
- **Who owns the answer** if it is not the user — the client, CRM, FE, Legal, product. That question leaves the frontier and enters `## Open` with an owner; it must not block the rest of the round. This applies only if the answer can change what we build. Another team's internal concern with no effect on our side, such as a static FE link, is not an Open item; leave it out.

Between rounds, write the answers into the plan (Phase 4) and re-derive the frontier: answers open new branches more often than they close them.

**Coverage.** A round is not done because you ran out of obvious questions. Walk `references/grill-checklist.md` for the domains that apply — data model and contracts, auth and authorization, concurrency and idempotency, caching and invalidation, failure and retry semantics, security and PII, i18n, observability and audit, migration and backfill, testing, dependencies and ownership. Skip a domain deliberately and say so in one line; a silent skip is the failure this skill exists to prevent.

**An assumption you write down is a question you owe.** If the plan says "invoices only, to confirm" or "assuming the EUR threshold applies to every currency", that caveat must appear in the round as a numbered question — otherwise it reads as settled to everyone but you, and gets inherited by the implementation. Either ask it, or record it as a decision with its reason. Prose hedging is the one place an unexamined branch can hide from a checklist.

**Push back.** If the user's answer conflicts with something you found — a ticket comment, the existing code, a neighbouring plan — say so plainly with the evidence and ask which wins. Finding the contradiction is the whole value of having read everything first. If they reaffirm, that is their call: record it as a decision with the trade-off named, and move on.

**Done** is when the frontier is empty: every branch visited, every remaining unknown sitting in `## Open` with an owner and a note on what it blocks. Say so explicitly and ask the user to confirm the shared understanding before the plan is called finished. If the user calls a halt earlier, honour it and record the unvisited branches in `## Open` rather than pretending they were settled.

## Phase 4 — Record decisions as they land

Append after each round, do not batch to the end.

A decision entry carries the choice, the reason, and what it costs. Three failure modes to avoid:

- **Restating the code.** "The service validates the payload" earns nothing. "Validation runs in the dispatch job and the *validated* value is what gets delivered, because coercion and defaults must reach the row as well as the sender" earns its place. The same test decides what survives in `## Shipped`.
- **Recording the choice without the trade-off.** Every real decision has a loser. Name it: the accepted race, the case that will fire twice, the staleness window, the thing that breaks the day a second product type exists.
- **Deleting superseded decisions.** They move to `## Resolved` with the date and what changed. The audit trail is why the plan beats a chat log.

Facts verified against real data get a date and a source (e.g. `checked against DEV <environment>, 7. 7. 2026`) — the reader cannot tell a probed fact from a guess otherwise.

## Plan structure

Mirror the project's existing plans; this is the shape they converge on.

````markdown
# <Feature> — Implementation Plan

> Design record for <feature>. Deliberately **not** a mirror of the code — <where the mechanics live>. This file keeps what code cannot tell you: decisions, why we chose them, what was verified against real data, and what is still open.

## Context

What the feature does, for whom, and the scope boundary — what is explicitly **not** in it. Name the existing stack it builds on.

Diagram the flow when it spans several components, and draw it in **mermaid** rather than an ASCII box sketch — it renders in the repo, in the PR and in Notion, and the spec built from this plan will want the same diagram. Keep it to the happy path plus at most one error branch, then validate it: no `(`, `)`, `+`, `;` or `:` inside message text after an arrow, one statement per line, `participant X as Label` when the label has spaces. Render with `mmdc` if it is available, otherwise re-read every arrow line against those rules — a diagram that fails to parse is worse than no diagram.

## Sources

| What | Link | Carries |
| --- | --- | --- |
| Business spec | [Notion — <title>](url) | status codes + copy |
| <KEY-1> | [KEY-1](url) | the umbrella ticket |
| <KEY-2> | [KEY-2](url) | detail attributes; decisive comment [#123456](url) |

## Decisions

| Topic | Decision |
| --- | --- |
| <Topic> | <The choice, the reason, and the rejected alternative in one or two sentences.> |

## Shipped

Once parts are implemented, record only what reads as arbitrary without the reason — the code is the reference for everything else. On each update this section should get **shorter**: a decision that has become visible in the code shrinks to its reason, or goes.

### <Subsystem deep dive>

Prose for anything a table row cannot hold: the ordering that matters, the race that is accepted, the field that is required even though it looks redundant. One section per subsystem that has non-obvious reasoning.

## Rollout (gated — each item is implemented, validated and reviewed before the next)

| # | Item | Done when | State |
| --- | --- | --- | --- |
| 1 | <Smallest shippable slice, in dependency order> | <The observable check that proves it> | ⬜ |

States: ⬜ pending · ✅ done · ⏸ skipped (say why) · 🗑️ dropped (say why).

`Done when` names something a reviewer can verify without asking you: a test that asserts the behaviour, a command that passes, a value visible in the data. "Works as described" is not a criterion.

Items are changes to the repo: code, tests, plans, specs. Communication (a ticket reply, a Slack ping) is the user's to send, so it never becomes a Rollout item.

## Open

| Item | Owner | Blocks |
| --- | --- | --- |
| <Question> | <client / CRM / FE / Legal / us> | <what it blocks, or "Nothing"> |

An item that blocks nothing still says so — "nothing" is information, it is what lets implementation start.

## Resolved (audit trail)

Decisions that changed, with the date, who decided, the link to where, and what code (if any) it moved.

## Verification

Type-check, lint and the suite. Then: what the automated tests cover, what they deliberately do **not**, and the manual checks worth doing by hand before calling it done.
````

## House style

- **English**, matching the project's plans. The client-facing document is a different artifact — that is `build-spec`, run after this.
- **Dense prose over bullet mush.** These plans read as argument, not as notes. A paragraph that explains why beats five bullets that assert.
- **Link everything**: JIRA keys as `[KEY-123](url)`, decisive comments by their focused-comment link, Notion pages by title.
- **Markdown only** — headings, tables, fenced blocks. Relative repo paths are fine here (unlike the spec, this document stays in the repo).
- **No secrets or credentials**, no client PII in examples.

## After the plan

Close by recommending `implement-plan` **in a fresh session**, and give the exact invocation with the plan path (`/implement-plan files/<feature>/<feature>-plan.md`). Do not offer to start implementing here ("Should I start item 1?"). There are three reasons:

- **The plan is the handoff.** A fresh session has only the plan to work from. If something is missing from it, the gap shows up immediately instead of being quietly filled from this conversation's memory.
- **Context budget.** This session is full of research dumps, ticket threads and alternatives you rejected. Implementation needs that space for code, test output and review rounds, and the rejected options shouldn't be sitting next to the code as it's written.
- **Gated rollout.** `implement-plan` runs one Rollout item at a time and stops for the user's review. Implementing at the end of a grilling session blurs those gates.

If the user explicitly asks to implement here anyway, that's their call. When the feature is implemented and stabilised, `build-spec` turns this plan into the FE/client spec.
