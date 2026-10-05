---
name: implement-plan
description: Implement the Rollout items of a technical plan (files/<feature>/<feature>-plan.md, as written by build-plan) through subagents — an implementer per item, the project's gates run by the orchestrator, an independent read-only reviewer checking the diff against the plan's Decisions and the item's "Done when", and a capped fix loop until it passes. Ends with a smoke run of the app. Never commits.
argument-hint: '<plan path> [item | from-to | all] [--step]'
disable-model-invocation: true
---

# Implement Plan

Take a plan that `build-plan` finished and turn its `## Rollout` into working, validated code — one item at a time, each one through the same loop: **implement → gates → independent review → fix**, until the item meets its "Done when" or the loop gives up with evidence.

You are the **orchestrator**. You do not write the feature code yourself; you schedule items, brief subagents, run the gates, judge the evidence and keep the plan's state honest. Two reasons: the implementer's context fills with file reads you don't need, and you are the one who must be able to say *why* an item is done — which you can only do if you ran the checks yourself instead of trusting a subagent's "tests pass".

Three rules carry the whole skill:

1. **The plan is the contract.** Its `## Decisions` are settled; an implementer who finds one unworkable stops and reports — it does not quietly choose something else. Items in `## Open` are not the implementer's to decide either.
2. **Evidence or it didn't happen.** A gate is PASS only if you ran the command and saw exit code 0. Skipped, unavailable or BLOCKED is never PASS, and is reported as such.
3. **A review is valid only for the code it saw.** Any edit after an approval means the gates and the review run again on the new snapshot.

Never commit, push, stage, or open a PR. The user reviews the diff and commits.

## Inputs

- **Plan path** — required. Read the whole plan, not only the Rollout: the implementer brief is built from Context, Decisions, the deep-dive sections and Verification.
- **Items** — `3`, `2-4` or `all` (default: every ⬜ item, in table order). The user usually passes one number.
- **`--step`** — stop after each item for the user's review instead of continuing to the next.

Skip, and report, any item whose state is not ⬜, and any item with a human owner (e.g. `⬜ owner: Ján` for a manual reseed) — those are not code work.

## Phase 0 — Preflight

Do these in one go and report the result in a few lines:

