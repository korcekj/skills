---
name: pr
description: Generate a concise GitHub pull request description from commits unique to a source branch versus a base branch, then optionally create or update a draft PR with gh.
---

# PR Assistant

Use this skill when the user asks for `/pr` behavior, wants a pull request description, or wants help creating or updating a GitHub PR from branch-specific commits.

## Preconditions

- The current directory must be a git repository with a GitHub remote.
- `gh` must be installed and authenticated if the user wants to create or update a PR.
- Remote refs should be up to date before summarizing branch-only commits.

## Inputs

- Optional first argument: source branch.
- Default source branch: the current branch from `git branch --show-current`.
- Optional second argument or `--base`: target/base branch.
- Default base branch: `main`.

## Workflow

1. Determine the source branch.
- If the user provided a first positional branch argument, use it.
- Otherwise detect the current branch:

```bash
git branch --show-current
```

- Verify the remote source exists:

```bash
git rev-parse --verify origin/<source-branch> 2>/dev/null
```

- If the remote source branch does not exist, fall back to the local branch ref:

```bash
git rev-parse --verify <source-branch> 2>/dev/null
```

2. Determine the base branch.
- If the user provided a second positional branch or `--base`, use it.
- Otherwise default to `main`.
- Verify the remote base exists:

```bash
git rev-parse --verify origin/<base-branch> 2>/dev/null
```

3. If the relevant refs are missing locally or look stale, fetch before summarizing:

```bash
git fetch origin <base-branch> <source-branch> --prune
```

4. Gather commits unique to the source branch.

- Prefer remote-vs-remote comparison when `origin/<source-branch>` exists:

```bash
git log --oneline origin/<source-branch> --not origin/<base-branch>
```

- Otherwise compare the local source branch against the remote base:

```bash
git log --oneline <source-branch> --not origin/<base-branch>
```

5. Inspect commit-level changes for the unique commits.

```bash
git show --stat <commit-hash> --format="%h %s"
```

6. Build the PR description using only those unique commits.

7. If there are no unique commits, state that there is nothing to summarize or open as a PR against the selected base branch.

8. Ask the user whether to create or update a draft PR on GitHub.
- If the answer is no, return only the generated description.
- If the answer is yes, continue with `gh`.

9. When creating or updating a PR:
- Verify `gh` auth first when needed:

```bash
gh auth status
```

- Save the generated description to a temp file only for the `gh` step. This is recommended, not mandatory, because `--body-file` is more reliable than inline multiline shell quoting. Prefer `mktemp` over a fixed path:

```bash
body_file="$(mktemp /tmp/pr-body.XXXXXX.md)"
```

- Check whether a PR already exists for the source branch:

```bash
gh pr list --head <source-branch> --json number,url
```

- If a PR exists, update its body:

```bash
gh pr edit <pr-number> --body-file "$body_file"
```

- If no PR exists, create a draft PR:

```bash
gh pr create --draft --title "<short summary>" --body-file "$body_file" --base <base-branch> --head <source-branch>
```

- Return the PR URL.
- If the source branch is local-only, make it clear that the branch must be pushed before PR creation can succeed.

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

## Rules

- Only include commits unique to the source branch by using `--not origin/<base-branch>`.
- Keep each bullet to one line.
- Group related changes.
- Focus on what changed and why, not just filenames.
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

- Run git inspection commands in the current workspace shell.
- If remote refs are stale or absent, fetch them before generating the summary.
- In sandboxed Codex environments, run `gh` commands with escalated permissions and a short justification when required.
- Use `--body-file` with `gh pr edit` and `gh pr create` to avoid shell quoting issues with multiline content.
- Prefer `mktemp` over a hardcoded `/tmp/pr_body.md` file to avoid collisions between runs.
- If the environment has no interactive option UI, ask the create-or-update question directly in chat.
- After creating or updating a PR, verify the result when needed:

```bash
gh pr view <number> --json body,url
```

## Usage Examples

- `/pr`
- `/pr feature/acld-30-nav`
- `/pr feature/acld-30-nav release/v0.1.0`
- `/pr feature/acld-30-nav --base release/v0.1.0`
