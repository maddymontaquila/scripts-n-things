# Aspire release blog skill

A global Copilot user skill for drafting Aspire release blog posts in Maddy's voice.

## What it does
- takes the Aspire release version as input at runtime
- gathers tone signals from prior Maddy-authored Aspire/DevBlogs posts and PR review feedback
- researches candidate highlights from `aspire`, `aspire.dev`, and the changelog/wiki
- proposes a shortlist and theme before drafting
- writes a single `aspire-blog` markdown post and runs local validation when approved

## Install
```bash
cd /Users/maddy/source/scripts-n-things/blogwriter
./install.sh
```

By default this symlinks the skill into `~/.copilot/skills/aspire-release-blog`.
After installing, restart or relaunch Copilot CLI so the new user skill is discoverable.

## Use
Start Copilot CLI from the `microsoft/aspire-blog` checkout, then invoke the skill with a version:

```text
/aspire-release-blog 13.4
```

You can also provide extra direction in the prompt, for example:

```text
/aspire-release-blog 13.4 theme=build-readiness must_include="TypeScript improvements, agentic work" avoid="tiny bug fixes"
```

## Expected local repos
The skill is designed to run from `~/source/aspire-blog` and will look for sibling clones at:
- `~/source/aspire`
- `~/source/aspire.dev`

If a local repo or release branch is missing, it should fall back to GitHub/web sources.
