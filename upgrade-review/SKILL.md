---
name: upgrade-review
description: Review proposed dependency upgrades from any source — Dependabot or Renovate PRs, npm/pnpm/yarn audit findings, an outdated check, or a manual list of packages. Validates changelogs and real breaking-change impact against the codebase, respects the project's configured minimum release age, applies safe upgrades with pinned exact versions and verifies them with the project's install, type-check, lint and test scripts. Never commits, pushes, merges or closes anything.
argument-hint: '<pr-url...> | <package...> | audit | outdated'
disable-model-invocation: true
---

# Upgrade Review

Decide for each proposed dependency upgrade: **safe to apply, or leave alone** — then apply the safe ones and prove they work. The bot (Dependabot, Renovate, …) is only a messenger; the unit of work is always "package X: current version → target version", regardless of where the proposal came from.

## Inputs

Accept any mix of:

- PR URLs from an upgrade bot (Dependabot, Renovate, or similar) — extract package + version bump via `gh pr view <url> --json title,body,files` and `gh pr diff <url>`.
- Audit output — run `npm audit --json` (or the detected package manager's equivalent) and focus on the advisories the user cares about (default: high + critical).
- A plain list of package names or "see what's outdated" — use `npm outdated` / equivalent.

If no input is given, ask whether to scan audit findings, outdated packages, or specific PRs.

## Workflow

### 1. Detect the environment

Identify the package manager from lockfiles (`package-lock.json` → npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun) and use it consistently. Never use a different one than the project does, and never run bare `npx` for project tasks — use the project's documented scripts.

### 2. Assess each upgrade independently

For every `package: current → target`:

- **Semver jump.** Patch/minor from a well-maintained package is usually low risk; a major always needs changelog evidence.
- **Changelog / release notes.** Read them for every version between current and target — `gh api repos/<owner>/<repo>/releases`, the package's `CHANGELOG.md`, or `npm view <pkg>` for repository links. Look specifically for: removed/renamed APIs, changed defaults, dropped Node/engine support, peer-dependency shifts, ESM/CJS packaging changes.
- **Real impact, not theoretical.** Grep the codebase for how the package is actually used. A breaking change in an API the project never touches is not a blocker — but say so explicitly in the verdict.
- **Minimum release age — resolve from project config, never assume.** The project may already define its policy; look for it before applying any default, in this order:
  - `.npmrc` / `pnpm-workspace.yaml` — `minimumReleaseAge` (pnpm, in minutes) or a `before=` date pin (npm)
  - `renovate.json` (or `renovate` key in `package.json`, `.github/renovate.json5`) — `minimumReleaseAge`
  - `.github/dependabot.yml` — `cooldown` settings
  - CI workflow files that pass a release-age flag to install/audit steps

  Use the first value found and state in the report which source it came from. If nothing is configured, **apply no age gate at all** — don't invent one. When a policy exists, check `npm view <pkg> time --json`: if the target version is younger than the configured age, mark it **wait** (not unsafe) and say when it becomes eligible. Why the age gate matters: freshly published versions are where supply-chain compromises and bad releases live; the quarantine window gives the ecosystem time to catch them.

- **Transitive effects.** Check whether the bump drags in new transitive majors or conflicts with peer deps.

### 3. Check existing overrides

Look at `overrides` / `resolutions` in `package.json`. For each one, decide whether the upgrade makes it obsolete — stale overrides hide future vulnerable versions and confuse audits. Flag removals; don't remove silently.

### 4. Verdict table — before touching anything

Present a table and pause here only if any verdict is ambiguous; otherwise continue.

| Package | Current → Target | Verdict | Reason |
|---|---|---|---|
| axios | 1.16.0 → 1.16.1 | ✅ safe | patch, fixes CVE-…, no API changes |
| chai | 4.x → 6.x | ❌ leave | drops CJS, project uses `require` in tests |
| nodemailer | 8.x → 9.0.1 | ⏳ wait | released 3 days ago, eligible <date> |

### 5. Apply the safe ones

- Pin **exact versions** (no `^`/`~`) in `package.json`, matching the project's existing pinning style.
- Regenerate the lockfile with the detected package manager.
- If an override became obsolete and the user agreed, remove it.

### 6. Verify

Run, via the project's documented scripts: install, type-check, lint, tests. All must pass. If something fails, either fix it as part of the upgrade (when trivial and clearly caused by the bump) or revert that single upgrade and downgrade its verdict — never leave the working tree broken.

### 7. Report

Final summary: what was applied, what was left and why, what to re-check later (wait verdicts), which bot PRs the user can now close.

## Hard boundaries

- **Never commit, push, merge, or close PRs.** The user reviews the working tree, commits manually, and closes bot PRs themselves. This is the contract — apply + verify, then stop.
- Never upgrade past what was asked. If the bot proposes 1.16.1, don't jump to 1.17.0 without flagging it as a separate suggestion.
- If audit demands a version that violates the minimum release age, present the conflict (security fix vs. release age) and let the user decide — don't resolve it silently.

## Other ecosystems

The same procedure applies outside Node (pip/uv, cargo, go modules, …): changelog evidence, real usage impact, minimum release age, exact pins where the ecosystem supports them, verify with the project's own checks, never commit.
