---
name: pr
description: Generate a concise pull request description from commits unique to a source branch versus a base branch, then optionally create or update a draft PR. Detects the remote provider (GitHub via gh, Azure DevOps via az) from the origin URL and runs the matching flow.
argument-hint: '[source-branch] [base-branch]'
disable-model-invocation: true
---

# PR Assistant

Use this skill when the user asks for `/pr` behavior, wants a pull request description, or wants help creating or updating a PR from branch-specific commits. Works against both **GitHub** (`gh`) and **Azure DevOps** (`az repos`) remotes; the provider is detected from the `origin` URL.

## Preconditions

- The current directory must be a git repository with an `origin` remote.
- Remote refs should be up to date before summarizing branch-only commits.
- To create or update a PR:
  - **GitHub**: `gh` installed and authenticated (`gh auth status`).
  - **Azure DevOps**: `az` installed with the `azure-devops` extension (`az extension add --name azure-devops`) and authenticated (`az login`, or `AZURE_DEVOPS_EXT_PAT` set). Note: for MSA-backed orgs, raw REST/git-over-AAD tokens are rejected (403) — only the `az` extension's own cached credential works, so drive everything through `az repos` / `az devops invoke`.

## Provider detection

Detect the provider from the origin URL first; every later step branches on it.

```bash
origin_url="$(git remote get-url origin 2>/dev/null)"
case "$origin_url" in
  *dev.azure.com*|*visualstudio.com*) provider="azure" ;;
  *github.com*)                       provider="github" ;;
  *) provider="" ;;  # unknown — ask the user which provider / how to create the PR
esac
```

If `provider` is empty, still generate the description; ask the user how they want the PR created before running any provider command.

### Parse Azure DevOps coordinates from the origin URL

Azure DevOps needs org / project / repo explicitly (unless `az devops configure --defaults` is set). Handle the common URL shapes:

- SSH v3: `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}`
- HTTPS: `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}`
- Legacy: `https://{org}.visualstudio.com/{project}/_git/{repo}`

```bash
# yields: ORG PROJECT REPO and ORG_URL=https://dev.azure.com/<org>
parse_azure() {
  local u="$1"
  if [[ "$u" == *ssh.dev.azure.com* ]]; then
    # git@ssh.dev.azure.com:v3/ORG/PROJECT/REPO
    local rest="${u#*v3/}"; ORG="${rest%%/*}"; rest="${rest#*/}"
    PROJECT="${rest%%/*}"; REPO="${rest#*/}"
  elif [[ "$u" == *visualstudio.com* ]]; then
    # https://ORG.visualstudio.com/PROJECT/_git/REPO
    ORG="$(echo "$u" | sed -E 's#https?://([^.]+)\.visualstudio\.com/.*#\1#')"
    PROJECT="$(echo "$u" | sed -E 's#.*visualstudio\.com/([^/]+)/_git/.*#\1#')"
    REPO="$(echo "$u" | sed -E 's#.*/_git/##')"
  else
    # https://[ORG@]dev.azure.com/ORG/PROJECT/_git/REPO
    local path="${u#*dev.azure.com/}"
    ORG="${path%%/*}"; path="${path#*/}"
    PROJECT="${path%%/*}"; REPO="${path#*/_git/}"
  fi
  REPO="${REPO%.git}"
  ORG_URL="https://dev.azure.com/$ORG"
}
```

Prefer the values Azure DevOps itself reports when available (e.g. `az repos pr show --id <id> --query repository.name`) over string parsing.

## Workflow

Steps 1–7 are **provider-agnostic** (pure git). Only steps 8–9 branch on the provider.

1. Determine the source branch.

- If the user provided a first positional branch argument, use it.
- Otherwise detect the current branch: `git branch --show-current`.
- Verify the remote source exists: `git rev-parse --verify origin/<source-branch> 2>/dev/null`.
- If the remote source branch does not exist, fall back to the local ref: `git rev-parse --verify <source-branch> 2>/dev/null`.

2. Determine the base branch.

- If the user provided a second positional branch or `--base`, use it.
- Otherwise default to `main`. Note: this project family usually targets a `release/vX.Y.Z` branch — if the current base is ambiguous, confirm with the user.
- Verify the remote base exists: `git rev-parse --verify origin/<base-branch> 2>/dev/null`.

3. If refs are missing locally or look stale, fetch before summarizing:

```bash
git fetch origin <base-branch> <source-branch> --prune
```

4. Gather commits unique to the source branch.

