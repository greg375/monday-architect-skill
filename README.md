# monday-architect — a Claude Code skill for the monday.com MCP connector

A pair of Claude Code skills for building accounts on monday.com via the official monday MCP connector:

- **`monday-architect`** — operator's manual that forces correct product/architecture choices and documents every verified mutation, query, enum value, and column-value shape across the monday GraphQL API.
- **`refresh-monday-skill`** — companion skill that re-verifies `monday-architect` against the live API on demand and reports any drift.

## What's it for?

Out of the box, Claude often builds wrong on monday: putting CRM pipelines on Work Management boards, faking portfolios with mirror columns, refusing widgets that exist, and writing column-value JSON in shapes the API rejects.

This skill loads a verified map of the monday API into Claude's context so that:

1. Claude picks the right product (CRM vs Work Management vs Dev vs Service vs Marketing vs Projects).
2. Claude uses native objects (Projects + Portfolio for cross-board rollup, not regular boards with mirrors).
3. Claude wires `board_relation` + `mirror` columns correctly across boards.
4. Claude builds widgets from the verified catalog instead of refusing or inventing.
5. Claude writes column-value payloads in shapes the API actually accepts.

The whole skill was verified end-to-end against the live MCP (creating workspaces, boards, columns of every type, dashboards with all 16 chart variants, portfolios with connected projects, forms, docs, webhooks, etc.) — every mutation, query, and value shape was either *executed* or introspected against the live GraphQL schema.

## Install

Clone or copy the `skills/` directory into your Claude Code skills folder:

```bash
git clone https://github.com/greg375/monday-architect-skill ~/monday-architect-skill
mkdir -p ~/.claude/skills/
cp -r ~/monday-architect-skill/skills/monday-architect ~/.claude/skills/
cp -r ~/monday-architect-skill/skills/refresh-monday-skill ~/.claude/skills/
```

Or run the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/greg375/monday-architect-skill/main/install.sh | bash
```

(Both skills install into `~/.claude/skills/`. They're independent — install one without the other if you prefer.)

## Prerequisites

- **Claude Code** (CLI, desktop app, or VS Code extension).
- **The monday.com MCP connector** connected to your Claude account. Connect it at https://claude.ai/customize/connectors. The skill expects tool names of the form `mcp__claude_ai_monday_com__*`.
- **A monday.com account** you have permission to build in. The skill will work on any tier, but some features (validation rules, certain bulk-job paths, owner-restricted mutations) are gated by plan/role.

## Use

Once installed, the `monday-architect` skill triggers automatically whenever you mention monday.com, the MCP tool prefix, or any monday concept (boards, dashboards, deals, sprints, portfolios, mirrors, etc.) in Claude Code. You don't invoke it manually.

To verify the skill is still accurate against your account, run:

```
/refresh-monday-skill
```

It will introspect the live monday API, diff every cited mutation/query/enum against what the skill asserts, report drift, and (with your approval) patch your local skill file.

## Versioning

Each release of the skill carries a `version: YYYY-MM-DD` field in the SKILL.md frontmatter. To see your installed version:

```bash
head -10 ~/.claude/skills/monday-architect/SKILL.md
```

To update to the latest:

```bash
cd ~/monday-architect-skill && git pull
cp -r skills/monday-architect ~/.claude/skills/
cp -r skills/refresh-monday-skill ~/.claude/skills/
```

## What the skill covers

- All 8 monday product kinds and when to use each
- Workspace + folder layout (and the gotcha: `create_board` doesn't take a folder ID)
- All 40+ column types with verified value shapes
- Cross-board relationships (`board_relation` + `mirror`) and the wiring pitfalls
- All 7 dashboard widget types and 16 CHART variants — verified end-to-end
- Forms (with backing-board auto-creation, 23 question types, conditional logic)
- Docs (with markdown auto-import, block-level mutations, version history)
- Updates / replies / notifications / mentions
- Automations: webhooks (22 event types), integration blocks, trigger analytics
- Audit logs and compliance
- Dev product (sprints, epics, sequences)
- Notetaker (meeting transcripts, action items)
- Search (3 strategies, multi-entity)
- Users / teams / departments / permissions
- Objects platform
- Schema introspection (complexity budgets, version pinning)
- Raw GraphQL fallback patterns
- Error semantics and the most common `ColumnValueException` codes
- Demo-build mode: data realism, dashboard composition, cross-product flows, cleanup
- Project + Portfolio mutation shapes (verified) and the portfolio quick-start
- ~30 anti-patterns to refuse on sight

## Maintenance

This skill is a snapshot of the monday API as of its `version` date. monday.com ships fast — APIs drift, new mutations appear, enum values get added or deprecated. Two ways to stay current:

- **Per-user (recommended for production demos):** Run `/refresh-monday-skill` before any high-stakes demo.
- **Periodic:** Run `/refresh-monday-skill` on a monthly cadence. The companion skill will detect schema drift, gone mutations, new fields, and offer to patch your local copy.

If you want auto-detection, you can wire `/refresh-monday-skill` to a scheduled remote routine (see `docs/scheduled-refresh.md`) — but the patcher itself runs locally because it edits files in your `~/.claude/skills/` directory.

## Contributing

Issues and PRs welcome. If you find an API behavior that contradicts what the skill asserts:

1. Run `/refresh-monday-skill` to confirm it's drift, not a typo.
2. Open an issue with the diff.
3. Or send a PR patching `skills/monday-architect/SKILL.md` directly.

Please don't add account-specific facts (board IDs, column IDs, your account's enabled products) to the skill — keep it neutral.

## License

MIT. See `LICENSE`.

## Acknowledgements

The initial release was built and verified end-to-end against the live monday MCP connector via two rounds of execution against a real enterprise monday account. Dozens of API gotchas surfaced during those rounds are now baked into the skill so Claude doesn't repeat them. See `CHANGELOG.md` for the verified facts and gotchas captured at each release.
