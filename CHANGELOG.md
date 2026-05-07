# Changelog

All notable changes to the monday-architect skill will be documented here.

## [2026-05-07-patch11] — Editorial cleanup (anti-pattern #40/#46 split, title5 stale reference)

Two small content-integrity fixes from a skill review on 2026-05-07. No new API findings.

### Fixed
- **§22 anti-pattern #40 was an orphan title; #46 had the body of #40 concatenated to its tail.** A patch10 merge artifact left "Creating a `board_relation` column without `boardIds` and assuming it works" with no explanation, and put the explanation at the end of the unrelated dropdown-shape entry. Split cleanly: #40 now contains its own body; #46 stands alone.
- **§25 Round-4 `title5` finding referenced a contradiction with §1.5 that no longer exists.** §1.5 was already corrected in an earlier patch to say "CEO/COO/CIO only", but the Round-4 entry still claimed §1.5 listed Director/Manager/VP/etc. Stripped the stale callout; the rule itself is unchanged.

## [2026-05-07-patch10] — Nidek demo build findings (create_item two-step, permissions, dropdown shape, title5, Round-4)

Verified end-to-end during the Nidek medical device demo build on 2026-05-07. Eight concrete API behaviors that were missing or incorrect in the skill.

### Added
- **`create_item` silently ignores `status` and `date` column values.** Passing these in `columnValues` creates the item but drops the values without error. Two-step pattern is now documented as **mandatory**: `create_item` (name + group only) → `change_item_column_values` (all column values). Applies to both MCP tool and raw GraphQL.
- **`update_status_column` must NOT include `id` in label objects.** The `id` field is read-only; including it returns `ColumnValueException: label id cannot be set manually`. Correct shape: `{label: {name: "X", color: done_green}}`.
- **`allowCreateReflectionColumn: true` does NOT backfill reverse cells.** Creates the reverse column structure but all cells start empty. Must populate manually via `change_item_column_values` on the linked board for each item that needs a reverse link.
- **Failed compound mutations may partially apply.** When `change_item_column_values` fails mid-batch, some values may already be written. Always re-query board state after failure before retrying.
- **`permissions: owners` boards silently drop `board_relation` writes via `change_item_column_values`.** The mutation returns success but cells stay empty. Fix: use raw GraphQL `change_multiple_column_values` via `all_monday_api`.
- **`title5` on native CRM Contacts has only 3 labels: CEO, COO, CIO.** All other labels (Director, Manager, VP, etc.) are rejected by the API. The §1.5 table previously listed additional labels that don't exist.
- **`move_item_to_group` does NOT accept `boardId`.** Passing it causes `"Variable $boardId is never used"`. Args: `itemId` + `groupId` only.
- **Dropdown column value shape is `{"labels": ["X"]}` (plural, array), NOT `{"label": "X"}`.** Using the status shape on a dropdown column silently fails — cell stays empty. Anti-pattern #46 added.

### Fixed
- §1.5 CRM Contacts `title5` column corrected: now shows "CEO/COO/CIO only" with cross-reference to Round-4 findings.
- Anti-patterns updated: #41–#46 added for all Round-4 findings.

## [2026-05-05-patch9] — dashboard two-step, mirror column creation, mandatory column demo note

Verified end-to-end during the Nidek medical device demo build on 2026-05-07.

### Added
- **§7 — `create_dashboard` produces an EMPTY CONTAINER.** Must always follow with `create_widget` calls. An empty dashboard in a demo is a failure. Full two-step workflow documented.
- **§5 — Mirror column creation via `create_column` MCP tool ALWAYS FAILS.** Only working method is raw GraphQL via `all_monday_api` with `defaults` string. Full mutation shape, key rules, and "Column value type is not supported" quirk documented.
- **§5 — Mandatory `board_relation` demo note.** When migrating away from the board a mandatory column pointed at, the column becomes a permanently visible empty artifact. Cannot be deleted or hidden via API — UI-only fix via column chooser.
- Anti-patterns #38–#40 added.

## [2026-05-05-patch8] — `create_column.defaults` correction (board_relation IS API-wirable)

Patch7 incorrectly stated that `board_relation.boardIds` could not be set via the API. **It can — via the `defaults: JSON` argument on `create_column` (raw GraphQL).** Verified end-to-end on `2026-07` by wiring 14 cross-product `board_relation` columns and 27 item-level links during a single demo build.

