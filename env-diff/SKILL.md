---
name: env-diff
description: Checklist of the ENV variable changes a backend release needs in the real deployed environments — added, removed and renamed variables plus requiredness, validation and default changes — from the env validation schema diff between release tags (default) or release/vX.Y.Z branches, split per schema (server, scheduler, …) and attributed to ticket keys. Read-only, chat output.
argument-hint: '[--tags | --releases] [version | from..to]'
disable-model-invocation: true
---

# Env diff

Tell the user exactly what to change in the deployed environments (Azure / AWS / Vault / pipeline variables) before a release goes out. The env validation schema is the source of truth: the app refuses to boot when a variable it requires is missing or invalid, so every schema change is a potential failed deploy. The reader acts on the list item by item — each line should answer "what do I set, change or delete, and in which service?".

## Inputs

- **Mode** — `--tags` (default) or `--releases`. A range written with `release/` refs implies `--releases`.
- **Range** — `from..to` as given; a single version or ref is `to`. Run `git fetch origin --tags` first, then resolve the rest by mode:
  - **tags** — a version means the tag `v<X.Y.Z>`. Nothing → the tag `v<package.json version>`, or `HEAD` when that tag does not exist yet (say so). A missing `from` is the previous tag (`git describe --tags --abbrev=0 <to>^`). Diff tag to tag (`git diff <from> <to>`).
  - **releases** — compares `release/vX.Y.Z` branches, for a release that is not tagged yet. A version means `origin/release/v<X.Y.Z>`, falling back to the local branch. Nothing → the current branch when it is a `release/v*` branch, else `release/v<package.json version>`. A missing `from` is the highest `release/v*` branch below `to` by semver (`git branch -a --list '*release/v*'`, dedupe local/remote, ignore suffixed experiment branches like `release/v0.2.0-foo`). Diff with three dots (`git diff <from>...<to>`) so the older branch's unmerged fixes do not show up as reverts. Use `<from>..<to>` for `git log` attribution.

## Workflow

### 1. Locate the schema

GoodRequest projects keep it in `scripts/envValidation/` (`envValidationSchemas.ts`, `envSchemas.ts`, …) next to an `envValidation.ts` runner. If that folder is missing, look for what the boot/validation script imports: a Joi/zod/envalid object whose keys are `UPPER_SNAKE` env names. Check that the file exists at both refs; when it moved, diff with `-M` and compare the old path at `from` with the new path at `to`.

Map each exported schema to the service that runs with it — the `envValidationSchemas` array or the runner's `switch` names them (`server`, `scheduler`, …). These are deployed as separate containers with separate env config, so group the output per service.

### 2. Read the change

`git diff <range> -- <schema files>`. The hunk header (`@@ … export const envServerSchema = Joi.object({`) tells which schema a hunk belongs to; when a hunk spans or is ambiguous, read the file at both refs (`git show <ref>:<path>`) and compare the key sets per schema. A key moved within the same schema is not a change.

Report, per service:

- **Added** — a new key. State whether it is required, and when: "always", "in production" (a `productionRequired`-style helper or `.when('NODE_ENV', …)` switch), or optional. Include the description and the expected format (uri, email, number range, allowed values, cron pattern).
- **Removed** — the key is gone; the variable can be deleted from the environment after the release is live.
- **Renamed** — a removal and an addition in the same commit with the same meaning (matching description, name differs by a word or prefix). Also report merges and splits (e.g. five `X_*` secrets replaced by one `X`). Renames are inferred, so say so; the action is "set the new name with the old value, delete the old one after the release".
- **Requiredness** — optional ↔ required, or a change in which `NODE_ENV` makes it required.
- **Validation** — type, `.valid(...)` values, uri/email/pattern, min/max, `.empty('')` handling. Say whether the currently deployed value could now fail.
- **Default** — `.default(...)` added, removed or changed; matters for environments where the variable is unset.

Resolve indirection so the user does not have to: when allowed values come from an enum (`.valid(...SERVICES)`) or a pattern from a shared regex, read it at `to` and list the values. When a shared helper (`StringProductionRequired`, `productionRequired()`) changes, every key using it changes — list them.

Ignore what does not touch a deployed environment: description-only edits, comments, reordering, import changes, and changes to the runner script unless they change which schema a service validates against.

### 3. Attribute to tickets

`git log --format='%h %s' <from>..<to> -- <schema files>`, then `git log -S<KEY>` for any change that log does not settle. Take the ticket key from the subject (`ABC-123: …`); no key → the short hash.

### 4. Report

Markdown in chat, in English:

```
## Env changes v1.5.1 → v2.0.0

### server
➕ Add
- [ ] **`SAMSUNG_API_URL` — required in production**, uri — Base URL of the Samsung Wallet Server API (PAS-175)
- [ ] `REGION` — optional, one of `eu-central-1`, `eu-west-1` — Deployment region identifier (PAS-31)
✏️ Rename
- [ ] **`DIGISIGN_WEBHOOK_SECRET_*` (5 vars) → `DIGISIGN_WEBHOOK_SECRET` — required in production**; inferred from matching descriptions (ACLD-12)
🔧 Change
- [ ] **`SMTP_PORT` — optional → required in production** (ACLD-9)
➖ Remove (after deploy)
- [ ] `DB_DISABLE_MIGRATIONS` (PAS-120)

### scheduler
➕ Add
- [ ] `REGION` — optional, one of `eu-central-1`, `eu-west-1` (PAS-31)
```

- Section order per service: Add, Rename, Change, Remove — the order the user applies them in (removals wait until the new version is live, so a rollback still boots).
- Within each section, list the required variables first (always, then in production) and bold the name plus the requiredness — they are the ones that break the boot if missed, so they must stand out at a glance. Optional ones follow in plain text.
- Omit empty sections and services without changes.
- The list is the whole output — no notes, summaries, deploy-blocker counts or "what I checked" sections. The validation runner already reports missing variables on deploy; the user needs the checklist, not commentary. Uncertainty goes inline on the affected line (e.g. "inferred from matching descriptions"), and only two things justify a one-line remark below the list: `HEAD` used because the tag does not exist yet, or a schema file you had to guess.
- No changes at all → reply with one line: `No ENV changes v0.7.2 → v0.8.0.`

## Rules

- Every line traces back to a concrete diff hunk — re-read it before writing.
- Never print values from `.env` files or secrets; this skill lists names and requirements only.
- Read-only toward the repository: no edits, commits or pushes.

## Usage

- `/env-diff` — current `package.json` version tag vs the previous tag
- `/env-diff 2.0.0` — `v2.0.0` vs the previous tag
- `/env-diff v1.4.3..v2.0.0`
- `/env-diff --releases` — current `release/v*` branch vs the previous release branch
- `/env-diff release/v0.7.2..release/v0.8.0` — releases mode, implied by the refs
