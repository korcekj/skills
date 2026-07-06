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

| Skill | Description                                                                                                                                                            | Install                                    |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `pr`  | Generate a concise GitHub pull request description from commits unique to a source branch versus a base branch, then optionally create or update a draft PR with `gh`. | `npx skills add korcekj/skills --skill pr` |
| `node-backend-testing` | Testing strategy and workflow guide for Node.js backends using Mocha, Chai, Supertest, Rewiremock, and Docker Compose. | `npx skills add korcekj/skills --skill node-backend-testing` |
| `node-backend-checks` | Lint and type-check guardrail for Node.js/TypeScript backends. | `npx skills add korcekj/skills --skill node-backend-checks` |
| `upgrade-review` | Review dependency upgrades (Dependabot/Renovate PRs, audit findings, manual lists) for breaking changes, apply safe ones with pinned versions and verify — never commits or closes PRs. | `npx skills add korcekj/skills --skill upgrade-review` |
| `build-spec` | Generate or update a client/FE-facing feature spec (Slovak, Notion-ready) from a technical plan or implemented code, with validated mermaid diagrams. | `npx skills add korcekj/skills --skill build-spec` |
