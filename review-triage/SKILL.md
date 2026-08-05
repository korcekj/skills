---
name: review-triage
description: Evaluate a code review produced by another AI agent or bot (pasted findings, a PR review, a report file). Verifies every finding against the real code, separates real issues from false positives, out-of-scope and by-design items, then applies only the fixes the user approves and verifies them. Never commits, pushes or resolves review comments.
argument-hint: '[paste the findings, or a PR URL / file path]'
disable-model-invocation: true
---

# Review Triage

Another agent reviewed the code and produced a list of findings. The job is to decide, **per finding**, whether it is real — with evidence from the actual code, not from the reviewer's prose — and then fix only what is worth fixing.

The reviewer is a messenger, not an authority. Its findings are claims to verify, not tasks to execute.

## Inputs

Accept any of:

- Findings pasted directly into the prompt (the usual case).
- A PR URL — pull the review comments (`gh pr view <url> --comments`, `gh api repos/{owner}/{repo}/pulls/{n}/comments`).
- A path to a report file.

Pasted findings are frequently **garbled**: items duplicated, numbering skipped or restarted, text truncated mid-sentence, code snippets mangled by copy-paste (backticks eaten, `person.mobilephone` collapsed to `person.mobile??`). Before triaging:

- Normalise into one numbered list, keeping the reviewer's own index and severity label (`1.`, `🟡`, `[P2]`, `Low`, `Nit`) so the user can map verdicts back to what they pasted.
- Deduplicate repeated items; say which were duplicates.
- Where text is truncated, reconstruct the intent from the cited `file:line` — and if the intent stays unclear, ask instead of guessing.

## Workflow

### 1. Verify every finding against the code

Non-negotiable, for each finding, before forming any verdict:

- Open the cited `file:line`. **Never trust the reviewer's quoted snippet** — reviewers quote stale code, already-fixed code, or code that never existed. If the quote disagrees with the file, the file wins; say so in the verdict.
- Trace the actual failure path the reviewer describes. A finding survives only if you can name the concrete inputs/state that produce the wrong behaviour.
- Check whether the surrounding code already guards it. A "silent failure" that already logs and audits above the cited line is a false positive.
- If the finding is about a change made in this session or branch, diff it (`git diff`, `git log -p`) — regressions and "this PR moved X" claims are settled by the diff.
- Check the project's own precedent before calling something a bug: an existing function that already handles the same condition a certain way is the answer, and consistency with it usually beats the reviewer's suggestion.

### 2. Classify

Group findings under these headings — a finding lands in exactly one:

- **Real — worth fixing.** Verified, with a nameable failure, and cheap enough relative to the risk.
- **Real but trivial.** True, but a style/nit-level payoff. Still list it; the user often takes these.
- **By design / already handled.** True observation, wrong conclusion — the behaviour is a deliberate trade-off, or already covered elsewhere. Name the decision or the covering code.
- **False positive.** The premise is wrong. State exactly which premise and what the code actually does.
- **Out of scope.** Real, but pre-existing or unrelated to the current change. Flag it, never fix it silently in the same diff — offer it as a separate follow-up.

### 3. Present verdicts and stop

Report **before touching any code**. Per finding: the reviewer's index, the `file:line`, the verdict, and the evidence that justifies it in one or two sentences. Be blunt about severity — do not upgrade a nit into a bug to look thorough, and do not soften a real bug.

Where a real finding has more than one sane fix, present the options (A / B / C) with the cost of each and a recommendation — do not pick silently. When the right call depends on product intent, external-system behaviour, or a colleague's decision, **ask instead of guessing**.

End with an explicit ask, e.g.: *"Which for #1 — A, B or C? #2, #4, #5 I'd just do."* Wait for approval. The user decides what gets implemented; that is the point of the whole exercise.

### 4. Apply only what was approved

- Smallest diff that resolves the finding. Follow the surrounding conventions; reuse existing utils/schemas/helpers before adding new ones.
- Adopt the reviewer's *fix* only when it is genuinely the best one — their snippets carry typos and often ignore project patterns. Rewrite as needed.
- Update tests and mocks as part of the change. When a finding is "untested path", the fix is the test.
- Do not drag in adjacent improvements that were not approved.

### 5. Verify

Run the project's own type-check, lint and test scripts (see the `node-backend-checks` and `node-backend-testing` skills for Node/TypeScript backends). All must pass. If a fix cannot be made to pass, revert that one fix and say so — never leave the tree broken.

### 6. Report

- What was applied, per finding number, and what the change actually does.
- What was **not** applied and why (rejected, out of scope, user skipped).
- Validation result: type-check, lint, tests (with the passing count).
- Anything left for the user: uncommitted files, a follow-up ticket worth opening, a question for a colleague, PR description that now needs updating.

## Hard boundaries

- **Never commit, push, merge, or resolve/close review comments.** Apply and verify, then stop — the user reviews the working tree and commits manually.
- **Never implement before approval**, even for findings that look obviously correct.
- Never claim a finding is verified without having opened the file.
- Do not defer to the reviewer out of politeness. "Both are plausible" is not a verdict; pick one and justify it.
