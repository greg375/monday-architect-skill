---
name: refresh-monday-skill
description: Verify the monday-architect skill against the live monday MCP and report any drift since the last verification. Run this when the user types `/refresh-monday-skill`, after a monday API release announcement, before a high-stakes demo, or on a periodic cadence (e.g. monthly via the schedule skill). Re-introspects every named mutation/query, every enum cited in the skill, and the widget/view catalogs, then produces a diff report and (with user approval) patches `~/.claude/skills/monday-architect/SKILL.md` to reflect the current state of the API.
---

# refresh-monday-skill — Layer 2 verification routine

This skill keeps `~/.claude/skills/monday-architect/SKILL.md` in sync with the live monday GraphQL schema. It does NOT execute any account-mutating builds (no test workspaces, no created boards). It only runs introspection queries and compares them to the facts asserted in the architect skill.

When invoked, work through these steps in order:

## Step 1 — Confirm prerequisites

- Confirm the monday MCP connector is connected and authenticated. Run `mcp__claude_ai_monday_com__get_user_context` once. If it errors, stop and tell the user to authenticate.
- Read the current state of `~/.claude/skills/monday-architect/SKILL.md` so you have the asserted facts to compare against.

## Step 2 — Re-introspect the load-bearing facts

Run these in parallel (they are all read-only):

| Tool / query | What it confirms |
|---|---|
| `mcp__claude_ai_monday_com__get_graphql_schema(operationType: "read")` | Full list of query field names + GraphQL type names |
| `mcp__claude_ai_monday_com__get_graphql_schema(operationType: "write")` | Full list of mutation field names |
| `mcp__claude_ai_monday_com__all_widgets_schema` | Every dashboard widget type and its config schema |
| `mcp__claude_ai_monday_com__get_user_context` | Active product kinds on this account |
| `get_type_details(BoardKind)` (raw GraphQL) | Board visibility enum |
| `get_type_details(WorkspaceKind)` | Workspace visibility enum |
| `get_type_details(DashboardKind)` | Dashboard visibility enum |
| `get_type_details(ColumnType)` | Full column type enum |
| `get_type_details(WebhookEventType)` | All webhook event types |
| `get_type_details(WorkspacesQueryAccountProductKind)` | All product kinds |
| `get_type_details(ViewKind)` | Creatable view types |
| `get_type_details(SearchStrategy)` | Search strategy enum |
| `get_type_details(NotificationTargetType)` | Notification target enum |
| `get_type_details(DuplicateBoardType)` | Board duplication mode enum |
| `get_type_details(BoardMuteState)` | Board mute state enum |
| `get_type_details(BulkImportState)` | Bulk import job state enum |
| Tool schema for `create_widget` (via ToolSearch select) | The 7 creatable widget kinds |
| Tool schema for `create_column` | The full ColumnType enum exposed via the MCP wrapper |
| Tool schema for `create_folder` | Folder color/icon/font-weight enums |

## Step 3 — Build a diff report

For every fact the architect skill asserts, mark one of:

- **OK** — schema matches the skill verbatim.
- **DRIFT** — schema differs from the skill (new value added, old value removed, renamed). Capture the specific change.
- **GONE** — the named mutation/query/type no longer exists. High-priority fix.
- **NEW** — the schema has something the skill doesn't mention (a new mutation, a new enum value, a new widget type). Lower priority but worth noting.

Specifically check these load-bearing claims in `SKILL.md`:

