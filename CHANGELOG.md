# Changelog

All notable changes to the monday-architect skill will be documented here.

## [2026-05-04-patch5] — two-case stop rule for missing product workspaces

### Added
- Case 1: product not in `account.products` → stop, give user exact Administration → Products path with per-product message template.
- Case 2: product enabled + workspace exists but is empty (e.g. Service on many accounts) → stop, tell user to open the workspace and click "Get started" to initialise native boards.
- Per-product table: what workspace to look for, which native boards must exist before building, which products require UI initialisation vs MCP-only (`core` is the only one that doesn't require UI first).
- Explicit rule: `core` is the only product where creating boards via MCP without native templates is acceptable.
- Required workflow updated to 8 steps covering both failure modes before any mutation is written.

## [2026-05-04-patch3] — full cross-product architecture + product-not-enabled stop rule

### Changed
- §1.5 completely rewritten as a comprehensive cross-product architecture reference covering all 7 products.

### Added
- **CRM:** verified native board set with exact column IDs, `item_terminology`, status label values, and full relationship wiring map (Leads↔Contacts↔Accounts↔Opportunities deduplication triangle, Activities log, post-sale Onboarding/Finance/Legal links).
- **Dev:** verified native boards from live account: Feature request, Product backlog (with backlog_impact/effort/priority columns), Customer feedback, Quarterly goals, PRD template. Sprint pair system documented (how `task_sprint` works, cross-pair failure mode, `get_monday_dev_sprints_boards` usage).
- **Service:** noted that workspace may be empty on some accounts; documented Tickets + Knowledge Base schema with correct column types; CRM wiring (Contacts + Accounts `board_relation` + mirror).
- **Work Management:** core patterns (projects, tasks, OKR, portfolio); deal-to-project handoff pattern.
- **Projects/Portfolio:** `create_project` two-board fact; `connect_project_to_portfolio` takes tasks board ID; portfolio 11-column native schema.
- **Marketer:** Campaigns/Content Calendar/Briefs/Assets board set with CRM wiring.
- **Full flywheel diagram:** canonical end-to-end Marketer → CRM → Work Management → Dev → Service → CRM renewal flow with wiring instructions.
- **Pre-build checklist:** 7-step mandatory checklist before writing any mutation.
- Core rule elevated: "always use native boards — modify, don't recreate."
- **STOP rule:** if a required product is not enabled or its workspace is missing, the skill now stops and gives the user the exact Administration → Products steps to enable it rather than building generic substitute boards. Covers all 6 products with workspace name mapping.

## [2026-05-04-patch2] — native board catalog + search-before-build rule

### Added
- §1.5 "Native boards — search before you build": verified column schemas for all native CRM boards (Leads, Contacts, Accounts, Opportunities/Deals, Sales Activities, Products & Services, Accounts Management), plus board sets for Dev, Service, and Marketer products. Works on any account, not account-specific.
- Anti-pattern #2: creating CRM/Dev/Service boards from scratch when native boards already exist in the product workspace.
- Rule: call `workspace_info` on the product workspace before `create_board`; use the existing native board if present.

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
