---
name: aspire-release-blog
description: Draft an Aspire release blog post in Maddy Leger's voice. Use when working from the aspire-blog repo and you need to research a release, propose a curated highlight shortlist, draft a single markdown post, and validate it.
---

# Aspire release blog writer

This skill writes **Aspire release blogs in Maddy's voice**. It is intentionally **generic by version**: never bake in release-specific assumptions. Always take the release number from the current request or ask for it.

## Core goals
- sound like Maddy, not generic marketing copy
- curate a few high-value, customer-facing highlights instead of exhaustively listing everything
- propose a theme and shortlist before drafting
- produce a single `aspire-blog`-ready markdown file and validate it locally

## Inputs to collect
At minimum, collect or confirm:
- release version, like `13.4`
- any release theme or framing to emphasize
- must-include items
- items to avoid or de-emphasize
- publish date if you are writing the file
- preferred title/slug if the user already has them in mind

If any of these materially affect the draft, ask before writing.

## Workspace checks
1. Prefer running from the `microsoft/aspire-blog` checkout.
2. Confirm the current repo is the blog repo by checking for familiar files such as `.github/copilot-instructions.md`, `validate.sh`, and recent post folders.
3. If the user is not in the blog repo, ask whether to continue with a path they provide or switch to `~/source/aspire-blog`.
4. Look for sibling repos at:
   - `~/source/aspire`
   - `~/source/aspire.dev`
5. If local clones or release branches are missing, fall back to GitHub or web reads instead of failing.

## Blog workflow constraints
Before drafting, read the current repo guidance from the live checkout, especially:
- `.github/copilot-instructions.md`
- `README.md`
- `validate.sh`
- recent Aspire release posts near the target date

Treat the live repo instructions as the source of truth. Also follow these standing expectations:
- keep the PR to a single markdown post unless the user asks for something else
- mirror the current blog folder layout used by nearby posts
- set `author1` to `maddy-leger`
- set `microsoft_alias` to `maleger`
- validate after writing and fix issues before handing off

## Voice and editorial guidance
Use `references/editorial-voice.md` as the standing tone guide, then verify it against live samples in the repo and relevant PR review comments.

When building the draft:
- open with momentum and a clear reason this release matters
- sound like a developer talking to developers: confident, specific, and excited
- prioritize the most interesting customer-facing changes, not every patch or refactor
- explain why a feature matters in practice, not just what changed
- keep the framing positive and forward-looking
- avoid flat, exhaustive changelog narration
- keep jokes light and optional; if a line feels forced, cut it
- use links to docs or release notes for deeper detail instead of stuffing every detail into the post

## Research workflow
Use `references/release-research-playbook.md`, then adapt to the specific release.

Build a candidate pool from:
- the Aspire changelog wiki for the target version
- milestone or release activity in `microsoft/aspire`
- relevant `release/<version>` content in `microsoft/aspire.dev`
- recent blog history in `microsoft/aspire-blog`
- PR review comments that reveal tone or emphasis preferences, especially `microsoft/aspire-blog#52`

Filter candidates toward:
- customer-facing impact
- features users are likely to notice or ask about
- items that support a coherent release theme
- things the team is genuinely excited about

Avoid centering the post on:
- tiny fixes without user impact
- internal-only refactors
- a laundry list of every change

## Required interaction flow
Do not jump straight into a full draft.

1. Research the release and gather voice signals.
2. Propose a shortlist of likely highlights and 1-2 possible themes.
3. Ask the user to confirm, reorder, add must-includes, or cut items.
4. Only after approval, draft the post.
5. If title, slug, or publish date are still unresolved, propose sensible defaults and confirm them.
6. Write the file, then validate it.

## Draft structure
A strong default structure is:
1. title and frontmatter
2. short opening that frames the release
3. 3-5 major highlight sections with practical context
4. links to the full changelog and/or what's new content for exhaustive detail
5. closing CTA that points readers to try it, read more, or give feedback

Keep the article focused. A good release post is curated and readable.

## File creation and validation
When the user wants the draft written into the repo:
1. Find a nearby recent post and mirror its folder shape, for example `YYYY/MM-Mon/slug/slug.md` if that is the current convention.
2. Reuse repo conventions for frontmatter and section formatting.
3. Prefer matching nearby live post layout over blindly using `newpost.cs`; if the helper script produces a flatter structure than current posts, follow current posts.
4. Run the repo validation script after writing.
5. If validation is repo-wide, separate draft-specific warnings from unrelated existing repo warnings.
6. Fix any markdown or metadata issues you can fix safely.
7. Report the final file path and any follow-up edits that still need human input.

## Output expectations
At the end of a successful run, provide:
- the approved theme
- the chosen shortlist of highlights
- the final file path
- validation status
- any open questions that still need Maddy's judgment