### Fixed

- **§5 — `board_relation.boardIds` is settable at creation.** The correct mutation:
  ```graphql
  mutation {
    create_column(
      board_id: 12345,
      title: "Customer Account",
      column_type: board_relation,
      defaults: "{\"boardIds\":[67890],\"allowCreateReflectionColumn\":true}"
    ) { id title settings_str }
  }
  ```
  Returned `settings_str` confirms wiring: `"{\"boardIds\":[67890],\"allowCreateReflectionColumn\":true}"`. Subsequent `change_multiple_column_values` writes with `{"item_ids": [...]}` succeed immediately. **Use raw GraphQL via `all_monday_api`** — the MCP `create_column` tool wrapper exposes `columnSettings` (column-type config like status labels), not the `defaults` arg.
- **§5 — Mandatory column workaround.** Some native `board_relation` columns (e.g. `bill_to` on Quotes & Invoices, `board_relation6` on the ITSM Tickets template) are mandatory and cannot be deleted. When you encounter one with empty `boardIds`, add a NEW supplementary `board_relation` column alongside it via `create_column.defaults`. The mandatory empty column stays as a UI artifact; your new column carries the data.
- **§5 — `update_column(settings)` and `change_column_metadata` cannot set `boardIds` AFTER creation.** Both still rejected: `update_column.settings` returns `Column schema validation failed`; `change_column_metadata.column_property` enum exposes only `title` and `description`. So either set boardIds at creation or delete + recreate.
- **§22 #35 — Inverted.** Was: "promising to wire a new `board_relation` without UI assistance". Now: "creating a `board_relation` column with empty boardIds and asking the user to wire it in the UI — wrong, use `create_column.defaults` instead".
- **§24 step 7 — Inverted.** Was a STOP for UI handoff. Now: "for every `board_relation` column you create, use raw GraphQL `create_column` with `defaults: \"{\\\"boardIds\\\":[<target>]}\"`". Native columns ship pre-wired; only NEW columns need the `defaults` arg.
- **§25 round-3 finding — Reversed.** Patch7 cheatsheet claimed boardIds was unsettable; patch8 corrects with the working mutation and notes `update_column` is still broken.

### Verification

- Wired 14 cross-product `board_relation` columns end-to-end via `create_column.defaults`:
  - Native ITSM Tickets → CRM Accounts (`Customer Account`)
  - Native ITSM Tickets → CRM Contacts (`Customer Contact`)
  - CRM Contacts → ITSM Tickets (`Open Tickets`, reverse, `allowCreateReflectionColumn:false` to break the chain)
  - Quotes & Invoices → CRM Contacts (`Recipient Contact` — supplementary, since native `bill_to` is mandatory and empty)
  - Campaigns → CRM Accounts (`Target Accounts`)
  - Campaigns → CRM Leads (`Leads Generated`)
  - Content Calendar → Campaigns (`Campaign`)
- 27 item-level links wired immediately via `change_multiple_column_values` after column creation, all in single batched mutations — no UI handoff needed.

## [2026-05-05-patch7] — cross-product build findings (boardIds, sprint template, update_board)

Verified end-to-end during a full 4-product (CRM + Service + Dev + Campaigns) demo build on 2026-05-05. Six concrete API facts that contradicted or were missing from the skill.

