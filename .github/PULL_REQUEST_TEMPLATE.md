## What this PR changes
<!-- short summary -->

## Why
<!-- which section of SKILL.md, what was wrong/missing, why this fixes it -->

## How verified
- [ ] Ran `/refresh-monday-skill` locally — clean / drift detected → patched
- [ ] Executed end-to-end against a throwaway monday workspace
- [ ] Schema introspection matches the new claim (`get_type_details` / `get_graphql_schema`)
- [ ] Other (describe):

## Account-neutrality
- [ ] No board IDs, column IDs, group IDs, or account-specific products baked into SKILL.md
- [ ] Claims are framed as "what the API exposes," not "what my account has"

## Skill version bump
- [ ] Bumped `version: YYYY-MM-DD` in `skills/monday-architect/SKILL.md` frontmatter
- [ ] Added a CHANGELOG.md entry under a new dated section
