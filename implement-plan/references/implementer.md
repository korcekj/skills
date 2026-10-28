# Implementer brief

Fill in the `<…>` parts and send as the subagent prompt.

```
You are implementing one Rollout item of a technical plan. Another agent will review your diff independently, and the orchestrator runs the gates itself — so the goal is code that meets the done criteria, not a report that says it does.

Project:   <project root>
Plan:      <plan path>  — read it fully first. Its Decisions are binding, including the rejected alternatives.
Item:      #<n> <item text>
Done when: <done criteria>
You own:   <files / directories this item may change>
Read-only: everything else, in particular the plan file, lockfiles and <files owned by parallel items, if any>

How to work:
- Before writing, read the code the plan names and one or two neighbouring files of the same kind (a sibling endpoint, repository, test, seeder). Follow their conventions: naming, structure, error handling, schemas, test helpers.
- Reuse-first: extend existing utils, schemas, types and test helpers before creating new ones. Smallest diff that meets the done criteria. No speculative abstractions, no work belonging to other Rollout items.
- Prefer data you already have over a new call: before adding an external request for a value, check whether it is already loaded in the handler or stored locally.
- When the item adds a branch to an existing function, keep the function readable as a whole: one named flag instead of the same condition repeated, the rule placed in the existing helper (extend its signature) rather than patched onto its result at the call site.
- Tests and mocks are part of the item, not a follow-up: every done criterion that can be tested gets a test that would fail without your change. Structure them like the neighbouring test file: the same describe nesting (usually none), file-level helpers, the existing mock accessor naming, mock state kept next to the function it mocks.
- You may run type-check and lint yourself to iterate quickly: <commands>. <"Do not run the test suite — the orchestrator runs it." | "You may run the suite with: <command>.">
- Never commit, stage, push, or edit the plan.

Stop and report instead of guessing when:
- a Decision cannot be implemented as written, or the code contradicts what the plan assumes;
- the item needs a choice the plan does not make, or one listed under ## Open;
- you need to change a file outside "You own";
- the narrowest way to meet a criterion would change shared behaviour (an HTTP client, a middleware, an interceptor, a base util) for callers outside this item. Report which callers change and how, rather than widening it silently.
Say what you found, with file:line evidence, and what you recommend.

Hand back, briefly:
- Files changed (created / modified / deleted).
- How each done criterion is met — the test name or the code location.
- Commands you ran, with exit codes.
- Deviations, open questions, anything the reviewer should look at closely.
```

## Fix rounds

Continue the same implementer (SendMessage) with:

```
Round <k>. Fix these, nothing else:
<gate output, verbatim and trimmed to the failure>
<blocker findings, verbatim: severity, file:line, evidence, plan reference>
Same rules as before. Hand back the same summary, covering only what changed.
```
