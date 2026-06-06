---
name: node-backend-checks
description: Use when the agent has edited TypeScript code, or when the user says "lint", "type-check", "check types", "tsc", "eslint", "run checks", or "before commit/push". Runs the project's documented lint and type-check scripts via the detected package manager (npm/pnpm/yarn/bun); never bare `npx`. Skips when no `tsconfig.json` or eslint config is present.
---

# Node Backend Checks

Use this skill to run lint and type-check gates on a Node.js/TypeScript project without inventing commands. Acts as a small guardrail so the agent does not fall back to bare `npx tsc` or `npx eslint .` when the project already ships documented scripts.

## When to Run

Run after any code edit that could change types or lint output:

- A TypeScript source file was modified, added, or deleted
- The user asks to "lint", "type-check", "check types", "verify", or run gates "before commit / push"
- A change is about to be committed and the project documents these scripts

If the project has no TypeScript or no linter configured, see [Skip Rules](#skip-rules) and emit a single line saying which gate was skipped and why — do not stay silent.

## Discovery First

Before running anything, locate the documented commands by scanning project docs and `package.json`:

1. Read project documentation for documented `lint` / `type-check` invocations. Check the first one that exists:
   - `CLAUDE.md`
   - `AGENTS.md`
   - `README.md`
2. Read `package.json` `scripts` and look for entries named:
   - Lint — `lint`, `lint:fix`
   - Type-check — `type-check`, `typecheck`, `tsc`, `check-types`, `types`
3. Use the exact script names found. Do not rename, alias, or invent flags.

## Package Manager Detection

Pick the package manager by checking, in order:

1. `packageManager` field in `package.json` (e.g. `"packageManager": "pnpm@9.0.0"`)
2. Lockfile presence at the project root:
   - `pnpm-lock.yaml` → `pnpm`
   - `yarn.lock` → `yarn`
   - `bun.lockb` → `bun`
   - `package-lock.json` → `npm`
3. Fallback: `npm`

Invoke scripts through the detected manager: `pnpm run lint`, `yarn lint`, `bun run lint`, or `npm run lint`. Keep this consistent across lint and type-check in the same run.

## Host Execution

Run all checks on the host directly. Do not route through Docker, devcontainers, or any other harness — even if the project documents one for tests. Lint and type-check are pure static analysis; they need only the local `node_modules` and produce identical output on host and container. Host execution is faster and avoids container startup overhead on every gate run.

If host execution fails because dependencies are not installed, surface that as the error (`run <pm> install first`); do not silently fall back to a containerized variant.

## Monorepo / Workspaces

If `package.json` has a `workspaces` field, or a `pnpm-workspace.yaml` exists at the root, the project is a monorepo. Gates may need to target a specific workspace:

- `npm run lint --workspace=<name>`
- `pnpm --filter <name> run lint`
- `yarn workspace <name> lint`

Default to the root-level script when one exists (it usually fans out to all workspaces). Only scope to a single workspace when the edit touched only that workspace's files and the user wants a fast check.

## Lint

- Run the project's lint script through the detected package manager (commonly `<pm> run lint`)
- For autofix, only run `<pm> run lint:fix` (or the project's equivalent) when documented; do not invent it
- Never run `npx eslint .` or pass ad-hoc flags
- Report total failure count and the first three errors with file path and rule; offer to expand if the user wants more

## Type-check

- Run the project's type-check script through the detected package manager (commonly `<pm> run type-check` or `<pm> run typecheck`)
- Never run `npx tsc --noEmit` or pass ad-hoc flags
- Report total failure count and the first three errors with file path and TS error code; offer to expand if the user wants more

## Skip Rules

The skill does not apply for a given gate — exit without running it, and emit one line stating which gate was skipped and why — when:

- No `tsconfig.json` exists at the project root → skip type-check
- No eslint config exists (`eslint.config.*`, `.eslintrc*`, or `"eslintConfig"` in `package.json`) → skip lint
- No matching script exists in `package.json` for the gate → skip that gate; do not fabricate one
- The edited files are non-TypeScript (`.md`, `.json`, `.yml`, assets) and no type-check/lint is wired for them → skip both

## On Failure

When a gate reports errors, do not mark the broader task as complete. The expected flow is:

1. Report the failure summary (count + first three errors)
2. Fix the underlying issue in the code, not by suppressing the rule or weakening the config
3. Re-run the same gate to confirm green

Only after lint and type-check come back clean is the change ready for commit.

## Quality Gate

When finalizing a change that touches TypeScript source:

1. Type-check first (`<pm> run type-check`)
2. Lint second (`<pm> run lint`)

Each step uses the project's documented script via the detected package manager. Never bare `npx`. Never via Docker.