```bash
# preferred, when origin/<source-branch> exists
git log --oneline origin/<source-branch> --not origin/<base-branch>
# otherwise, local source vs remote base
git log --oneline <source-branch> --not origin/<base-branch>
```

5. Inspect commit-level changes: `git show --stat <commit-hash> --format="%h %s"`.

6. Build the PR description from only those unique commits (see Output Format).

7. If there are no unique commits, state that there is nothing to summarize or open, and stop.

8. Ask the user whether to create or update a PR.

- If no, return only the generated description.
- If yes, continue with the provider-specific step. Save the description to a temp file first (more reliable than inline multiline quoting):

```bash
body_file="$(mktemp "${TMPDIR:-/tmp}/pr-body.XXXXXX.md")"
```

9. Create or update the PR — **branch on `provider`**.

### GitHub (`gh`)

```bash
gh auth status
# existing PR for this source branch?
gh pr list --head <source-branch> --json number,url
# update
gh pr edit <pr-number> --body-file "$body_file"
# or create draft
gh pr create --draft --title "<short summary>" --body-file "$body_file" \
  --base <base-branch> --head <source-branch>
gh pr view <number> --json body,url   # verify
```

### Azure DevOps (`az repos`)

`az` has no `--body-file`; pass the description via `"$(cat "$body_file")"`. Branch names may be short (`PAS-38`) or full (`refs/heads/PAS-38`).

```bash
parse_azure "$origin_url"   # sets ORG_URL PROJECT REPO

# existing active PR for this source→base?
az repos pr list --org "$ORG_URL" --project "$PROJECT" --repository "$REPO" \
  --source-branch <source-branch> --target-branch <base-branch> --status active \
  --query "[].{id:pullRequestId,url:url}" -o json

# update body (and publish a draft by adding --draft false)
az repos pr update --org "$ORG_URL" --id <pr-id> --description "$(cat "$body_file")"

# or create a draft PR
az repos pr create --org "$ORG_URL" --project "$PROJECT" --repository "$REPO" \
  --source-branch <source-branch> --target-branch <base-branch> \
  --title "<short summary>" --description "$(cat "$body_file")" --draft \
  --query "{id:pullRequestId,url:url}" -o json

# verify
az repos pr show --org "$ORG_URL" --id <pr-id> --query "{title:title,url:url,status:status}" -o json
```

Notes for Azure DevOps:

- The source branch must already be pushed to the Azure DevOps remote before `az repos pr create` succeeds — creation does not push.
- `--description` accepts multiple space-separated values (each a paragraph); a single quoted multiline string also works.
- Azure DevOps PR web URLs follow `https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<id>` — the `url` field returned by the API is the REST URL, so construct the web URL from the id if the user wants a clickable link.
- If the source branch is local-only, make clear it must be pushed first.

## Output Format

```markdown
## Summary

[One sentence describing the overall goal of this PR]

## Changes

- ✨ [New feature or addition]
- 🔧 [Fix or bug resolution]
- ♻️ [Refactor or improvement]
- 📝 [Documentation update]
- 🧪 [Test addition or update]
- 🗑️ [Removal or deprecation]
```

No footer, no attribution line, no branding after the bullets. The body ends at the last bullet.

## Rules

- NEVER add branding, footers, attribution, or "Generated with" lines to the PR body.
- Only include commits unique to the source branch by using `--not origin/<base-branch>`.
- Keep each bullet to one line. Group related changes. Focus on what changed and why, not filenames.
- Skip trivial formatting-only edits unless they materially affect behavior.
- Preserve important user-facing, architectural, testing, security, and documentation changes.
- Use emojis consistently:
  - ✨ features
  - 🔧 fixes
  - ♻️ refactors
  - 📝 docs
  - 🧪 tests
  - 🗑️ removals
  - 🔒 security
  - ⚡ performance
  - 🎨 UI or styling
  - 🏗️ architecture

## Execution Notes

- Run git inspection commands in the current workspace shell. Fetch stale/absent refs before summarizing.
- Detect the provider once (from `origin`) and reuse it; never assume GitHub.
- GitHub: use `--body-file`. Azure DevOps: use `--description "$(cat "$body_file")"`.
- Prefer `mktemp` over a hardcoded path to avoid collisions between runs.
- If the environment has no interactive option UI, ask the create-or-update question directly in chat.

## Usage Examples

- `/pr`
- `/pr PAS-38 release/v1.5.0`               (Azure DevOps repo)
- `/pr feature/acld-30-nav --base release/v0.1.0`   (GitHub repo)
