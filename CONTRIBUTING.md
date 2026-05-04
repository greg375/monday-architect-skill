# Contributing

Thanks for considering a contribution. Three kinds of changes are most useful.

## 1. API drift fixes

monday.com ships fast. If you find a fact in `skills/monday-architect/SKILL.md` that no longer matches the live API:

1. Run `/refresh-monday-skill` locally to confirm it's drift, not a typo.
2. If `/refresh-monday-skill` flagged it, follow its suggested patch.
3. If you found it manually, open an "API drift" issue using the template, or send a PR straight to `SKILL.md`.

## 2. New mutations / queries / enum values

If you found something in the monday API the skill doesn't cover:

1. Verify it exists by running `get_graphql_schema` or `get_type_details` against the live MCP.
2. Run it once end-to-end if it's a mutation — make sure it actually works, not just that it compiles.
3. Add it to the appropriate section of `SKILL.md` with a short note on the verified arg shape.
4. Update CHANGELOG.md with a new dated entry.

## 3. Bad-claim bug reports

If Claude built something wrong on monday because of a wrong claim in the skill:

1. Open a "bad-claim" issue with a minimal repro prompt.
2. Quote the misleading claim from `SKILL.md` if you can find it.
3. Either we fix it, or you send a PR.

## Things to avoid

- **Don't bake account-specific facts into the skill.** No board IDs, column IDs, group IDs, or "this account has products X/Y/Z." The skill should work for any account.
- **Don't add behavioral claims you haven't tested.** "I think this should work" is fine in an issue but not in `SKILL.md`. The skill's value comes from every claim being either schema-introspected or executed.
- **Don't remove the version stamp or "verified on" line.** Other users rely on those for currency.

## Skill version bumps

When merging any PR that changes `SKILL.md` content, bump the `version:` field in the frontmatter to today's date. Tag the merge with `vYYYY-MM-DD`. Cut a GitHub release pointing at the new tag with the relevant CHANGELOG entry.

## Layered verification

The skill has three layers of correctness, in increasing cost:

1. **Schema introspection** — `get_graphql_schema` says it exists. Cheap, automated by `/refresh-monday-skill`.
2. **Tool-schema check** — the MCP tool's input-validation enum says it exists. Verified by checking the connector's `enum` fields directly.
3. **End-to-end execution** — actually call the mutation in a throwaway workspace. Catches behavioral changes, permission gates, feature flags. Recommended before high-stakes demos.

For each PR, indicate which layers you've verified at via the PR template checkboxes.
