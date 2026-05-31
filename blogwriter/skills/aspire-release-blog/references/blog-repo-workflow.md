# Aspire blog repo workflow notes

These are standing expectations for writing into `microsoft/aspire-blog`. Always verify against the live repo before making changes.

## Working assumptions
- run the skill from the `aspire-blog` checkout when possible
- create one markdown post per PR unless told otherwise
- follow the current folder convention used by nearby posts
- use repo validation before finishing

## Metadata defaults for release posts
- `author1`: `maddy-leger`
- `microsoft_alias`: `maleger`

Other metadata should be proposed based on the specific release and confirmed if it is not already known.

## Practical checklist
1. read `.github/copilot-instructions.md`
2. inspect a nearby recent Aspire release post
3. confirm title, slug, and publish date
4. mirror the folder shape used by nearby posts; do not assume `newpost.cs` matches the current nested date-folder layout
5. write the draft into the correct folder
6. run `validate.sh`
7. if validation is repo-wide, isolate draft-specific warnings from pre-existing repo warnings
8. fix issues and report the final path

## Reminder
The post should complement the changelog and website, not duplicate them. Keep the story curated and readable.