1. **Product kinds** (§1, §27): `core`, `crm`, `software`, `service`, `marketing` / `marketing_campaigns`, `project_management`, `forms`, `whiteboard`. Compare against `WorkspacesQueryAccountProductKind` enum.
2. **BoardKind** (§3, §27): `private`, `public`, `share`.
3. **WorkspaceKind** (§2, §27): `open`, `closed`, `template`.
4. **DashboardKind** (§7, §27): `PUBLIC`, `PRIVATE`.
5. **ColumnType** (§4, §27): the 40+ values in §4. Compare against the live enum AND against the `create_column.columnType` tool-schema enum.
6. **WebhookEventType** (§11, §27): the 21 values in §11.
7. **Widget catalog** (§7, §27): `NUMBER`, `CHART`, `BATTERY`, `CALENDAR`, `GANTT`, `LISTVIEW`, `APP_FEATURE`. Compare against both `all_widgets_schema` keys AND `create_widget.widget_kind` tool-schema enum.
8. **CHART graph_type variants** (§7): 24 values — 16 camelCase + 8 underscore aliases. Both forms accepted by API.
9. **ViewKind** (§3, §27): `DASHBOARD`, `TABLE`, `FORM`, `APP`.
10. **DuplicateBoardType** (§3.5): `duplicate_board_with_pulses`, `duplicate_board_with_pulses_and_updates`, `duplicate_board_with_structure`.
11. **NotificationTargetType** (§10): `Post`, `Project`.
12. **SearchStrategy** (§15): `SPEED`, `BALANCED`, `QUALITY`.
13. **BoardMuteState** (§25): `NOT_MUTED`, `MUTE_ALL`, `MENTIONS_AND_ASSIGNS_ONLY`, `CUSTOM_SETTINGS`, `CURRENT_USER_MUTE_ALL`.
14. **All cited mutation names** — grep the skill for backticked function names matching the pattern `[a-z_]+` and verify each appears in the write schema. Names cited:
    `create_workspace`, `update_workspace`, `delete_workspace`, `create_folder`, `update_folder`, `delete_folder`, `move_object`, `use_template`, `update_board_hierarchy`, `create_board`, `update_board`, `delete_board`, `archive_board`, `duplicate_board`, `create_column`, `update_column`, `delete_column`, `create_status_column`, `update_status_column`, `create_dropdown_column`, `update_dropdown_column`, `attach_status_managed_column`, `attach_dropdown_managed_column`, `create_status_managed_column`, `update_status_managed_column`, `create_dropdown_managed_column`, `update_dropdown_managed_column`, `activate_managed_column`, `deactivate_managed_column`, `delete_managed_column`, `create_group`, `update_group`, `delete_group`, `archive_group`, `duplicate_group`, `create_item`, `create_subitem`, `change_item_column_values`, `change_simple_column_value`, `change_multiple_column_values`, `change_column_value`, `change_column_metadata`, `change_column_title`, `change_item_position`, `move_item_to_board`, `move_item_to_group`, `delete_item`, `archive_item`, `duplicate_item`, `bulk_delete_items`, `bulk_archive_items`, `undo_action`, `clear_item_updates`, `add_file_to_column`, `add_file_to_update`, `update_assets_on_item`, `set_item_description_content`, `add_required_column`, `remove_required_column`, `update_dependency_column`, `batch_update_dependency_column`, `create_timeline_item`, `delete_timeline_item`, `create_custom_activity`, `delete_custom_activity`, `create_doc`, `update_doc`, `update_doc_name`, `delete_doc`, `duplicate_doc`, `read_docs`, `create_doc_block`, `create_doc_blocks`, `update_doc_block`, `delete_doc_block`, `add_content_to_doc_from_markdown`, `import_doc_from_html`, `create_view_table`, `update_view_table`, `create_dashboard`, `update_dashboard`, `update_overview_hierarchy`, `delete_dashboard`, `create_widget`, `delete_widget`, `create_view`, `update_view`, `delete_view`, `create_form`, `form_questions_editor`, `update_form`, `update_form_settings`, `update_form_question`, `delete_question`, `create_form_question`, `create_form_tag`, `update_form_tag`, `delete_form_tag`, `activate_form`, `deactivate_form`, `set_form_password`, `shorten_form_url`, `create_update`, `edit_update`, `delete_update`, `like_update`, `unlike_update`, `pin_to_top`, `unpin_from_top`, `create_notification`, `update_notification_setting`, `update_mute_board_settings`, `create_webhook`, `delete_webhook`, `execute_integration_block`, `create_validation_rule`, `update_validation_rule`, `delete_validation_rule`, `create_or_get_tag`, `create_workspace`, `create_team`, `delete_team`, `add_users_to_team`, `remove_users_from_team`, `assign_team_owners`, `remove_team_owners`, `add_users_to_board`, `add_teams_to_board`, `delete_subscribers_from_board`, `delete_teams_from_board`, `add_users_to_workspace`, `add_teams_to_workspace`, `delete_users_from_workspace`, `delete_teams_from_workspace`, `invite_users`, `activate_users`, `deactivate_users`, `update_users_role`, `update_multiple_users`, `update_email_domain`, `create_department`, `update_department`, `delete_department`, `assign_department_members`, `assign_department_owner`, `clear_users_department`, `unassign_department_owners`, `update_directory_resources_attributes`, `create_project`, `convert_board_to_project`, `create_portfolio`, `connect_project_to_portfolio`, `enroll_items_to_sequence`, `create_object_schema`, `update_object_schema`, `delete_object_schema`, `connect_board_to_object_schema`, `create_object_schema_columns`, `update_object_schema_columns`, `set_object_schema_column_active_state`, `detach_boards_from_object_schema`, `bulk_object_schema_column_actions`, `update_object`, `create_object`, `delete_object`, `archive_object`, `publish_object`, `unpublish_object`, `create_object_relations`, `delete_object_relation`, `add_subscribers_to_object`, `create_article`, `publish_article`, `update_article_block`, `delete_article`, `backfill_items`, `ingest_items`, `set_board_permission`.
