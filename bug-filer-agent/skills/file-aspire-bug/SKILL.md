---
name: file-aspire-bug
description: >
  Files a high-quality bug report against dotnet/aspire (framework/runtime bugs)
  or microsoft/aspire.dev (documentation bugs). Gathers environment context,
  checks for duplicates, drafts the issue for review, and files via GitHub CLI.
allowed-tools:
  - Bash(gh:*)
  - Bash(dotnet:*)
  - Bash(find:*)
  - Bash(grep:*)
  - Bash(cat:*)
  - WebSearch
---

# File Aspire Bug Report

You are filing a bug report. Follow these steps precisely.

## Step 1: Parse Arguments

The bug description is in `$ARGUMENTS`: $ARGUMENTS

If `$ARGUMENTS` is empty or unclear, ask the user to describe the bug before proceeding.

## Step 2: Route to Repository

Determine the target repository based on keywords in the bug description:

- If the description contains "docs", "documentation", "aspire.dev", or "website" → target is **microsoft/aspire.dev**
- Otherwise → target is **dotnet/aspire**
- If ambiguous (e.g., mentions both code and docs), ask the user which repo to file against.

State which repo you're targeting and why.

## Step 3: Gather Environment Context

Collect this information automatically:

1. Run `dotnet --info` and summarize the key parts (SDK version, runtime version, OS).
2. Search the current project for Aspire package versions:
   - Find `.csproj` files and extract `Aspire` package references: `grep -r "Aspire" --include="*.csproj" .`
   - Check `Directory.Packages.props` if it exists: `find . -name "Directory.Packages.props" -exec grep -i "aspire" {} +`
   - Check `global.json` for Aspire SDK version: `find . -name "global.json" -exec cat {} +`

If any of these commands fail (e.g., not in a .NET project), note what's missing and continue — the info is helpful but not blocking.

## Step 4: Search for Duplicates

Extract 2-3 key terms from the bug description and search for existing issues:

```bash
gh api "search/issues?q=is:issue+repo:{TARGET_REPO}+{KEY_TERMS}&per_page=5" --jq '.items[] | "- #\(.number): \(.title) (\(.state)) - \(.html_url)"'
```

Present the results to the user:
- If potentially matching issues are found, list them and ask: "Any of these look like the same issue? If so, I can add a comment instead of filing a new one. Otherwise, I'll proceed with a new issue."
- If no matches found, say so and proceed.

**Wait for user response before continuing.**

## Step 5: Draft the Issue

### For `dotnet/aspire`

Read the template at `references/dotnet-aspire-template.md` (relative to this SKILL.md file). Fill in each section using:
- The bug description from the user
- Environment context from Step 3
- Any error messages, stack traces, or exceptions from the conversation history

Craft a concise, specific title (under 80 characters).

### For `microsoft/aspire.dev`

Read the template at `references/aspire-dev-template.md` (relative to this SKILL.md file). Fill in each section. Include the page URL if known.

## Step 6: Present Draft for Review

Show the complete draft to the user:

```
**Repository:** {repo}
**Title:** {title}
**Labels:** bug

---
{full body}
---
```

Ask: "Ready to file this? Let me know if you'd like any changes."

**NEVER file the issue without explicit user approval.** Wait for confirmation.

## Step 7: File the Issue

Write the issue body to a temp file and use `gh issue create`:

```bash
cat > /tmp/aspire-issue-body.md << 'ISSUE_BODY'
{body content}
ISSUE_BODY
```

For **dotnet/aspire**:
```bash
gh issue create --repo dotnet/aspire --title "{title}" --body-file /tmp/aspire-issue-body.md --label "bug"
```

For **microsoft/aspire.dev**:
```bash
gh issue create --repo microsoft/aspire.dev --title "{title}" --body-file /tmp/aspire-issue-body.md
```

Clean up the temp file after:
```bash
rm /tmp/aspire-issue-body.md
```

## Step 8: Report Back

Return the issue URL to the user. Example:

"Filed: https://github.com/dotnet/aspire/issues/XXXX"