### Added
- **§5 — `board_relation.boardIds` cannot be set via API.** New CRITICAL subsection. `update_column(settings: JSON)` rejects every realistic payload with "Column schema validation failed"; `change_column_metadata.column_property` only accepts `title` and `description`; no other mutation in the schema configures linked boards on a `board_relation` column. The user must configure boardIds in the UI (column header → Settings → Connect boards). After UI config, `{"item_ids": [...]}` writes succeed normally. Native columns (`contact_account`, `task_sprint`, `bug_tasks`, etc.) ship pre-wired and don't hit this. Workaround pattern documented: create column → STOP → list (board, column, target board) triples for user → wait for confirmation → write item links.
- **§1.5 — monday Dev TWO native variants.** Split the Dev section into "Variant A — Simple" (Feature request / Product backlog / Customer feedback / Quarterly goals / PRD template) and "Variant B — Sprint Template" (Sprints / Tasks / Epics / Bugs Queue / Retrospectives / Capacity). Variant B is provisioned via the UI Sprint template, NOT via API. All native column IDs and pre-wired `board_relation` columns documented for both variants.
- **§6 — `update_board` documentation.** Args: `board_id, board_attribute, new_value`. Returns bare JSON — NO `{ id }` selection. `BoardAttributes` enum includes `description`, `name`. Multiple updates in one document need GraphQL aliases.
- **§24 — Execution-order step 7: STOP for boardIds UI handoff.** Renumbered §24 to 15 steps; new explicit step between column creation and item seeding requires Claude to list every (board, column, target board) triple for user UI configuration.
- **§24 — `update_board_hierarchy` documentation.** Args: `board_id, attributes: { workspace_id?, folder_id? }`. Response type `UpdateBoardHierarchyResult { success, message, board }` — NO `id` or `errors` fields. The right tool for moving boards between workspaces or folders mid-build.
- **§3.7 — When to put Campaigns inside the CRM workspace.** New architectural note: for SMB demos where marketing is sourced from CRM Accounts/Leads, a `[Campaigns & Marketing]` folder inside the CRM workspace is cleaner than a separate `marketing_campaigns` workspace.
- **§22 — three new anti-patterns (#35–#37):** promising to wire a new `board_relation` without UI assistance; promising `create_sprint` to provision the engineering sprint board set; selecting `{ id }` on `update_board`.
- **§25 — Round-3 findings cheatsheet:** 11-bullet section consolidating this session's gotchas — boardIds API limitation, missing `create_sprint` mutation, `update_board` bare JSON, `update_board_hierarchy` response shape, `change_column_metadata` enum, `update_column(settings)` validator behavior, harness-blocked `delete_workspace`, mirror columns reading "unsupported" via API, CRM native `board_relation` reads returning null on some accounts, form auto-creating a Name question, no widget read/delete API.

### Fixed
- **§13 — Removed false `create_sprint` claim.** That mutation is not in the API schema as of `2026-07`. Replaced with explicit warning that engineering sprint board set is UI-only (Sprint template) and cross-reference to §1.5 Variant B.
- **§22 — Renumbering broken in patch6.** Two items shared "4." (related-item-ID-in-text and refusing-widget-without-checking-schema). Renumbered the entire list 1–37.
- **§25 — `delete_workspace` claim updated.** Patch6 said "use raw GraphQL via `all_monday_api`". Verified that the MCP harness's Stage 2 safety classifier frequently blocks this mutation; the reliable fallback is UI deletion. The "cascades" note now qualifies "when it runs".
- **§6 — `change_column_metadata` enum clarified.** `column_property` enum has only `title` and `description`. Added cross-reference to §5 for `board_relation.boardIds`.

### Verification
- Verified against API release `release_candidate 2026-07` end-to-end during a real cross-product demo build: created 4 workspaces, ~22 boards (mix of native CRM/Dev/Service + custom), ~140 items with cross-product `board_relation` links, 3 dashboards with NUMBER/CHART/BATTERY/CALENDAR/GANTT widgets, 3 Docs, 2 Forms.

## [2026-05-04-patch6] — contradiction fixes and account-specificity caveat

### Fixed
- **`link_board_items_workflow` contradiction resolved** — removed from §0 introspection table, §22 anti-pattern list, §24 execution step 7, and §26 demo sequence step 6. All four locations previously told Claude to call this non-existent tool as a required precondition before writing `board_relation` columns. §5 and §25 already correctly stated it is not callable and not needed; now the skill is consistent throughout.
- **§22 duplicate numbering** — two items were numbered "3"; renumbered all items from 4 onwards to restore sequential ordering.
- **§1.5 Service section inconsistency** — the "When building Service" schema table previously ended with "create the Tickets board in the Service workspace", contradicting the Case 2 stop rule above it. Now correctly instructs Claude to stop and tell the user to initialise via the UI's "Get started" flow.
- **§2 workspace workflow consolidation** — removed the redundant 5-step pre-build workflow that duplicated §1.5's 8-step Required Workflow; §2 now defers to §1.5 with a quick reference summary.

### Added
- **Account-specific column ID caveat** in CRM section — `connect_boards41` / `connect_boards4` are auto-generated IDs that vary per account; `contact_*`, `deal_*`, `activity_*`, `lead_*` prefixes are stable native conventions. Always resolve actual column IDs via `workspace_info` + `get_board_info`.

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