15. **All cited query names** — same exercise against the read schema.

## Step 4 — Report findings

Output a concise report to the user with this structure:

```
monday-architect skill verification report — <date> (API <release_candidate version>)

✅ <N> facts verified unchanged
⚠️  <N> drifts detected
❌ <N> facts now invalid (mutation/query/enum gone)
🆕 <N> new things in the schema not yet in the skill

Drifts:
- <area>: was "X", now "Y" (impact: <high/medium/low>)
...

Gone:
- <name>: <description>

New (worth adding):
- <name>: <one-line description>
```

Cap the report at ~30 lines. Don't dump full enum lists unless something changed.

## Step 5 — Patch the skill (with user approval)

For each DRIFT and GONE finding:
- Show the exact `Edit` you propose to make to `SKILL.md`.
- Wait for user approval.
- Apply the edit.

For NEW findings, ask the user whether to add them. Don't add silently — new mutations/types are often beta features the user may not want to rely on yet.

After patches are applied, update the "Verified against monday API" line at the top of `SKILL.md`. If that line doesn't exist yet, add one right after the YAML frontmatter:

```markdown
> Last verified end-to-end against the monday MCP on <YYYY-MM-DD> (API release_candidate <version>). Run `/refresh-monday-skill` to re-verify.
```

## Step 6 — If clean, just report and stop

If everything checks out (no DRIFT, GONE, or NEW), output a one-liner:

```
monday-architect verified clean against API <version> on <date>. No changes needed.
```

…and update the "Last verified" line in the skill so the user can see it ran.

## Out of scope

This skill does NOT:
- Re-execute end-to-end build flows (that's Layer 3 — the manual demo dry-run).
- Test webhooks, file uploads, validation rules, or anything that would mutate the live account.
- Verify the skill's *opinionated* content (demo seed-data sizes, cross-product archetypes, anti-patterns) — those are judgment calls, not API facts.

If the user asks "is the skill 100% correct?", the honest answer is: this skill verifies the API surface; it does not verify behavioral changes that introspection can't see (e.g. a mutation that still exists but now requires a permission it didn't before). For that, recommend running the round-2 manual test from the prior chat.
