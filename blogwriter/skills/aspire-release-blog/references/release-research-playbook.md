# Release research playbook

Use this playbook to assemble a candidate feature pool for any Aspire release version.

## Primary sources
1. changelog wiki for the target version
2. `microsoft/aspire` release branch, milestone, and merged work
3. `microsoft/aspire.dev` release branch and staged "what's new" content
4. nearby release posts in `microsoft/aspire-blog`
5. user-provided must-include features or positioning notes

## Preferred order
Start local when possible because it is faster and often richer:
- current `aspire-blog` checkout
- sibling `~/source/aspire`
- sibling `~/source/aspire.dev`
- `gh` or web fallbacks when local material is missing

## Version normalization
Given a version like `13.4`, derive likely source names such as:
- wiki page: `13.4-Change-log`
- release branch: `release/13.4`
- web slug variants like `13-4` when searching docs URLs

Do not assume every source exists in exactly one format. Search if the obvious path fails.

## Candidate selection criteria
Prefer items that are:
- visible to users
- easy to explain in a short section
- connected to a broader theme
- representative of where Aspire is heading
- likely to drive excitement, adoption, or reduced friction

De-prioritize items that are:
- purely internal refactors
- tiny fixes without a story
- repetitive variations of the same change
- already covered better by exhaustive docs or changelog entries

## Suggested research steps
1. Read the changelog/wiki and mark all plausible customer-facing items.
2. Compare with `aspire.dev` what's-new content to find items that are already positioned well.
3. Inspect recent merged work or milestone context in `aspire` to understand the intent behind major items.
4. Group candidates into themes.
5. Reduce to a shortlist of roughly 3-5 highlights.
6. Bring the shortlist to Maddy for approval before drafting.

## Shortlist output format
When presenting options to the user, include:
- the proposed release theme or 1-2 theme options
- each highlight with a one-line why-it-matters explanation
- optional links or source notes for the supporting material
- any places where positioning is unclear and needs Maddy's judgment
