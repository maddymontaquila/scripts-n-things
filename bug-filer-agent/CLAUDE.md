# Aspire Bug Filer Skill

A Claude Code skill for filing high-quality bug reports against [dotnet/aspire](https://github.com/dotnet/aspire) (framework/runtime) and [microsoft/aspire.dev](https://github.com/microsoft/aspire.dev) (documentation).

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- `dotnet` SDK installed (for environment context gathering)

## Installation

Run the installer to symlink the skill into your global Claude Code skills directory:

```bash
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/skills
ln -sf "$(pwd)/skills/file-aspire-bug" ~/.claude/skills/file-aspire-bug
```

## Usage

In any Claude Code session:

```
/file-aspire-bug <description of the bug>
```

The skill will:

1. Route to the correct repo (`dotnet/aspire` or `microsoft/aspire.dev`) based on keywords
2. Gather environment context (`dotnet --info`, Aspire package versions)
3. Search for duplicate issues
4. Draft a well-formatted issue using the repo's template structure
5. Present the draft for your review
6. File the issue after explicit approval

## Repo Routing

- Keywords like "docs", "documentation", "aspire.dev", "website" route to `microsoft/aspire.dev`
- Everything else routes to `dotnet/aspire`
- If ambiguous, the skill will ask you
