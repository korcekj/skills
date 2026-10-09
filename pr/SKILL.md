---
name: pr
description: Generate a concise pull request description from the commits and diff unique to a source branch versus a base branch, then create a draft PR (or update the existing PR's body) without asking. Pass --dry-run to only print the description. Detects the remote provider (GitHub via gh, Azure DevOps via az) from the origin URL.
argument-hint: '[source-branch] [base-branch] [--base <branch>] [--dry-run]'
disable-model-invocation: true
---

# PR Assistant

Invoking `/pr` is the go-ahead: generate the description, then create a **draft** PR or update the body of the existing one. Do not ask for confirmation. `--dry-run` stops after printing the description and never calls `gh`/`az`.

## Preconditions

- Current directory is a git repository with an `origin` remote.
- Unless `--dry-run`:
  - **GitHub**: `gh` installed and authenticated (`gh auth status`).
  - **Azure DevOps**: `az` with the `azure-devops` extension, authenticated (`az login` or `AZURE_DEVOPS_EXT_PAT`). For MSA-backed orgs raw REST/git-over-AAD tokens are rejected (403); only the `az` extension's own cached credential works, so drive everything through `az repos` / `az devops invoke`.

## Provider detection

```bash
origin_url="$(git remote get-url origin 2>/dev/null)"
case "$origin_url" in
  *dev.azure.com*|*visualstudio.com*) provider="azure" ;;
  *github.com*)                       provider="github" ;;
  *) provider="" ;;
esac
```

If `provider` is empty, print the description and ask the user how to create the PR. Do not guess a provider.

## Workflow

Steps 1–6 are pure git. Only step 7 branches on the provider.

1. **Source branch**: first positional argument, else `git branch --show-current`.

2. **Base branch**: second positional argument or `--base`. Otherwise detect it, because these projects usually target the newest release branch rather than `main`:

```bash
base="$(git branch -r --list 'origin/release/*' --sort=-v:refname | head -1 | sed 's#^ *origin/##')"
[ -z "$base" ] && base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
: "${base:=main}"
```

Always state the chosen base in the output (`Base: release/v1.4.0 (auto-detected)`), so a wrong guess is visible right away.

3. **Fetch** so the comparison runs against current remote state: `git fetch origin <base> <source> --prune` (ignore a missing remote source here; step 4 handles it).

4. **Push guard** (skip with `--dry-run`): a PR can only reflect pushed commits, and pushing is the user's call.
   - `origin/<source>` missing → stop with "push `<source>` first". Do not push.
   - Local ahead of remote (`git rev-list --count origin/<source>..<source>` > 0) → stop with "N local commits not pushed". Do not push.

   With `--dry-run`, compare the local `<source>` when it is ahead or has no remote branch.

5. **Gather the change set** (`<src>` = `origin/<source>`, or the local ref per step 4):

```bash
git log --format='%h %s%n%b' <src> --not origin/<base>   # unique commits + bodies
git diff --stat origin/<base>...<src>                    # scope
git diff origin/<base>...<src> -- . ':!*lock*' ':!*.snap'  # actual changes
```

   No unique commits → say there is nothing to open and stop.
   Read the diff, not just the stat. Commit subjects say *what was touched*; the diff shows *what behavior changed*, which is what the description is for. For very large diffs (> ~2000 lines), read the stat first, then the diffs of the files that carry the logic (skip generated files, fixtures, and locale value churn).

6. **Write the description** (see Output Format) and the title:
   - Title: `<TICKET>: <summary>` when the branch name contains a ticket key (`[A-Z][A-Z0-9]+-[0-9]+`), else just `<summary>`. Summary: imperative, ≤ 70 chars, matching the repo's commit subject style.

7. **Create or update — branch on `provider`.** Write the body to a temp file first: `body_file="$(mktemp "${TMPDIR:-/tmp}/pr-body.XXXXXX")"`. If a PR already exists, update **only the body**. Keep its title and draft state, since the user may have changed them.

### GitHub (`gh`)

```bash
gh pr list --head <source> --base <base> --state open --json number,url
gh pr edit <number> --body-file "$body_file"                     # existing
gh pr create --draft --title "<title>" --body-file "$body_file" \
  --base <base> --head <source>                                   # new
```

### Azure DevOps (`az repos`)

`az` auto-detects org/project/repo from the git remote (`--detect` is on by default). If detection fails, pass `--org https://dev.azure.com/<org> --project <project> --repository <repo>` parsed from the origin URL (`git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`, `https://<org>@dev.azure.com/<org>/<project>/_git/<repo>`, or `https://<org>.visualstudio.com/<project>/_git/<repo>`). There is no `--body-file`; use `"$(cat "$body_file")"`.

```bash
az repos pr list --source-branch <source> --target-branch <base> --status active \
  --query "[].{id:pullRequestId}" -o json
az repos pr update --id <id> --description "$(cat "$body_file")"            # existing
az repos pr create --source-branch <source> --target-branch <base> --draft \
  --title "<title>" --description "$(cat "$body_file")" \
  --query "{id:pullRequestId,repo:repository.name,project:repository.project.name}" -o json   # new
```

The API's `url` is a REST URL. Report the web URL instead: `https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<id>`.

8. **Report**: one line per outcome (`Created draft PR #42: <url>` / `Updated body of PR #42: <url>`), plus the base used. Then print the description.

## Output Format

```markdown
## Summary

[1–2 sentences: what this PR achieves and why — the problem or goal, not a list of files]

## Changes

- ✨ [Behavior added/changed, phrased for a reviewer]
- 🔧 [...]

## Notes

- [Only reviewer/deployer-relevant facts — see below]
```

`## Notes` is **conditional**. Include it only when the diff contains at least one of these, and leave it out otherwise:
- DB migration (and whether it is reversible)
- new/changed env var or config key
- API contract change (request/response shape, status codes, removed endpoint)
- new or upgraded dependency
- breaking change or required client/FE update
- manual deploy/ops step, feature flag, or backfill

The body ends at the last bullet. No footer, attribution, branding, or "Generated with" line.

## Writing rules

- Describe behavior and intent, not mechanics. "Investment preview now returns `estimable` so FE can hide the estimate" beats "Update preview controller and schema".
- Don't restate commit subjects verbatim. Merge related commits into one bullet. Fix-ups of earlier commits in the same branch don't get their own bullet.
- One line per bullet. Mention identifiers (endpoint, field, job name) when a reviewer would search for them; skip file paths.
- Skip formatting-only, lockfile-only, and generated changes unless they affect behavior.
- Emoji prefixes: ✨ feature · 🔧 fix · ♻️ refactor · 📝 docs · 🧪 tests · 🗑️ removal · 🔒 security · ⚡ performance · 🎨 UI · 🏗️ architecture.

## Usage Examples

- `/pr`: current branch, auto-detected base, draft PR
- `/pr --dry-run`: print the description only
- `/pr PAS-38 release/v1.5.0`
- `/pr feature/acld-30-nav --base release/v0.1.0 --dry-run`
