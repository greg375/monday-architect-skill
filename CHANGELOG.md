# Changelog

All notable changes to the monday-architect skill will be documented here.

## [2026-05-04-patch1] — workspace-selection fix

### Fixed
- §2 now explicitly requires calling `list_workspaces` before creating any board and matching the chosen product kind to the correct existing workspace. This prevents Claude from building CRM, Dev, or Service boards inside the default Work Management workspace — the most common mis-build pattern found in live testing.

## [2026-05-04] — initial release

First public release.

### Verified
- All 8 monday product kinds (`core`, `crm`, `software`, `service`, `marketing` / `marketing_campaigns`, `project_management`, `forms`, `whiteboard`).
- All 40+ `ColumnType` enum values + verified column ID prefix mappings (e.g. `numbers` → `numeric_*`, `mirror` → `lookup_*`, `status` → `color_*`).
- All 14 verified column-value JSON shapes (status, dropdown, date, timeline, email, phone, link, country, rating, checkbox, people, board_relation, time_tracking, tags).
- All 7 dashboard widget types (`NUMBER`, `CHART`, `BATTERY`, `CALENDAR`, `GANTT`, `LISTVIEW`, `APP_FEATURE`) end-to-end.
- All 16 CHART `graph_type` variants end-to-end.
- All 22 `WebhookEventType` values.
- 11-column native portfolio board structure + portfolio quick-start workflow.
- 14-column native project tasks-board template (auto-created by `create_project`).
- Full mutation/query name set (~50+ verified mutations, ~60+ verified queries).
- Doc block content union, form question types, view kinds, search namespace shape, audit event catalogue, complexity budget shape.

### Gotchas captured
- `link_board_items_workflow` is referenced as a precondition but isn't a callable tool.
- `get_full_board_data` is internal-only.
- `create_subitem` isn't a top-level MCP tool — use `create_item` with `parentItemId`.
- `create_board` doesn't accept a folder ID — must `move_object` afterward.
- `create_form` auto-creates its backing board.
- `create_doc` accepts markdown directly.
- Status `index` field is silently remapped to color ID at storage time.
- Status colors in raw GraphQL are unquoted enums; in `columnSettings` JSON they're quoted strings.
- Phone numbers in column values can't have spaces.
- `archive_group` cascades to its items; the response field `archived: false` is unreliable.
- `solution_live_version_id` from `create_portfolio` is template-shared, NOT the portfolio's board ID.
- `connect_project_to_portfolio` only accepts the lower-numbered tasks board (the parent project board is rejected).
- `create_project` returns `process_id: null` despite docs implying async.
- `delete_workspace` cascades — single call cleans up everything.
- `create_validation_rule` may return "feature not currently supported" depending on account.
- `update_mute_board_settings` with `MUTE_ALL` is owner-only.
