# Skills

Personal agent skills published from this repository.

## Install

Install the `<skill>` skill from GitHub:

```bash
npx skills add korcekj/skills --skill <skill>
```

Or install from a full repository URL:

```bash
npx skills add https://github.com/korcekj/skills --skill <skill>
```

## Update

Check for available updates to installed skills:

```bash
npx skills check
```

Update installed skills to the latest versions:

```bash
npx skills update
```

## Available Skills

| Skill                  | Description                                                                                                                                                                                                                              | Install                                                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `pr`                   | Generate a concise pull request description from the commits and diff unique to a source branch, then create a draft PR or update an existing one (GitHub `gh` / Azure DevOps `az`). `--dry-run` only prints the description.          | `npx skills add korcekj/skills --skill pr`                   |
| `node-backend-testing` | Testing strategy and workflow guide for Node.js backends using Mocha, Chai, Supertest, Rewiremock, and Docker Compose.                                                                                                                   | `npx skills add korcekj/skills --skill node-backend-testing` |
| `node-backend-checks`  | Lint and type-check guardrail for Node.js/TypeScript backends.                                                                                                                                                                           | `npx skills add korcekj/skills --skill node-backend-checks`  |
| `upgrade-review`       | Review dependency upgrades (Dependabot/Renovate PRs, audit findings, manual lists) for breaking changes, apply safe ones with pinned versions, verify and boot-check the app — never commits or closes PRs.                              | `npx skills add korcekj/skills --skill upgrade-review`       |
| `build-spec`           | Generate or update a client/FE-facing feature spec (Slovak, Notion-ready) from a technical plan or implemented code, incl. external-system entity contracts and validated mermaid diagrams.                                              | `npx skills add korcekj/skills --skill build-spec`           |
| `review-triage`        | Evaluate another AI agent's code review — verify each finding against the real code, separate real issues from false positives, apply only approved fixes and verify them.                                                               | `npx skills add korcekj/skills --skill review-triage`        |
| `build-plan`           | Create or update a technical implementation plan (`files/<feature>/<feature>-plan.md`) — researches JIRA/Notion/code first, then grills round by round until no architectural, contract, failure-mode or security question is left open. | `npx skills add korcekj/skills --skill build-plan`           |
| `implement-plan`       | Implement a plan's Rollout items through subagents — implementer, gates, independent reviewer and a capped fix loop against the plan's Decisions and each item's "Done when" — then smoke-run the app. Never commits.                    | `npx skills add korcekj/skills --skill implement-plan`       |
| `changelog`            | Per-release changelog of API contract changes (endpoints, request/response shapes, breaking changes) from the tag-to-tag diff, linked to Jira and Notion specs, posted to Slack after approval.                                          | `npx skills add korcekj/skills --skill changelog`            |
