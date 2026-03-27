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