- **Done criteria per item.** Use the Rollout's `Done when` column. If the plan has none (older plans), derive it from the Decisions and the `## Verification` section that bear on the item, and show the derived criteria to the user before starting — a criterion you invented is an assumption, and the user should get one chance to correct it.
- **Blockers.** An `## Open` row whose *Blocks* column names a selected item stops that item. Say so, skip it, continue with the rest.
- **Gates.** Discover the project's real commands — `package.json` scripts, the README, compose services (`dev_test` for tests, `dev` for the app). Prefer the `node-backend-checks` and `node-backend-testing` skills when the project matches them. Do not invent bare `npx` commands.
- **Baseline.** Run `scripts/snapshot.sh` (from this skill's directory) in the project root and keep the hash. It is a tree hash of the whole working tree, untracked files included, made without touching the user's index — so `git diff <before> <after>` shows exactly what an item changed even when the tree was dirty when you started. Tell the user if it was dirty.

## Phase 1 — Schedule

For each selected item, read enough to predict which files it touches (the plan usually names them). Items run **in parallel** only when they are independent in the Rollout order *and* touch no shared file — lockfiles, migrations, shared enums/constants, seeders, shared test helpers and the plan itself count as shared. Everything else runs in sequence. Most rollouts are dependency-ordered, so sequential is the normal case; parallelism is a bonus, not a goal.

Parallel implementers share one working tree, so each gets an explicit list of files it owns, and none of them runs the test suite — the suite usually needs a single shared test database, and you run it after the batch.

State the schedule in one or two lines and start. No confirmation needed unless you derived done-criteria above.

## Phase 2 — The loop, per item

```
snapshot S0
  → implementer (references/implementer.md)
  → gates: type-check, lint, tests          ← you run them
  → snapshot S1, reviewer on diff S0..S1 (references/reviewer.md)
  → blockers or gate failures? → back to the implementer with the evidence, repeat
```

**Implement.** Spawn a `general-purpose` subagent with the brief from `references/implementer.md`, filled in. Give it the plan path and let it read the plan itself rather than pasting excerpts — paraphrased decisions lose the reasons that make them binding.

**Gates.** Run them yourself, in order: type-check, lint, then the test suite. Record each as `command → exit code → PASS/FAIL/BLOCKED`. When a test fails, read the failure against the diff: a failure in code the item never touched is likely pre-existing — confirm it against the baseline where cheap, record it, and do not make the implementer chase it.

**Review.** Take snapshot S1 and spawn a fresh `general-purpose` subagent with the brief from `references/reviewer.md`. It is read-only and has not seen the implementer's reasoning, which is the point: it judges the diff against the plan and the done criteria, not against the implementer's story. Its verdict is `approved` or `changes-required`, with findings that carry severity, file:line, evidence and the plan reference.

**Fix.** Gate failures and `blocker` findings go back to the **same** implementer (SendMessage, so it keeps its context) with the exact output and findings — not your summary of them. Before forwarding a finding, sanity-check it against the code: a reviewer claim that is plainly wrong wastes a round. `minor` findings are not looped; they go into the final report for the user.

A round is: implementer pass → gates → review. **Cap: 3 fix rounds after the first pass.** If the item still is not clean, stop it: leave it ⬜, report the last gate output and open findings, and skip any later item that depends on it. Independent items continue. A loop that is not converging after three rounds is telling you the plan or the item is wrong, and more rounds only spend tokens hiding that.

**Approval is tied to a snapshot.** After the reviewer approves, run `scripts/snapshot.sh` again. If the hash differs from the one the reviewer saw (you, the implementer or a formatter changed something), re-run the gates and get a re-review of the new diff before calling the item done.

**Deviation from the plan.** If the implementer reports that a Decision cannot be implemented as written, or that something the plan never decided must be decided, stop that item and ask the user — with the implementer's evidence and your recommendation. If the user approves a change, update the Decisions row and add a dated entry to `## Resolved (audit trail)` in the plan's own style, then resume.

**Done.** Gates PASS on the final snapshot, reviewer approved that snapshot, no open blockers → mark the item ✅ in the Rollout table. Touch nothing else in the plan (`## Shipped` is the user's call). With `--step`, stop here and report; otherwise continue with the next item.

## Phase 3 — Smoke run the app

After the last item, if any item changed code, start the application once and see that it actually boots. Tests run the app in-process against a test DB; this catches what they do not — startup wiring, config, migrations and seeders on the dev database, a route that throws at registration.

1. Check `docker compose ps`. If the dev service is already running, ask before restarting it — the user may be working against it.
2. `docker compose up -d <dev service>` (usually `dev`; its dependencies come up with it). Wait for it to report ready — a healthcheck, a "listening on" log line — with a timeout of a few minutes. A container that exits or keeps restarting is a FAIL.
3. Read `docker compose logs <dev service>` from this start: errors, unhandled rejections, failed migrations/seeders, deprecation warnings that were not there before, connection retries. Judge what is unusual; quote it.
4. Probe cheaply, no credentials needed: a health endpoint if the project has one (search the routes), and each **new or changed route without auth** — a `401`/`403` proves the route is wired and the auth middleware runs; a `500` or `404` is a finding.
5. Stop only what you started (`docker compose stop <services>`). Never `down -v` — that deletes the dev database.

A smoke failure is reported with the log excerpt. If it is clearly caused by an item, that item goes back through one fix round; otherwise report it and let the user decide.

## Final report

Concise, one block per item, then the smoke result:

```
#2 SETTINGS_KEY + types + seeders — ✅ (2 rounds)
  gates   npm run type-check → 0 PASS · npm run lint → 0 PASS · docker compose up dev_test → 0 PASS
  review  approved @ <snapshot>; round 1 blocker: seeder test env missing `pl` (fixed)
  minor   src/types/settings.ts:14 — interface could reuse ISupportContact (left as is)
  files   src/constants/settings.ts, src/types/settings.ts, src/db/seeders/202603301200-settings.ts

#3 get.contacts response — ⬜ stopped after 3 rounds
  open    <blocker, file:line, evidence>
  last    <failing gate output, trimmed>

smoke   dev up in 18 s · logs clean · /health → 200 · GET /api/web/investor/contacts → 401 PASS
```

End with what is left for the user: review the diff (`git diff <baseline>` covers it all), anything BLOCKED or pre-existing, and the next ⬜ item.
