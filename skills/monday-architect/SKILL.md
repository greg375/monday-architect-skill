---
name: monday-architect
description: Use this skill ANY time the user is building, modifying, or reasoning about a monday.com account via the monday MCP connector — workspaces, boards, dashboards, docs, forms, items, columns, widgets, CRM pipelines, Dev sprints, projects/portfolios, Connect Boards / mirrors, formulas, automations/triggers, webhooks, audit logs, integrations, the marketplace, the Objects platform, doc blocks, or anything queryable through the monday GraphQL API. Acts as the operator's manual for the MCP connector and forces correct product/architecture choices. Trigger on any mention of monday.com, monday boards/dashboards/docs, leads/deals/CRM, sprints/epics, item linking, the `mcp__claude_ai_monday_com__*` tool prefix, or monday GraphQL.
version: 2026-05-05-patch8
---

# monday.com architect — operator's manual

You operate the monday.com MCP connector. The user expects builds that use native monday objects, correct typed schemas, and the full advanced API surface — not generic-board workarounds. This skill is your reference. Work through the relevant sections for the task at hand.

> The API facts in this skill (product kinds, column types, board kinds, widget types, webhook events, dashboard visibility, mutation/query names, value shapes, error codes) were verified end-to-end against the monday GraphQL schema and the live MCP connector on **2026-05-05** against API release `release_candidate 2026-07`. Account-specific facts (board IDs, column IDs, group IDs, which products are enabled) MUST come from live MCP calls — never assume.
>
> **To re-verify against your own account and detect drift, run `/refresh-monday-skill`** (sister skill — same repo). Run it monthly, before high-stakes demos, or after any monday API release announcement.
>
> **Behavior may differ by account tier, plan, enabled products, and per-user permissions.** Some mutations cited (e.g. `create_validation_rule`, `update_mute_board_settings` for non-owners, certain bulk-job paths) may return "feature not currently supported" or permission errors depending on your account's configuration. Treat the skill as a map of what *can* exist, not a guarantee of what *will* work for your role.

---

## 0. Always introspect first — never write payloads from memory

Your training data on monday.com is stale. Before designing or executing, query the live system. **Cache the responses for the duration of the task.**

| When | Tool | Why |
|---|---|---|
| Starting any build | `get_user_context` | Account tier, active products on THIS account (subset of: `core`, `crm`, `software`, `service`, `marketing` / `marketing_campaigns`, `project_management`, `forms`, `whiteboard`), favorites, relevant boards/people. Don't assume which products are enabled — check. |
| Choosing where to build | `list_workspaces` (paginated) → `workspace_info(workspace_id)` | Lists boards/docs/folders in a workspace; capped at 100 per object type — paginate or filter |
| Designing data model | `get_graphql_schema(operationType: "read"|"write")` | Authoritative list of queries/mutations + all GraphQL type names |
| Drilling into a type | `get_type_details(typeName)` | Fields, args, enum values for a specific type |
| Creating a column | `get_column_type_info(columnType)` | JSON Schema 7 for column settings — required for `create_column` |
| Updating column values | call `get_column_type_schema` (via `all_monday_api`) or pull from `get_column_type_info` | Per-type value JSON shape — required for `change_item_column_values` |
| Creating widgets | `all_widgets_schema` | Full JSON Schema 7 for every widget type |
| Creating views | call `get_view_schema_by_type` (via `all_monday_api`) | Schema for `create_view` settings parameter |
| Anything not covered by a named tool | `all_monday_api` | Raw GraphQL fallback (validate against `get_graphql_schema` first) |
| Searching existing content | `search` | Global search across boards/items/docs |
| Inspecting a board | `get_board_info` → `get_board_items_page` (paginated, with cursor) | Metadata + items. Do NOT call `get_full_board_data` — it is marked internal-only / UI-triggered. |
| Sprints (Dev) | `get_monday_dev_sprints_boards`, `get_sprints_metadata`, `get_sprint_summary` | Native sprint objects |
| Notetaker | `get_notetaker_meetings` | Meeting transcripts/talking points |

**Rule:** if you're about to write a payload, mutation, column-value JSON, or widget config from memory — stop and call the relevant introspection tool first.

---

## 1. Pick the right product

monday.com is **eight product kinds** (verified via `WorkspacesQueryAccountProductKind`):

| `kind` | Marketing name | Use for |
|---|---|---|
| `core` | Work Management | Generic projects, ops, content, OKRs, tasks |
| `crm` | monday CRM | Leads, contacts, accounts, deals, pipelines, sales activity |
| `software` | monday Dev | Sprints, epics, bugs, releases, roadmaps |
| `service` | monday Service | Tickets, SLA, support queues, customer ops |
| `marketing` / `marketing_campaigns` | monday Marketer | Campaigns, briefs, content calendar |
| `project_management` | monday Projects | Project portfolios, project health, resource planning |
| `forms` | WorkForms | Standalone form-building |
| `whiteboard` | Canvas | Whiteboards |

**Decision rules:**
- "CRM", "leads", "deals", "pipeline", "accounts", "contacts" → `crm`. Never a Status column on a `core` board.
- "Sprint", "epic", "story points", "backlog", "bug tracking" → `software`. Use sprint queries (`sprints`, `get_monday_dev_sprints_boards`, `get_sprint_summary`).
- "Ticket", "SLA", "queue", "first response time" → `service`.
- "Campaign", "creative brief", "content calendar" → `marketing` / `marketing_campaigns`.
- "Portfolio", "program", "cross-project rollup" → see §3 (use **Project + Portfolio**, NOT regular boards with mirrors).
- "Whiteboard", "diagram", "free-form canvas" → `whiteboard`.
- "Standalone form" (no board) → `forms`.
- Default → `core`.

If unsure which products are enabled, call `get_user_context` first — its `account.products` field lists active product kinds.

---

## 1.5 Native boards and cross-product architecture

### The fundamental rule: always use native boards — modify, don't recreate

monday accounts come with **product workspaces pre-provisioned** at signup. Each workspace contains native boards with purpose-specific `item_terminology`, pre-wired `board_relation` columns, native column ID conventions, and built-in views.

**This is the default: use the existing native board. Add groups, columns, or seed data to it. `create_board` is the last resort — only when a board of that type genuinely doesn't exist in the workspace.**

### STOP: if a required product workspace or its native boards are missing

**The MCP cannot provision a product workspace with native boards.** Only the monday.com UI does this when you enable a product. There are two failure modes — handle both:

#### Case 1: Product not enabled at all (`account.products` doesn't contain the kind)

Stop and tell the user:
> "To build a [Product Name] setup, you need to enable the product on your monday.com account first. Go to **monday.com → your avatar → Administration → Products**, enable **[Product Name]**, and come back. This automatically creates the native workspace with all the pre-built boards (Leads, Contacts, Accounts, etc.). I can't create those native boards via the API — they only exist when the product is enabled through the UI."

#### Case 2: Product is enabled, workspace exists, but workspace is empty or missing native boards

Some products (especially `service`) have a workspace provisioned but no boards inside it yet. Stop and tell the user:
> "Your [Product Name] workspace exists but the native boards haven't been set up yet. Open the **[Workspace Name]** workspace in monday.com and click **'Get started'** or use the template picker to initialise the default boards. Once the native boards exist I can start building on top of them."

#### Per-product: what to tell the user and what to look for

| Product kind | Product name | Workspace to find | Native boards that must exist before building |
|---|---|---|---|
| `crm` | monday CRM | "CRM" | Leads, Contacts, Accounts, Opportunities (or Deals), Sales Activities |
| `software` | monday Dev | "Dev" | Feature request, Product backlog, Customer feedback, Quarterly goals |
| `service` | monday Service | "Service" | Tickets (if empty: tell user to initialise via UI) |
| `marketing_campaigns` | monday Marketer | "Marketing" (or "Marketing Campaigns") | Campaigns, Content Calendar |
| `project_management` | monday Projects | Uses existing `core` workspace | No separate workspace — but requires `create_project` / `create_portfolio` mutations |
| `core` | Work Management | "Main workspace" (or any named workspace) | Project/task boards — these can be created via MCP if absent |

**`core` is the only product where creating boards via MCP without native templates is acceptable** — Work Management boards have no fixed native structure. All other products have native boards that must come from the UI first.

### Required workflow before creating any board

1. Call `get_user_context` — check `account.products` for enabled product kinds.
2. **If the required product kind is absent → Case 1 stop** (tell user to enable via Administration → Products).
3. Call `list_workspaces` — find the workspace for the target product.
4. **If the workspace is missing → Case 1 stop** (same message — product likely not enabled).
5. Call `workspace_info(workspace_id)` — scan all folders and boards.
6. **If the workspace exists but has no native boards → Case 2 stop** (tell user to initialise via the workspace's Get Started flow).
7. **If native boards exist → use them.** Add items/groups/columns. Do not duplicate.
8. **Only `create_board` if a specific board type is genuinely absent from an already-initialised workspace** — and only in the correct product workspace.

---

### monday CRM (`crm` workspace) — verified native board set

The CRM workspace provisions these boards. Every monday CRM account has them.

| Board | `item_terminology` | Key native column IDs | Cross-wired to |
|---|---|---|---|
| **Leads** | `Lead` | `lead_status` (status: New Lead/Attempted to contact/Contacted/Qualified/Unqualified), `lead_email` (email), `lead_phone` (phone), `lead_company` (text), `lead_owner` (people), `date` (Last activity), `location5` (location), `long_text` (Comments) | Contacts (duplicate detector), Accounts (existing account detector) |
| **Contacts** | `Contact` | `contact_email` (email), `contact_phone` (phone), `contact_company` (text), `contact_account` (board_relation → Accounts), `contact_deal` (board_relation → Opportunities), `status` (Type: Customer/Vendor/Partner/VIP/N/A), `title5` (dropdown: CEO/COO/CIO/Director/Manager/VP/Team Member/C Level/), `date` (Last interaction), `location` (location) | Accounts, Opportunities, Leads |
| **Accounts** | `Account` | `company_domain` (link), `industry` (dropdown — 51 standard industry values), `status` (Account Status: Buying process/Client/Past Client), `account_contact` (board_relation → Contacts), `account_deal` (board_relation → Opportunities), `mirror` (Account Value — SUM mirror of Won deal values), `employee_count` (text), `headquarters_loc` (text) | Contacts, Opportunities, Projects (post-sale) |
| **Opportunities / Deals** | `Opportunity` | `deal_stage` (status: New/Discovery/Proposal/Negotiation/Legal/Won/Lost), `deal_value` (numbers $), `deal_owner` (people), `deal_expected_close_date` (date), `deal_close_date` (date), `deal_contact` (board_relation → Contacts), `deal_close_probability` (formula % from stage), `deal_forecast_value` (formula: value × probability), monthly actual formulas (Jan–Dec), `deal_length` (formula), `dup__of_deal_age` (stage length formula) | Contacts, Accounts, Legal, Onboarding/Finance |
| **Sales Activities** | `Activity` | `activity_item` (board_relation → Leads/Contacts/Accounts/Opportunities/Activities), `activity_owner` (people), `activity_start_time` / `activity_end_time` (date), `activity_status` (status: Open/Done), `activity_type` (status: Meeting/Call summary), `long_text` (Description) | All CRM boards (unified activity log) |
| **Products & Services** | `Product` | Product/pricing catalog linked to Opportunities | Opportunities |
| **Accounts Management / Onboarding** | `Client` | Post-sale project tracker — cross-wired to Accounts and Opportunities | Accounts, Opportunities, Projects |

**CRM relationship wiring (all pre-built on a native CRM workspace):**
- Leads ↔ Contacts: duplicate email detector via `board_relation` + status indicator ("New Contact" / "Existing Contact")
- Leads ↔ Accounts: duplicate company detector via `board_relation` + status indicator ("New Account" / "Existing Account")
- Contacts ↔ Accounts: primary relationship — `contact_account` column links each contact to their account
- Contacts ↔ Opportunities: `contact_deal` column — deal history per contact
- Accounts ↔ Opportunities: `account_deal` + `mirror` (Account Value) — all deals visible on the account
- Accounts → Onboarding: `link_to_accounts_management` — won deal → onboarding project
- Opportunities → Legal: `board_relation` column (ID varies by account, e.g. `connect_boards41`) → Legal Requests board
- Opportunities → Finance/Invoices: `board_relation` column (ID varies by account, e.g. `connect_boards4`) → Finance & Collections board

> **Column ID caveat:** The `contact_*`, `deal_*`, `activity_*`, `lead_*` prefixes are stable native conventions. Columns like `connect_boards41` / `connect_boards4` are auto-generated IDs that vary per account — always call `workspace_info` + `get_board_info` to resolve the actual column IDs on the target account before writing payloads.

**When building CRM:** seed the existing native boards. Groups represent pipeline stages (e.g. "Working pipeline" / "Closed Won" / "Lost"). Do not create new Lead/Contact/Account/Deal boards.

---

### monday Dev (`software` workspace) — TWO native variants

The Dev workspace can be initialised in two distinct ways depending on which template the user picks in the UI. **Both produce native boards. Identify which variant the account has via `workspace_info` before designing.**

#### Variant A — "Simple" Dev setup (Feature-request-driven)

Provisioned when the user picks the basic Dev template:

| Board | `item_terminology` | Key columns | Purpose |
|---|---|---|---|
| **Feature request** | `Request` | `color_*` (Type: New feature/Feature improvement/Performance improvement), `long_text_*` (request + why), `email_*` (user email), `button` (To prioritize?) | External intake — comes with a Form view pre-built |
| **Product backlog** | `Feature` | `assignee` (people), `backlog_timeline` (timeline), `status` (Ideation/Ready for dev/Dev in progress/Done/Stuck/Deprioritized), `backlog_impact` (High/Medium/Low), `backlog_effort` (XL/L/M/S), `backlog_priority` (Critical/High/Medium/Low), `backlog_files` (file — for PRD attachment) | Quarterly planning with Gantt + Roadmap views |
| **Customer feedback** | `Feedback` | `status` (Not read/To follow-up/Treated), `rating_*` (rating), `long_text_*` (what to improve), `dropdown_*` (Tags), `email_*` (user email) | External feedback — comes with a Form view pre-built |
| **Quarterly goals** | `Goal` | `person` (people/Owners), `numeric_*` (Q start/Q goal/Q current — all %), `formula_*` (% of goal achieved) | OKR/goal tracking with Goal progression + Hierarchy views |
| **PRD template** | `item` | `files` (file) | Product requirements doc — uses FeatureBoardView (Doc app) |

#### Variant B — "Sprint Template" setup (Engineering team)

Provisioned when the user adds the **sprint template** in the UI (`Workspace → Add → Templates → Sprint`). This is what most engineering teams actually want:

| Board | `item_terminology` | Key columns | Purpose |
|---|---|---|---|
| **Sprints** | `Sprint` | `sprint_goals` (long_text), `sprint_timeline` (timeline), `sprint_start_date` / `sprint_end_date` (date), `sprint_capacity` (numeric), `sprint_tasks` (board_relation → Tasks), `sprint_activation` (status — `v` is Active), `sprint_completion` (checkbox) | Sprint container — one item per sprint |
| **Tasks** | `Task` | `task_owner` (people), `task_status` (status), `task_priority` (status), `task_type` (status — Bug/Feature/Test), `task_estimation` / `task_actual_effort` (numeric — hours or points), `task_epic` (board_relation → Epics), `task_sprint` (board_relation → Sprints) | Sprint task list |
| **Epics** | `Epic` | `epic_owner` (people), `timeline` (timeline), `epic_status` (status — In Progress/Planned/Backlog), `epic_priority` (status — Critical/High/Medium/Low), `epic_tasks` (board_relation → Tasks), `monday_doc_v2` (doc) | Quarterly epic planning |
| **Bugs Queue** | `Bug` | `people1` (Reporter), `bug_status` (status — Open/In Progress/Done/Pending Deploy/etc), `priority_1` (status), `time_tracking` (Time until resolution), `bug_tasks` (board_relation → Tasks) | Bug intake & triage |
| **Retrospectives** | `Retrospective` | (varies — typically `what_went_well`, `what_didnt`, `action_items`) | Sprint retro notes |
| **Capacity** | `Capacity` | (varies — typically `person`, `available_hours`, `sprint_link`) | Per-person sprint capacity |
| **Getting Started** | (doc) | — | Auto-generated walkthrough doc |

**⚠️ `create_sprint` mutation does NOT exist in API release `2026-07`.** Verified by full schema introspection. The skill has historically claimed this mutation creates the paired Sprints/Tasks boards — that is wrong for the current API.

**The native sprint board set must be provisioned via the UI.** If the user wants engineering sprint workflow:
1. Tell them to open the Dev workspace → Add → Templates → **Sprint** in the monday UI.
2. Wait for them to confirm the boards exist.
3. Then use `workspace_info` to get the auto-generated board IDs (Sprints, Tasks, Epics, Bugs Queue).
4. Seed sprints by creating items on the **Sprints** board directly. Add tasks via `create_item` on the Tasks board with `task_sprint: {item_ids: [<sprint_item_id>]}` and `task_epic: {item_ids: [<epic_item_id>]}`.

**Querying sprint state:**
- `get_monday_dev_sprints_boards` — find sprint board pairs (works for both variants).
- `get_sprints_metadata` — sprint definitions on a board.
- `get_sprint_summary` — burnup/burndown/summary for a sprint.

**Native cross-board wiring (sprint template):**
- `task_sprint` (Tasks → Sprints): pre-wired with `boardIds` set
- `task_epic` (Tasks → Epics): pre-wired
- `epic_tasks` (Epics → Tasks): pre-wired (reverse side, auto-populated)
- `bug_tasks` (Bugs Queue → Tasks): pre-wired
- `sprint_tasks` (Sprints → Tasks): pre-wired (reverse side)

These all ship with `boardIds` configured — you do NOT hit the §5 boardIds limitation when using these native columns. **Don't recreate them — use them.**

**Dev board relationships (logical flow):**
- Feature request → Product backlog (Variant A) OR Bugs Queue → Tasks (Variant B): the intake → work conversion
- Product backlog / Tasks → Sprint: pulled in via `task_sprint`
- Customer feedback / Bugs Queue → Tasks: feedback/bug informs sprint priority
- Quarterly goals → Epics: goals link to epics in the active quarter
- **CRM → Dev link:** Variant A uses Customer feedback ↔ CRM Accounts. Variant B has no built-in CRM link — add a `board_relation` from Bugs Queue or Tasks to CRM Accounts manually (and remember §5: the user must configure `boardIds` in the UI).

---

### monday Service (`service` workspace) — native board set

The Service workspace may be **empty on some accounts** (not always seeded at signup). When building Service:

| Board | `item_terminology` | Key columns to create | Purpose |
|---|---|---|---|
| **Tickets** | `Ticket` | `status` (New/Open/In progress/On hold/Resolved/Closed), `priority` (status: Critical/High/Medium/Low), `ticket_type` (status: Bug/Question/Feature/Other), `assignee` (people), `reporter` (people), `due_date` (date), `sla_breach` (formula or date), `contact` (board_relation → CRM Contacts), `account` (board_relation → CRM Accounts) | Core support queue |
| **Knowledge Base** | `Article` | `category` (dropdown), `status` (Draft/Review/Published), `assignee` (people), `related_ticket` (board_relation → Tickets) | Self-service docs, links to ticket patterns |
| **SLA Policies** | `Policy` | SLA tiers with response/resolution time targets | Reference board for SLA formula logic |

**Service ↔ CRM wiring (critical for demos):**
- Tickets link to CRM Contacts (`board_relation`) — the support agent sees who the customer is
- Tickets link to CRM Accounts — account-level support volume visible on Account board via `mirror`
- Won deals in Opportunities trigger ticket creation (via automation/webhook)

**If the Service workspace is empty:** follow the Case 2 stop rule above — tell the user to open the Service workspace and click "Get started" to initialise the native boards. The schema above is the reference for what to expect once they do. Do NOT create a Tickets board manually; the native board comes with pre-built views, SLA integrations, and form intake that a manually-created board won't have.

---

### monday Work Management (`core` workspace — typically "Main workspace") — native board set

The core workspace is for projects, tasks, ops, OKRs. It is **not** for CRM, Dev, or Service entities.

Native patterns (not fixed templates — varies by account):
- **Project boards** — timeline, owner, status, priority, dependency columns
- **Task boards** — linked to project board via `board_relation`
- **Resource planner** — auto-created alongside project boards when using `create_project`
- **OKR / Goals board** — company/department/team goal hierarchy
- **Portfolio** — created via `create_portfolio` + `connect_project_to_portfolio` (NOT a regular board)

**Work Management ↔ CRM wiring (the "deal-to-project" handoff):**
- Won Deal → create a Project in Work Management (most valuable cross-product flow)
- Project board → link back to Account and Deal in CRM
- Project milestones → Service tickets (issue tracking for deliverables)

---

### monday Projects (`project_management`) — Portfolio architecture

`project_management` is a **layer on top of core boards**, not a separate workspace. It adds:
- **`create_project`** → generates TWO boards: a parent project board + a tasks board with a 14-column native template
- **`create_portfolio`** → generates a portfolio board with 11 native columns (health, progress mirror, timeline mirror, etc.)
- **`connect_project_to_portfolio`** → takes the **tasks board ID** (lower-numbered), not the parent project board ID

Portfolio board native columns: `portfolio_project_owner` (people), `portfolio_project_rag` (status: At risk/On track/Off track), `portfolio_project_progress` (mirror — auto-rollup of `project_status`), `portfolio_project_priority` (Critical/High/Medium/Low), `portfolio_project_step` (Upcoming/In progress/Completed), `portfolio_project_planned_timeline` (timeline), `portfolio_project_actual_timeline` (mirror — rollup of `project_timeline`), `portfolio_project_doc` (doc), `portfolio_project_scope` (text), `portfolio_project_link` (board_relation to all connected projects).

---

### monday Marketer (`marketing_campaigns` workspace)

Native board set (varies by account — always check `workspace_info` first):

| Board | `item_terminology` | Key columns | Purpose |
|---|---|---|---|
| **Campaigns** | `Campaign` | `status` (Planning/Active/Completed/Paused), `owner` (people), `timeline` (timeline), `budget` (numbers $), `channel` (dropdown), `target_audience` (text) | Campaign pipeline |
| **Content Calendar** | `Content` | `status`, `channel` (dropdown), `publish_date` (date), `assignee` (people), `campaign` (board_relation → Campaigns) | Editorial calendar — use Calendar view |
| **Briefs** | `Brief` | `status`, `campaign` (board_relation → Campaigns), `assignee` (people), `due_date` (date) | Creative brief + Doc column for brief content |
| **Assets** | `Asset` | `file` (file column), `status`, `campaign` (board_relation) | Creative asset management |

**Marketer ↔ CRM wiring:**
- Campaigns link to CRM Accounts (target accounts for ABM campaigns)
- Campaign leads → CRM Leads board (form submissions flow in)
- Campaign performance dashboards pull from both Campaigns board + CRM deal data

**When to put Campaigns inside the CRM workspace instead:** for SMB demos where the marketing team is the same people as the sales team, or where every campaign target list is sourced from the CRM Accounts/Leads, the cleanest setup is a `[Campaigns & Marketing]` folder **inside the CRM workspace** (not a separate Marketing workspace). This keeps the cross-board navigation natural — every Account is one click from the campaigns targeting it. Build a separate `marketing_campaigns` workspace only when the marketing team is functionally distinct (different users, different cadence, different reporting) — typical at companies of 50+ FTEs.

---

### Cross-product architecture: the full monday flywheel

The most powerful monday demos show how all products form a single connected system. The standard end-to-end flow:

```
[Marketer] Campaign → Lead Form
        ↓
[CRM] Lead → Contact → Account → Opportunity (Deal)
        ↓ (Deal Won)
[Core/Projects] Project created → tasks assigned → milestones
        ↓
[Dev] Feature requests from customer → Product backlog → Sprint
        ↓
[Service] Support ticket → resolved → linked back to Account
        ↓
[CRM] Account Value updated via mirror → renewal opportunity created
```

**How to wire it via MCP:**
1. CRM → Projects: add a `board_relation` from Opportunities to a Work Management project board. When a deal is won, create a project item and link it.
2. CRM → Service: add a `board_relation` from CRM Accounts to Tickets board. Use a `mirror` on Account to show open ticket count.
3. Dev → CRM: Customer feedback board has a `board_relation` to CRM Accounts — enabling ARR-weighted feature prioritization.
4. Projects → Dev: sprint tasks can link back to project milestones via `board_relation`.
5. Any product → Dashboard: cross-product dashboards pull widgets from boards across all workspaces.

**Dashboard as the cross-product lens:**
Dashboards are workspace-scoped in creation but widgets can pull from boards in any workspace. Always build at least one cross-product dashboard for demos: CRM pipeline funnel + open tickets + active sprints + project health — on a single dashboard.

---

### Build checklist for any product build

Before writing any mutation:

- [ ] `get_user_context` — confirm which products are enabled on this account
- [ ] `list_workspaces` — find the workspace for each product you'll build in
- [ ] `workspace_info(workspace_id)` for each target workspace — find existing native boards
- [ ] For each entity you need: use existing board if present, create only if absent
- [ ] Place new boards in the correct product workspace, organised into folders
- [ ] Wire cross-product `board_relation` columns for any flow that spans products
- [ ] Build a cross-product dashboard showing the full flow

---

## 2. Workspaces and folders

- **Workspace** — top-level scope. `WorkspaceKind`: `open`, `closed` (enterprise-only), `template`.
  - Tools: `create_workspace`, `update_workspace`, `list_workspaces`, `workspace_info`.
  - Filter workspaces by product via `WorkspacesQueryInput.kind` (raw GraphQL).
- **Folder** — group related boards/dashboards/docs inside a workspace.
  - Tools: `create_folder` (16-color enum: `AQUAMARINE`, `BRIGHT_BLUE`, `BRIGHT_GREEN`, `CHILI_BLUE`, `DARK_ORANGE`, `DARK_PURPLE`, `DARK_RED`, `DONE_GREEN`, `INDIGO`, `LIPSTICK`, `NULL`, `PURPLE`, `SOFIA_PINK`, `STUCK_RED`, `SUNSET`, `WORKING_ORANGE`; plus `customIcon` and `fontWeight` enums), `update_folder`, `move_object`.
  - **`create_board` does NOT take a folder ID** — boards land at workspace root. After creating, call `move_object` with `objectType: "Board"`, `id: <boardId>`, `parentFolderId: <folderId>`. (Verified end-to-end.)
  - `workspace_info` returns up to 100 of each object type per workspace; paginate for larger.
- Use folders. Don't dump 20 boards at the workspace root.
- Naming: prefix related objects (`[Sales] Leads`, `[Sales] Deals`, `[Sales] Accounts`) so they cluster in lists and search.

### CRITICAL: Match product kind to the correct existing workspace

**Before creating any board, you MUST identify the right workspace for the chosen product kind.** Do NOT create a generic `open` workspace and build everything there. Follow the 8-step Required Workflow in §1.5 — it covers workspace identification, native-board discovery, and the two STOP cases.

Quick reference: CRM boards → "CRM" workspace; Dev boards → "Dev" workspace; Service boards → "Service" workspace; Work Management → `core` workspace (typically "Main workspace"). Pass `workspace_id` to `create_board`.

**Anti-pattern to refuse:** building CRM, Dev, or Service boards inside the default Work Management workspace. monday.com maintains product-specific workspaces with native context (column templates, views, integrations). Boards placed in the wrong workspace lose that context and are harder for end-users to find.

---

## 3. Pick the right object type

| User wants… | Build | Tool |
|---|---|---|
| Generic project / task list | **Board** (kind: `public` / `private` / `share`) | `create_board` |
| Hierarchical work in one board | **Sub-items** | `subitems` / `subtasks` column on the board |
| Cross-board project rollup / portfolio | **Project + Portfolio** (NOT regular board + mirrors) | `convert_board_to_project`, `create_project`, `create_portfolio`, `connect_project_to_portfolio` (raw GraphQL — see §3.5 for verified arg shapes) |
| Narrative content (PRD, meeting notes, wiki, SOP) | **Doc** | `create_doc` (NOT a long-text column) |
| Intake from humans | **Form** bound to a board | `create_form`, `form_questions_editor`, `update_form`, `get_form` |
| Cross-board visualization | **Dashboard + widgets** | `create_dashboard`, `create_widget` |
| Sprint/epic tracking | **Dev sprint board** | Native `software` workspace + sprint queries |
| Saved view of a board | **View** (table or app-embed only — see note) | `create_view`, `update_view`, `delete_view`; pre-fetch `get_view_schema_by_type(type: <ViewKind>, mutationType: CREATE)` |
| Reusable column definitions | **Managed column** | `create_status_managed_column`, `create_dropdown_managed_column`, then update/activate/deactivate/delete |

**Important:** the `BoardKind` enum exposes only `private` / `public` / `share` — visibility, not template type. There is NO "portfolio board kind". Portfolios are built from **Projects** (`create_project` / `create_portfolio` / `connect_project_to_portfolio`) — a separate object hierarchy. To convert an existing board into a project, use `convert_board_to_project`.

### 3.5 Project & Portfolio mutation shapes (verified end-to-end)

- **`create_project(input: CreateProjectInput!)`** — `input` fields: `name` (required), `board_kind` (required: `public`/`private` — `share` not supported), optional `template_id`, `companions: ["resource_planner"]`, `workspace_id`, `folder_id`, `callback_url`. Returns `CreateProjectResult { success, message, error, process_id }`. **In practice `process_id` came back as `null`** despite the docs implying async — the project boards appear in the workspace immediately. Possibly synchronous-but-callback-supported.
  - **Each `create_project` call produces TWO boards:** a parent project board + a tasks board with **2 seed tasks (Task 1, Task 2) and a 14-column native template**: `project_owner` (people), `project_resource` (board_relation), `project_status` (status), `project_priority` (status), `project_timeline` (timeline), `project_dependency` (dependency), `project_planned_effort`/`project_effort_spent`/`project_duration`/`project_budget` (numbers), `project_task_completion_date` (date), `subtasks_*` (subtasks), and a back-link `board_relation` to the parent.
  - **Of those two boards, only the lower-numbered (tasks) board IS "the project"** for `connect_project_to_portfolio` — the higher-numbered parent board is NOT recognized. Verified error: `"Failed to connect project to portfolio. the following boards are not projects: [<parent_id>]"`.
  - To find the project's task-board ID, query `boards(workspace_ids: [...])` after creation — both auto-generated boards share the project name.
- **`create_portfolio(boardName: String!, boardPrivacy: String!, destinationWorkspaceId: Int)`** — note `destinationWorkspaceId` is `Int` (despite IDs elsewhere being strings). Returns `CreatePortfolioResult { success, message, solution_live_version_id }`. **The `solution_live_version_id` is the version ID of the underlying portfolio TEMPLATE — it's the same for every portfolio you create. It is NOT the portfolio's board ID.** Query `boards(workspace_ids: [...])` after creation to find the new portfolio board (named with `boardName`).
- **Portfolio board structure (verified — 11 native columns):** `name`, `portfolio_project_owner` (people), `portfolio_project_rag` (status — Project Health, default labels: At risk / On track / Off track), `portfolio_project_progress` (mirror — auto-rolls up `project_status` from connected tasks boards), `portfolio_project_priority` (status — Critical/High/Medium/Low), `portfolio_project_step` (status — Stage: Upcoming/In progress/Completed), `portfolio_project_planned_timeline` (timeline), `portfolio_project_actual_timeline` (mirror — auto-rolls up `project_timeline`), `portfolio_project_doc` (doc), `portfolio_project_scope` (text — Description), `portfolio_project_link` (board_relation to all connected projects).
- **`connect_project_to_portfolio(projectBoardId: ID!, portfolioBoardId: ID!)`** — both are board IDs. Returns `ConnectProjectResult { success, message, portfolio_item_id }`. **Side effects:**
  - Creates a new item on the portfolio board (one item per project) — the `portfolio_item_id` returned is that item.
  - Adds the project's tasks board ID to `portfolio_project_link.boardIds` (the board_relation column's settings).
  - Wires the mirror columns' `displayed_linked_columns` to point at `project_status`/`project_timeline` on the connected boards.
  - **However**, the `portfolio_project_link` value on each portfolio item is initially null — you may need to populate it manually if the mirrors don't auto-resolve (test in the UI). The `connect_project_to_portfolio` mutation appears to wire structure but not item-level links.
- **`convert_board_to_project(input: ConvertBoardToProjectInput!)`** — async, returns `ConvertBoardToProjectResult` with a `process_id`. **`column_mappings` is REQUIRED** with three required fields: `project_status` (column ID), `project_timeline` (column ID), `project_owner` (column ID — note `"name"` is accepted as a stand-in for the name column). Cannot pass an empty `column_mappings: {}`.

### 3.6 Portfolio quick-start (the demo flow)

To set up a populated portfolio with two connected projects in one go:
1. `create_workspace(name, workspaceKind: "open")` → grab `workspace_id`.
2. `create_portfolio(boardName: "...", boardPrivacy: "public", destinationWorkspaceId: <int>)`.
3. `create_project(input: {name: "Project A", board_kind: public, workspace_id: "..."})` × N projects.
4. Query `boards(workspace_ids: [...])` to find: portfolio board ID, and each project's TWO board IDs. The lower-numbered one of each project is the tasks board (the "real" project).
5. `connect_project_to_portfolio(projectBoardId: <tasks_board_id>, portfolioBoardId: <portfolio_id>)` × N projects.
6. Populate the portfolio item columns (`portfolio_project_rag`, `portfolio_project_priority`, `portfolio_project_step`, `portfolio_project_planned_timeline`, `portfolio_project_scope`, `portfolio_project_owner`) on each portfolio item via `change_item_column_values` with `createLabelsIfMissing: true`.
7. Add real tasks to each project tasks board so the mirror columns have data to roll up.

---

## 4. Column model — the typed schema layer

Verified `ColumnType` enum (use these strings, not UI labels):

`auto_number`, `board_relation`, `button`, `checkbox`, `color_picker`, `country`, `creation_log`, `date`, `dependency`, `doc`, `direct_doc`, `dropdown`, `email`, `file`, `formula`, `hour`, `integration`, `item_assignees`, `item_id`, `last_updated`, `link`, `location`, `long_text`, `mirror`, `numbers`, `people`, `phone`, `progress`, `rating`, `status`, `subtasks`, `tags`, `team`, `text`, `timeline`, `time_tracking`, `vote`, `week`, `world_clock`. Plus `name`, `group`, `unsupported` (system-only). `person` is **deprecated** — use `people`.

Pick by intent:

| Need | Column |
|---|---|
| Workflow stages with fixed labels & colors | `status` |
| Multi-select tags from fixed list | `dropdown` |
| Free text / long text | `text` / `long_text` |
| Date / date+time | `date` |
| Time range | `timeline` |
| Calendar week | `week` |
| Time of day | `hour` |
| Assignee (person/team) | `people` (NEVER `person` — deprecated) |
| Whole-team assignment | `team` |
| Currency / count / score | `numbers` |
| File attachments | `file` |
| Hyperlink | `link` |
| Email / phone (with click-to-action) | `email` / `phone` |
| Cross-board relationship | `board_relation` (NOT `text`) |
| Surfaced value from related item | `mirror` |
| Computed value | `formula` |
| Auto-incrementing ID | `auto_number` / `item_id` |
| Created by + when | `creation_log` |
| Last updater + when | `last_updated` |
| Vote / rating / progress battery | `vote` / `rating` / `progress` |
| Geolocation | `location` |
| World clock | `world_clock` |
| Country | `country` |
| Item dependencies | `dependency` |
| Sub-tasks | `subtasks` |
| Doc embed | `doc` / `direct_doc` |
| Action button on the row | `button` |
| Time tracking widget | `time_tracking` |
| Cross-board tag | `tags` |
| Color swatch (design system) | `color_picker` |
| Item-level checkbox flag | `checkbox` |
| Auto-aggregate of all assignees | `item_assignees` |

Workflow:
1. `create_column` to add a column. For `status` and `dropdown`, prefer **managed columns** (`create_status_managed_column` / `create_dropdown_managed_column`) when the same labels should be reusable across boards. Managed-column IDs are UUIDs (e.g. `debd05ab-5c5b-4a6e-9760-35b07a9b4dd1`), not the usual `prefix_xxx`.
2. **Column ID prefix doesn't match the type name (verified):** column IDs are auto-assigned by the API and DO NOT use the `columnType` enum string. Common mismatches: `numbers` → `numeric_*`, `creation_log` → `pulse_log_*`, `mirror` → `lookup_*`, `status` → `color_*`, `people` → `multiple_person_*`, `timeline` → `timerange_*`, `time_tracking` → `duration_*`, `tags` → `tag_*`, `checkbox` → `boolean_*`. Match these patterns when constructing columnValues payloads.
3. **`columnSettings` for `create_column` must be UNWRAPPED** — pass the inner contents only. `get_column_type_info` returns a schema like `{schema: {properties: {settings: {properties: {labels: ...}}}}}` — the `settings` wrapper there is descriptive, NOT literal. Send `{"labels": [...]}` directly, NOT `{"settings": {"labels": [...]}}`. (Verified — sending the wrapped form throws `must NOT have additional properties`.)
4. To set a value on an item via the MCP `change_item_column_values` tool (the wrapper), use these verified value shapes — column-value JSON is *NOT* the same as column-settings JSON:
   - `text` / `long_text`: plain string
   - `numbers`: bare number (not wrapped)
   - `status`: `{"label": "..."}`
   - `dropdown`: `{"labels": ["..."]}` (note: plural `labels`, array)
   - `date`: `{"date": "YYYY-MM-DD", "time"?: "HH:MM:SS"}`
   - `timeline`: `{"from": "YYYY-MM-DD", "to": "YYYY-MM-DD"}`
   - `email`: `{"email": "...", "text": "..."}`
   - `phone`: `{"phone": "+digitsonly", "countryShortName": "DE"}` (no spaces in the phone string)
   - `link`: `{"url": "...", "text": "..."}`
   - `country`: `{"countryCode": "DE", "countryName": "Germany"}`
   - `rating`: `{"rating": 1..5}`
   - `checkbox`: `{"checked": "true" | "false"}` (string-typed booleans)
   - `people`: `{"personsAndTeams": [{"id": <int>, "kind": "person"|"team"}]}`
   - `board_relation`: `{"item_ids": [<int>, ...]}`
   - `time_tracking`: `{"running": <bool>, "startDate": <unix_ts>, "duration": <seconds>}`
   - `tags`: `{"tag_ids": [<int>, ...]}`
   When in doubt for an unfamiliar column type, call `get_column_type_info` for the schema, then sanity-check by reading an existing item's value via `get_board_items_page` with `includeColumns: true`.
5. **`createLabelsIfMissing: true`** on `change_item_column_values` allows writing a status/dropdown label that doesn't exist yet — without it, you get `extensions.code = "ColumnValueException"` with `column_validation_error_code = "missingLabel"`. (Verified.)
6. **Status `index` field gotcha (raw GraphQL):** when creating a status column with explicit indexes, the API stores labels keyed by the **color ID** (the `StatusColumnColors` numeric value), NOT the `index` field you provide. So a label you created with `index: 0` and `color: "american_gray"` is stored at key `17` (the ID of `american_gray`). When using `change_simple_column_value` with an integer index, you must use the **color ID**, not your assigned index. The `change_item_column_values` MCP tool with `{"label": "..."}` avoids this entirely — prefer label-based writes.
7. **In raw GraphQL, status colors are an enum, not a string** — write `color: done_green` (unquoted) inside a mutation, NOT `color: "done_green"`. The MCP `create_column` wrapper accepts strings via `columnSettings` because it serializes JSON, but `all_monday_api` calls into mutations like `create_status_managed_column` need raw enum syntax.
8. To update column-level metadata (e.g., status labels, dropdown options), use `update_status_column`, `update_dropdown_managed_column`, etc.

---

## 5. Cross-board relationships (`board_relation` + `mirror`)

The single biggest design pitfall. Rules:

1. **`board_relation` columns** link items across boards. Never store a related-item ID in a `text` column.
2. **`mirror` columns** surface fields from the linked item. Mirrors are the join — without them you cannot report across boards.
3. **Bidirectional**: add a `board_relation` on each side if both directions need to navigate or report.
4. Mirror columns are **read-only** and have filtering/aggregation limits in some widgets — design around this. If you need heavy filtering on a mirrored value, denormalize via a `formula` or an automation-populated column.
5. For very large many-to-many relationships, use a join board.

### ✅ Setting `boardIds` on `board_relation` columns — use `create_column.defaults`

**The single most under-documented mutation arg in the monday API.** `create_column` accepts a `defaults: JSON` argument that lets you set `boardIds` at column-creation time. Verified end-to-end on `2026-07`:

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

The returned `settings_str` confirms the wiring: `"{\"boardIds\":[67890],\"allowCreateReflectionColumn\":true}"`. After that, `change_multiple_column_values` with `{"item_ids": [...]}` works immediately.

**Important caveats (verified):**
- `defaults` is a top-level argument on `create_column`, NOT inside `columnSettings`. The MCP `create_column` tool wrapper exposes `columnSettings` for column-type config (e.g. status labels), but you must use raw GraphQL via `all_monday_api` to access the `defaults` argument for `board_relation`.
- `defaults` works for `board_relation` boardIds. It may also work for other column types' initial config — test before assuming.
- Pass the JSON as a string (escape inner quotes), since `defaults` is typed `JSON` (scalar, accepts string).
- Set `allowCreateReflectionColumn: true` so the reverse-side column gets auto-created on the linked board (typical CRM-style behavior).
- For the reverse column on the OTHER side, create a second `board_relation` column with `defaults: {boardIds:[<this board>], allowCreateReflectionColumn:false}` to avoid an infinite reflection chain.

#### What does NOT work (also verified)

`update_column(settings: JSON)` and `change_column_metadata` cannot set `boardIds` AFTER creation:
- `update_column` with `settings: "{\"boardIds\":[...]}"` returns `"Column schema validation failed"` (every JSON shape rejected).
- `change_column_metadata.column_property` enum has only `title` and `description`. No `settings` / `boardIds` option.

**Therefore: if a `board_relation` column already exists with empty `boardIds`** (`settings_str: "{}"`), you must:
1. `delete_column` it (if non-mandatory)
2. Recreate via `create_column` with `defaults`

If the existing column is **mandatory** (e.g. `bill_to` on native Quotes & Invoices, `board_relation6` on the native ITSM Tickets board), it cannot be deleted. In that case, create a NEW supplementary `board_relation` column alongside it — the mandatory empty one stays as a UI artifact, but your new column carries the data.

#### Native columns — already wired

Native CRM/Dev/Service `board_relation` columns ship with `boardIds` already configured (e.g. `contact_account`, `deal_contact`, `task_sprint`, `bug_tasks`, the ITSM `connect_boards2` Tickets↔Incidents pairing). Don't recreate them — use them.

#### When user has ALREADY created a column with empty boardIds

If the user manually created a `board_relation` column in the UI without picking a connected board (showing `settings_str: "{}"`), the API can't fix it. Two options:
1. Have them open the column header → Settings → Connect boards → pick target → Save (UI fix).
2. Or delete that column and recreate via `create_column.defaults` from the API.

**Note on `link_board_items_workflow`:** The descriptions of `change_item_column_values` and `get_board_items_page` mention a `[REQUIRED PRECONDITION]` to call `link_board_items_workflow` for board-relation tasks — **but that tool is NOT exposed as a callable MCP tool, and writing/reading `board_relation` columns works fine without it (verified end-to-end in May 2026), as long as `boardIds` was set at creation per the `defaults` rule above.** Treat the precondition note as legacy/aspirational documentation, not a real requirement.

CRM-style schema example:
- `Accounts` ← `Contacts` (board_relation on Contacts → Accounts; mirror Account Name back)
- `Accounts` ← `Deals` (board_relation on Deals → Accounts; mirror Account Name; mirror Owner)
- `Deals` ← `Activities` (board_relation on Activities → Deals)

---

## 6. Items, groups, and bulk operations

- **Create item:** `create_item` with `boardId, name, columnValues` (and optional `groupId`).
- **Create subitem:** use `create_item` with `parentItemId` set — there is no separate `create_subitem` MCP tool. Subitems live on a hidden auto-generated board (e.g. `Subitems of [BoardName]`); the response includes that board's ID. The raw GraphQL `create_subitem` mutation also exists for use via `all_monday_api`.
- **Update values:** `change_item_column_values`. Pass `createLabelsIfMissing: true` when writing a status/dropdown label that may not yet exist on the column — without it the call fails. (Requires permission to change board structure.)
- **Move/duplicate:** `move_object`.
- **Delete:** `delete_item`, `delete_group`, `delete_board`.
- **Group:** `create_group`, `update_group`, `delete_group`. Groups are intra-board sections. New items always land in the **top group** — make the most relevant group the top group.
- **Bulk read:**
  - `get_board_items_page` (single page, up to 500/page; supports filters, search, ordering, sub-items, item-description).
  - `next_items_page` via `all_monday_api` (continue with cursor) — required for >500 items.
  - `items_page_by_column_values` (search across columns).
- **Bulk read everything (one board):** `get_full_board_data` is internal-only and triggered by UI components — DO NOT call directly. Use `get_board_info` + `get_board_items_page` paginated.
- **Aggregations:** `board_insights` (named tool) supports SUM/AVG/MIN/MAX/COUNT/COUNT_DISTINCT/MEDIAN with group-by + filters. The `aggregate` raw GraphQL query is even more flexible. Use these instead of fetching all items + counting client-side.
- **Bulk write:** prefer multiple `create_item` calls; for large batches, fall back to `all_monday_api` with a multi-mutation document or use bulk-import jobs (`UploadJobInit`, `ItemsJobStatus`).
- **Tags:** `create_or_get_tag`.
- **Files:** `update_assets_on_item` (replace assets), `add_file_to_column` (append to a file column), `add_file_to_update` (attach to an update).
- **Archive vs delete:** archive (reversible) preferred for user-facing data — `archive_board`, `archive_group`, `archive_item`. Use `delete_*` only when permanent removal is intended.
- **Position / movement:** `change_item_position` (within group), `move_item_to_board` (move item across boards), `move_object` (relocate boards/docs/dashboards between workspaces or folders).
- **Item description (rich-text body):** `set_item_description_content` accepts markdown; `add_content_to_doc_from_markdown` appends to a doc.
- **Column structural changes:** `change_column_metadata`, `change_column_title`, `delete_column`, `add_required_column`, `remove_required_column`. **`change_column_metadata.column_property` is an enum with only `title` and `description`** — it does NOT expose column settings (e.g., `boardIds` for `board_relation`). For label/option updates use `update_status_column` / `update_dropdown_column`. For `board_relation.boardIds` see §5 — UI-only.
- **Board-level metadata:** `update_board(board_id: ID!, board_attribute: BoardAttributes!, new_value: String!)` — the response is bare JSON, NOT a `Board` object, so do NOT add a `{ id }` selection (you'll get `Field "update_board" must not have a selection since type "JSON" has no subfields`). `BoardAttributes` enum includes `description`, `name`, etc. Multiple `update_board` calls in one mutation document need aliases (e.g. `a: update_board(...)`, `b: update_board(...)`).
- **Dependency batching:** `batch_update_dependency_column` (≤50 items per batch).
- **Bulk import jobs:** `backfill_items` (no side effects, ≤20k rows, for migrations) vs `ingest_items` (full side effects, ≤10k rows, for ongoing integrations). Each returns a job ID + upload URL; check status with `fetch_job_status`.
- **Alternative single-value writes:** `change_column_value`, `change_simple_column_value`, `change_multiple_column_values` exist alongside `change_item_column_values` — use whichever matches the granularity needed.

---

## 7. Dashboards and widgets — verified catalog

`all_widgets_schema` returns these widget types (verified):

| Widget type | Use for |
|---|---|
| `NUMBER` | Single KPI (sum/avg/median/min/max of a numbers column, or item count). Supports prefix/suffix, currency/percentage formatting. |
| `CHART` | **All 16 `graph_type` variants verified working end-to-end:** `pie`, `donut`, `bar`, `column`, `line`, `smooth_line`, `area`, `bubbles`, `stackedBar`, `stackedColumn`, `stackedArea`, `stackedLine`, `stackedBarPercent`, `stackedColumnPercent`, `stackedAreaPercent`, `stackedLinePercent`. Stacked variants need `z_axis_columns`. Percent-stacked variants display proportions within each X group. Time-series charts (line/area + variants) want `x_axis_group_by: "date"` plus `group_by: "week"|"month"|...`. Bubbles wants 3 axes (x, y, z) and a numeric calc function. |
| `BATTERY` | Progress bar across boards/columns based on a "done" status label. Supports per-board status column lists, optional numeric weighting, group filtering. |
| `CALENDAR` | Date/timeline/week/creation_log/last_updated/lookup/formula columns rendered as calendar events. View modes month/week/day. Color-by board / group / parent / status / person / dropdown / board-relation / subtasks. |
| `GANTT` | Timeline/Gantt for timeline+date columns. Group/color/label by board/group/parent/color. |
| `LISTVIEW` | Standalone list view; configurable columns, item height, subitem display mode (like_items / nested / with_parents). |
| `APP_FEATURE` | Embed an app feature widget by `app_feature_id`. |

**Anything not in the above list** (e.g., Kanban, Workload, Numbers Grouping, Quote, Iframe) is NOT exposed by the connector's `create_widget`. Don't promise it. If the user asks, propose the closest supported widget — or build it as a **board view** (`create_view`) instead, since views support a wider set of layouts (kanban, etc.).

Workflow:
1. `create_dashboard` (in a workspace, optionally a folder; `DashboardKind` is `PUBLIC` or `PRIVATE`).
2. Call `all_widgets_schema` to get the JSON Schema 7 for the target widget.
3. `create_widget` with config matching that schema, attached to source board(s).

For board-level analytics without building a dashboard, use `board_insights`.

---

## 8. Forms

- **`create_form` auto-creates a backing board for responses** — you do NOT need to create the board first. Pass `destination_workspace_id` (required), optional `destination_name`, `destination_folder_id`, `board_kind`, owners/subscribers. Returns `{board_id, form_token}`. Use the `form_token` for all subsequent question/setting operations.
- **Edit questions:** `form_questions_editor` with `action: "create"|"update"|"delete"` and a question payload. Verified question types (23): `Boolean`, `ConnectedBoards`, `Country`, `DISPLAY_TEXT`, `Date`, `DateRange`, `Email`, `File`, `Link`, `Location`, `LongText`, `MultiSelect`, `Name`, `Number`, `PAGE_BLOCK`, `People`, `Phone`, `Rating`, `ShortText`, `Signature`, `SingleSelect`, `Subitems`, `Updates`. Question type cannot be changed after creation — always include `type` in update calls.
- **Question settings (verified by type):** `defaultCurrentDate`/`includeTime` (Date), `display` (Single/MultiSelect: Dropdown/Horizontal/Vertical), `optionsOrder` (Alphabetical/Custom/Random), `labelLimitCount`+`label_limit_count_enabled` (MultiSelect), `prefill` (`{enabled, source: Account|QueryParam, lookup}`), `prefixAutofilled`/`prefixPredefined` (Phone), `default_answer`, `skipValidation` (Link), `checkedByDefault` (Boolean), `locationAutofilled`.
- **Conditional logic:** `show_if_rules` with `operator: OR` and rule conditions referencing `building_block_id`.
- Modify settings with `update_form`. Inspect with `get_form`.
- Use the `form` query (raw GraphQL) by token to fetch a form for display/processing.
- Form features available via settings: tags, AI translate, password protection, response limits, close date, redirect after submission, accessibility, draft submissions, prefill, pre/post submission views, custom logo/background/layout.

---

## 9. Docs (workdocs)

- **Create:** `create_doc` accepts a `markdown` parameter directly — the markdown is auto-imported as blocks. Two location modes: `location: "workspace"` (with `workspace_id` + optional `folder_id` + `doc_kind`) or `location: "item"` (attaches doc to an item via a doc column).
- **Other:** `read_docs`, `update_doc`, rename with `update_doc_name`, delete with `delete_doc`, `duplicate_doc`.
- **Block-level editing** (raw GraphQL mutations): `create_doc_block`, `create_doc_blocks`, `update_doc_block`, `delete_doc_block` — use for granular doc updates after initial markdown import. **`create_doc_blocks` args are `docId` and `blocksInput` (camelCase variant); max 25 blocks per call (verified — 26 throws `A maximum of 25 blocks can be created at once`).**
- **`CreateBlockInput` block types (verified union):** `text_block`, `list_block`, `notice_box_block`, `image_block`, `video_block`, `table_block`, `layout_block`, `divider_block`, `page_break_block`. (Mentions are NOT a top-level block type — they're embedded within text blocks.)
- **Text block content shape** (verified): `{text_block: {delta_format: [{insert: {text: "..."}}]}}`. The `insert` field is an `InsertOpsInput` object with `text` or `blot`, NOT a bare string.
- **Append markdown to existing doc:** `add_content_to_doc_from_markdown` — easier than building blocks manually.
- Advanced (raw GraphQL): `doc_version_history`, `doc_version_diff`, `export_markdown_from_doc`, `import_doc_from_html`, `articles` / `article_blocks` / `update_article_block` (knowledge base).
- Use docs for: PRDs, meeting notes, wikis, runbooks, briefs, SOPs.
- Don't put narrative content in a `long_text` column — it's not searchable, structured, or shareable the same way.

---

## 10. Updates, replies, notifications, assets

- `create_update` — post an update on an item (the canonical activity log). Supports mentions.
- `get_updates` — fetch updates.
- `replies` query (raw GraphQL) — get replies on updates.
- `like_update` / `unlike_update` / `pin_to_top` / `unpin_from_top` / `edit_update` / `delete_update` (raw GraphQL).
- `create_notification` — push a notification to a user. `NotificationTargetType` has two values: `Post` (an Update) and `Project` (an Item or Board) — pick by what the user should be linked to.
- `notifications_settings` / `mute_board_settings` (raw GraphQL) — read user preferences.
- `get_assets` — list files attached to items/updates.
- `get_board_activity` — board audit log.

---

## 11. Automations, triggers, integrations, webhooks (advanced)

- **Webhooks**: first-class mutations `create_webhook` / `delete_webhook`; query existing with `webhooks`. `WebhookEventType` (verified, 22 events): `change_column_value`, `change_specific_column_value`, `change_status_column_value`, `change_name`, `change_subitem_column_value`, `change_subitem_name`, `create_item`, `create_subitem`, `create_column`, `create_update`, `create_subitem_update`, `edit_update`, `delete_update`, `item_archived`, `item_deleted`, `item_restored`, `item_moved_to_any_group`, `item_moved_to_specific_group`, `move_subitem`, `subitem_archived`, `subitem_deleted`. Use webhooks to drive external automations.
- **Integration blocks**: `execute_integration_block` mutation — run an integration block with provided field values.
- **Trigger / automation analytics**: `trigger_events`, `trigger_event`, `block_events`, `tool_events`, `account_trigger_statistics`, `account_triggers_statistics_by_entity_id` (raw GraphQL) — diagnose automation runs.
- **Validations**: `validations` query + mutations `create_validation_rule` / `update_validation_rule` / `delete_validation_rule` — board-level data validation rules.
- **Connections**: `connections`, `user_connections`, `account_connections`, `connection`, `connection_board_ids` — reusable auth connections (e.g., for sequences/integrations).

If the user asks "automate X when Y happens", first decide:
1. Is there a built-in automation recipe in the UI? (Most cases — recommend the user wires it there; the API doesn't currently expose recipe creation directly.)
2. If external system needs to react → **webhook** subscribing to the right `WebhookEventType`.
3. If a one-shot integration action → `execute_integration_block`.

---

## 12. Audit logs and compliance

- `audit_event_catalogue` (raw GraphQL) — list all audit event types.
- `audit_logs` (raw GraphQL) — query account audit log with filters (user_id, events, ip_address, time range, paginated).
- `export_events` — export board events for a date range (requires `X-Tool-Execution-Secret` header).

---

## 13. Dev product (monday Software)

- `get_monday_dev_sprints_boards` — find sprint boards.
- `get_sprints_metadata` — sprint definitions on a board.
- `get_sprint_summary` — burnup/burndown/summary for a sprint.
- `sprints` query (raw GraphQL) — full sprint collection.
- Native types: `Sprint`, `SprintSnapshot`, `SprintTimeline`, `SprintState`.
- Use Epics and Releases as native objects on `software` workspaces; don't reinvent them as Status options.
- `enroll_items_to_sequence` (raw GraphQL mutation, verified name) — enroll items into a sequence; pre-check eligibility with the `allowed_sequences_to_enroll` query.

> **Sprint provisioning is UI-only.** `create_sprint` is NOT in the API schema as of `2026-07`. To set up the native engineering board pair (Sprints + Tasks + Epics + Bugs Queue + Retrospectives + Capacity), the user must add the **Sprint template** in the monday UI (`Workspace → Add → Templates → Sprint`). See §1.5 "monday Dev — TWO native variants" for the full board structure of each variant.

---

## 14. Notetaker (meetings)

- `get_notetaker_meetings` — list meetings.
- Raw GraphQL: `notetaker { meetings(limit, cursor, filters) { ... } }` — paginated. `Meeting` fields (verified): `id`, `title`, `start_time`, `end_time`, `recording_duration`, `access_type`, `meeting_link`, `summary`, `participants`, `topics`, `action_items`, `transcript`. (All snake_case.)
- Use to extract action items / decisions from meetings into items.

---

## 15. Search and discovery

- `search` — global, multi-entity. Returns boards/items/docs with tailored filters per entity.
- `search` raw query supports a `SearchStrategy` arg with values (verified): `SPEED` (fastest, lower quality), `BALANCED` (default), `QUALITY` (best quality, slower).
- Marketplace app search comes in four flavors (separate queries, not strategies): `marketplace_vector_search`, `marketplace_fulltext_search`, `marketplace_hybrid_search`, `marketplace_ai_search`.
- `ask_developer_docs` — AI Q&A against monday's developer docs.
- Always run a `search` BEFORE creating something with a name the user mentioned — avoid duplicates.

---

## 16. Users, teams, roles, departments

- `list_users_and_teams` — enumerate principals.
- `get_user_context` — current user.
- Raw GraphQL: `users`, `teams`, `account_roles`, `departments`, `me`.
- User lifecycle mutations: `invite_users`, `activate_users`, `deactivate_users`, `update_users_role`, `update_multiple_users`, `update_email_domain`.
- Team mutations: `create_team`, `delete_team`, `add_users_to_team`, `remove_users_from_team`, `assign_team_owners`, `remove_team_owners`.
- Department mutations: `create_department`, `update_department`, `delete_department`, `assign_department_members`, `assign_department_owner`, `unassign_department_owners`, `clear_users_department`.
- Board membership: `add_users_to_board`, `add_teams_to_board`, `delete_subscribers_from_board`, `delete_teams_from_board`.
- Workspace membership: `add_users_to_workspace`, `add_teams_to_workspace`, `delete_users_from_workspace`, `delete_teams_from_workspace`.
- Use real user/team IDs in `people`/`team` columns and notifications.

---

## 17. Objects platform (advanced)

monday's newer Objects platform models things like workflows/projects as first-class objects with relations:

- `object_types_unique_keys` — list available object types. Each is identified by an `object_type_unique_key` formatted as `app_slug::app_feature_slug` (per-schema docstring); examples seen in docs are `'workflows'`, `'projects'`. Don't hardcode these — call the query.
- `objects` — query objects with filters.
- `object_relations` — fetch relations for an object.
- Mutation: `update_object`, plus relation operations.

Use this when working with cross-cutting object types beyond boards/items.

---

## 18. Knowledge base

- `articles`, `article_blocks` — published KB articles.
- `knowledge_base_search` — search snippets.

---

## 19. Schema introspection (deeper)

- `get_object_schemas` — account-level object schemas (board structure templates).
- `get_column_type_schema` — column-type JSON Schema for `update_column` defaults.
- `get_view_schema_by_type` — JSON Schema for `create_view` settings.
- `complexity` query — current GraphQL complexity budget. Monitor this for bulk operations.
- `version` / `versions` — API version info; pin if needed via `API-Version` header (raw GraphQL).
- `platform_api { daily_limit, daily_analytics }` — API quota and usage (verified fields). The `DailyAnalytics` type aggregates by app/day/user under sub-fields.

---

## 20. Raw GraphQL fallback (`all_monday_api`)

Use only when:
- A purpose-built MCP tool doesn't exist.
- You need a multi-operation document (batch write).
- You need fields/args not exposed by a named tool.
- You need to subscribe to webhooks, run integration blocks, or hit advanced queries (`audit_logs`, `aggregate`, `objects`, `notetaker`, `connections`, `sprints`, `complexity`, etc.).

Best practices:
- Validate against `get_graphql_schema(operationType)` and `get_type_details(typeName)` before sending.
- Watch `complexity` — bulk reads can exceed the budget; paginate via cursors (`next_items_page`).
- Pass `API-Version` header if you need a specific version (default = latest stable).
- Returned errors include `error_code`, `error_message`, and `extensions` data. Common code seen on column-value mismatches: `ColumnValueException` — fix by re-fetching the type schema (`get_column_type_info`) and rebuilding the payload, not retrying blindly. Other codes (complexity-budget, permission, validation) come back with their own `error_code` strings — read what the API returns instead of guessing.

---

## 21. Error semantics & rate limits

- Mutations on column values that fail validation throw `ColumnValueException` with details — call `get_column_type_info` and rebuild the payload, don't retry blindly.
- Item-creation cap is per-board; over-large boards should be split or migrated to portfolio/project structure.
- Complexity budget is per-minute; for big read sets, paginate with `next_items_page` (cursor-based) and avoid wide nested selections.
- For very large item sets, prefer `aggregate` over fetching items.

---

## 22. Anti-patterns — STOP if you catch yourself doing these

1. CRM pipeline on a `core` board with a Status column — use `crm`.
2. Creating a new Leads / Contacts / Accounts / Deals / Activities board from scratch when the native CRM workspace already has one — call `workspace_info` on the CRM workspace first, find the existing board, and seed it. Same applies to Dev sprints, Service tickets, and Marketing campaigns.
3. "Portfolio" built from a regular board + manual mirrors — use Projects/Portfolios (`create_project`, `create_portfolio`, `connect_project_to_portfolio`).
4. Related-item ID stored in a `text` column — use `board_relation` + `mirror`.
5. Refusing a widget without checking `all_widgets_schema`. (And don't promise widget types not in the verified catalog: only `NUMBER`, `CHART`, `BATTERY`, `CALENDAR`, `GANTT`, `LISTVIEW`, `APP_FEATURE`.)
6. `change_item_column_values` payload written from memory — call `get_column_type_info` first.
7. Using `column_type: "person"` — deprecated, use `people`.
8. Sprint/epic structure on generic `core` boards — use `software` workspaces + sprint queries.
9. Long-form narrative in a `long_text` column — use a Doc.
10. Hand-rolled GraphQL via `all_monday_api` when a named tool exists.
11. Form-style intake done via manual item creation — use a Form bound to the board.
12. Per-item notification done via update text — use `create_notification`.
13. Files dumped into a `long_text` column — use `file`.
14. Assignee tracked as a name string — use `people` with real user IDs.
15. Email/phone in plain `text` — use `email` / `phone` (enables click-to-email and dialer).
16. Building everything in the workspace root — group with folders.
17. Creating duplicates — `search` first.
18. Monolithic boards with 30+ columns — split by domain and connect via `board_relation`.
19. One dashboard per metric — group related KPIs onto one dashboard.
20. Fetching all items to count them — use `aggregate` or `items_page_by_column_values`.
21. Reading >500 items without pagination — use cursor with `next_items_page`.
22. Promising "automation recipes via API" — recipe creation isn't exposed; use webhooks + `execute_integration_block` instead.
23. Creating reusable status/dropdown labels per board — use **managed columns**.
24. Hardcoding "Done" string for a Battery widget — pass via `done_text` (supports per-language).
25. Ignoring `complexity` errors and retrying with the same query — paginate or trim selection.
26. Calling `change_item_column_values` with a new status/dropdown label without `createLabelsIfMissing: true` — call fails with `ColumnValueException`.
27. Calling `get_full_board_data` directly — it's marked internal-only (UI-triggered). Use `get_board_info` + paginated `get_board_items_page` instead.
28. Promising "portfolio kind" boards via `create_board` — that enum has only `public/private/share`. Portfolios are Projects (`create_project` → `create_portfolio` → `connect_project_to_portfolio`).
29. Replacing whole docs to make small edits — use `create_doc_block` / `update_doc_block` / `delete_doc_block` for granular updates.
30. Creating a webhook via raw GraphQL when `create_webhook` mutation exists.
31. Permanently deleting items/boards/groups when archive is appropriate — prefer `archive_item` / `archive_board` / `archive_group` (reversible) over `delete_*`.
32. Creating a status/dropdown column on a board you intend to share label semantics across — use `attach_status_managed_column` / `attach_dropdown_managed_column` (linked to a managed column) instead of `create_status_column` / `create_dropdown_column` (board-local).
33. Confusing `backfill_items` with `ingest_items` — backfill is for one-time data migration (no side-effects, 20k rows); ingest is for ongoing integrations (full side-effects, 10k rows).
34. Citing error codes from memory in user-facing diagnostics — read the actual `error_code` from the API response.
35. **Creating a `board_relation` column with empty boardIds and asking the user to wire it in the UI** — wrong. Use `create_column.defaults: "{\"boardIds\":[<id>]}"` (raw GraphQL via `all_monday_api`) to wire it at creation. The "needs UI handoff" rule was a patch7 mistake. See §5.
36. **Promising `create_sprint` to provision the engineering sprint board set** — that mutation is not in the schema. The user must add the Sprint template via the monday UI first. See §1.5 / §13.
37. **Quoting the response of `update_board` with a `{ id }` selection** — the response is bare JSON, not a `Board` object. See §6.

---

## 23. Output contract for the planning phase

Before executing, present a plan that explicitly states:

1. **Product `kind`** (`core` / `crm` / `software` / `service` / `marketing(_campaigns)` / `project_management` / `forms` / `whiteboard`) and why.
2. **Workspaces & folders** to be created/used.
3. **Boards** — name, `BoardKind` (`public`/`private`/`share`), product context, owner, sub-items?
4. **Projects/Portfolios** if cross-project rollup is needed (instead of regular boards + mirrors).
5. **Columns** per board — name, `ColumnType` (use the enum string), purpose. Flag every `board_relation` / `mirror` / `formula` / `dependency` / managed column.
6. **Cross-board relationships** — list of `board_relation` links + which `mirror` columns surface which fields.
7. **Items / groups** to seed (if any).
8. **Forms** with question → column mapping.
9. **Dashboards** — which widget types from the verified catalog (§7), config sourced from `all_widgets_schema`, attached to which boards.
10. **Views** (`create_view`) if Kanban/Table/Calendar/etc. are needed at the board level.
11. **Docs** to create.
12. **Webhooks / integrations / automations** — which `WebhookEventType` events and target endpoints.
13. **Permissions / sharing** assumptions.
14. **Open MCP lookups** still needed before building (e.g., "need `get_user_context` to confirm `crm` is enabled", "need `get_column_type_info(status)` for label config").

If the user pushes back on any choice, re-evaluate openly. Don't silently downgrade to a regular board to avoid the conversation.

---

## 24. Execution order

When the plan is approved, execute in this order to avoid forward-references:

1. Workspaces → folders.
2. Managed columns (status/dropdown), if any are reusable across boards.
3. Boards (parents before children of `board_relation` relationships).
4. Columns per board (including `board_relation`). **For NEW `board_relation` columns, the `boardIds` setting is empty after creation — see step 7.**
5. `mirror` columns (after `board_relation` exists on both sides).
6. Groups.
7. **For every `board_relation` column you create, use raw GraphQL `create_column` with `defaults: "{\"boardIds\":[<target>]}"`** — this wires the column at creation. Native columns (`contact_account`, `task_sprint`, `bug_tasks`, etc.) ship pre-wired and don't need this. See §5 for the exact mutation shape and the workaround when a mandatory empty column already exists.
8. Seed items + initial column values. Use `createLabelsIfMissing: true` if seeding new status/dropdown labels. `board_relation` writes (`{"item_ids": [...]}`) work — once `boardIds` is set per step 7.
9. Views (`create_view`).
10. Forms (board must exist).
11. Docs.
12. Dashboards + widgets (boards must exist with data for widgets to be meaningful).
13. Webhooks / integrations / automation triggers.
14. Notifications / sharing.
15. Verify with `get_board_info` + paginated `get_board_items_page` / `board_insights` / `aggregate` before reporting done. (Do NOT use `get_full_board_data` — internal-only.)

**Moving boards between folders/workspaces:** use `update_board_hierarchy(board_id: ID!, attributes: { workspace_id?: ID, folder_id?: ID })`. Returns `UpdateBoardHierarchyResult { success, message, board }` — no `id` field. Verified working — this is the right tool for re-organizing demo workspaces (e.g. moving a Campaigns board from a separate Marketing workspace into a CRM workspace folder mid-build). `move_object` works for boards too but `update_board_hierarchy` is more explicit.

If a step fails, fix the root cause — don't paper over with a `text`-column workaround.

---

## 25. Verified-by-execution gotchas (cheat sheet)

These are the things that bit during a real end-to-end build. Read this before you write payloads.

### Naming
- **Column ID prefixes don't match the `columnType` enum.** `numbers`→`numeric_*`, `creation_log`→`pulse_log_*`, `mirror`→`lookup_*`, `status`→`color_*`, `people`→`multiple_person_*`, `timeline`→`timerange_*`, `time_tracking`→`duration_*`, `tags`→`tag_*`, `checkbox`→`boolean_*`. Match the prefix when targeting a column by ID.
- **Managed-column IDs are UUIDs**, not the usual `prefix_xxx` shorthand.
- **Subitems live on a hidden auto-generated board** named `Subitems of <BoardName>`; the response includes its `board_id`.

### Settings vs values
- **`columnSettings` for `create_column` is UNWRAPPED.** Send `{"labels": [...]}`, NOT `{"settings": {"labels": [...]}}`. The schema returned by `get_column_type_info` *describes* the `settings` field — that wrapper is conceptual, not literal payload.
- **Column-value JSON ≠ column-settings JSON.** Column values use shapes like `{"label": "..."}`, `{"date": "..."}`, `{"item_ids": [...]}`. See §4 step 4 for the verified table.
- **Status `index` is remapped to color ID.** When you create a status with `index: 0` and `color: "american_gray"`, monday stores the label keyed by `17` (the color ID). Don't trust your assigned indexes for index-based writes — use label-based writes (`{"label": "X"}`) to avoid the trap.
- **Phone numbers can't have spaces** in the `phone` field. `+4940123456` works; `+49 40 123 4567` fails (the API tries to parse the second token as `countryShortName`).
- **Status colors in raw GraphQL are enum literals (unquoted)**, e.g. `color: done_green`. Inside `create_column.columnSettings` (a JSON string), use `"done_green"`. The MCP wrapper converts JSON → enum at the boundary.

### Architecture
- **`create_board` does NOT take a folder ID.** Boards land at workspace root. Call `move_object(objectType: "Board", id, parentFolderId)` after creation.
- **`create_form` auto-creates its backing board.** Don't create the response board first — the form mutation returns the board it just made plus a `form_token`.
- **`create_doc` accepts `markdown` directly.** No need to chain `create_doc_blocks` for the initial body.
- **`create_doc_blocks` shape:** `{text_block: {delta_format: [{insert: {text: "..."}}]}}`. Args are `docId` + `blocksInput`. Max 25 blocks per call.
- **`create_project` is async.** Returns `process_id`; the actual `project_id` arrives via callback URL or by polling. Plan for the latency.
- **`create_portfolio` doesn't return a board ID.** Query `boards(workspace_ids: [...])` after to find the new portfolio board.
- **`delete_workspace` cascades** — *when it runs.* When the API actually executes the mutation, it removes all boards, items, dashboards, docs, forms, projects, portfolios, subitem-boards, columns, groups, and updates in one call. Useful for demo cleanup. **But** the MCP harness's Stage 2 safety classifier frequently blocks this mutation; have the user delete the workspace via the monday UI as the reliable fallback.

### MCP tool quirks
- **`get_full_board_data` is internal-only.** Even though it appears in the tool list, its description says it's UI-triggered only. Use `get_board_info` + paginated `get_board_items_page` instead.
- **`link_board_items_workflow` is referenced as a precondition but is NOT a callable tool.** Writing to `board_relation` columns works fine without it (assuming `boardIds` is set per §5). Treat the precondition note in `change_item_column_values` and `get_board_items_page` as legacy documentation.
- **`create_subitem` is NOT a top-level MCP tool.** Use `create_item` with `parentItemId`. (The raw GraphQL `create_subitem` mutation does exist.)
- **No `delete_workspace` MCP tool either** — and the raw GraphQL mutation is **frequently blocked by the MCP harness's safety classifier** ("Stage 2 classifier — permission denied"). When you need to delete a workspace and the harness blocks it, tell the user to delete it via the UI (sidebar → right-click → Delete workspace) rather than retrying.
- **Webhook creation may be sandbox-blocked.** In some environments, creating webhooks pointed at external URLs (even `example.com`) is blocked by tooling-level guardrails. The API itself accepts the call; the harness denies it. Tell the user the URL/event combination you'd create rather than failing silently.
- **`board_relation.boardIds` IS settable via `create_column.defaults: "{\"boardIds\":[<id>]}"`.** See §5. `update_column(settings)` and `change_column_metadata` cannot set boardIds AFTER creation, but `create_column.defaults` works at creation time. Use raw GraphQL via `all_monday_api` since the MCP `create_column` tool wrapper exposes `columnSettings` (column-type config, not the same arg). When a mandatory column already exists with empty boardIds, add a supplementary `board_relation` column instead.

### Errors
- **`ColumnValueException`** is the standard error for bad column values. The error response includes `extensions.error_data` with `column_validation_error_code` (e.g. `missingLabel` for an unrecognized status label). `createLabelsIfMissing: true` is the fix for the `missingLabel` case.
- **The underlying mutation for `change_item_column_values` is `change_multiple_column_values`** — useful when reading error stack traces or constructing raw GraphQL.
- **Status label errors helpfully list valid options:** `"This status label doesn't exist, possible statuses are: {0: Proposal, 1: Closed Won, ...}"` — read those keys (color IDs) for the canonical mapping.

### API meta
- **Complexity budget:** ~5,000,000 per minute (verified `before/after/query/reset_in_x_seconds` shape). Reads cost roughly nothing per query. Bulk reads are the only realistic complexity risk.
- **API version:** Monday is on rolling release with date-versioned API (e.g. `release_candidate 2026-07`). The default (no `API-Version` header) is the latest stable.
- **Audit log event names use kebab-case** (`create-workspace`, `delete-board`, `add-user-to-team`), not snake_case. 75+ event types are catalogued.

### Round-2 findings (portfolio + advanced)
- **`create_project` is NOT just one board.** It creates two boards (parent + tasks) AND seeds the tasks board with **2 demo tasks (Task 1, Task 2)** and a **14-column native template** (`project_owner`, `project_resource`, `project_status`, `project_priority`, `project_timeline`, `project_dependency`, `project_planned_effort`, `project_effort_spent`, `project_duration`, `project_budget`, `project_task_completion_date`, `subtasks_*`, plus a back-link `board_relation`). Plan for these — they affect demo seeding strategy.
- **`connect_project_to_portfolio` only accepts the project's TASKS board ID** (the lower-numbered of the two), not the parent. The error if you pass the wrong one is: `"Failed to connect project to portfolio. the following boards are not projects: [<id>]"`.
- **`solution_live_version_id` returned from `create_portfolio` is template-version-shared**, NOT the unique portfolio ID. Same value is returned for every portfolio. To find the new portfolio's actual board ID, query `boards(workspace_ids: [<id>])` after creation.
- **A connected portfolio has 11 specific native columns.** See §3.5 for the full list. Two of those columns (`portfolio_project_progress`, `portfolio_project_actual_timeline`) are mirrors that auto-rollup `project_status`/`project_timeline` from connected tasks boards.
- **`connect_project_to_portfolio` wires structure but not item-level links.** The `portfolio_project_link` value on each portfolio item starts null even after a successful connect — you may need to populate it manually. Validate the mirror columns visually if you depend on them.
- **All 16 CHART variants verified working** end-to-end via `create_widget`. See §7.
- **`ViewKind` enum is just 4 values:** `DASHBOARD`, `TABLE`, `FORM`, `APP`. **There is NO `KANBAN` / `CALENDAR` / `GANTT` view creatable via `create_view`** — those are dashboard widget types only. For board-level kanban/calendar/gantt views, the user must add them manually in the UI.
- **`get_view_schema_by_type` arg names:** `type: ViewKind!, mutationType: ViewMutationKind!` (not `view_type`).
- **`convert_board_to_project.column_mappings` is REQUIRED.** Three required ID fields: `project_status`, `project_timeline`, `project_owner`. Cannot pass empty `{}`. The values must be column IDs on the source board (or `"name"` for the name column as a stand-in for owner).
- **`archive_group` cascades to its items** — items in the archived group become inaccessible via `items()` query and reject `change_simple_column_value` with `"Cannot change column value for inactive items"`. **The mutation's response field `archived: false` is unreliable** — verify the side effect by querying.
- **`change_simple_column_value` for status accepts: label name (`"C"`), color-key-as-string (`"1"`), or numeric color ID.** The status label is keyed by COLOR ID, not your `index` field at creation time.
- **`add_users_to_board` arg `kind` is an enum**: `subscriber` (lowercase). Returns `[{id}]` array.
- **`pin_to_top` uses `id`, not `item_id`** (the `id` is the update ID).
- **`update_mute_board_settings` with `MUTE_ALL` is owner-only** — non-owners get `"User unauthorized to perform action"`. The enum has 5 values: `NOT_MUTED`, `MUTE_ALL` (owner-only), `MENTIONS_AND_ASSIGNS_ONLY`, `CUSTOM_SETTINGS`, `CURRENT_USER_MUTE_ALL`.
- **`create_validation_rule` may return "This feature is not currently supported"** — feature-flagged. Don't promise validations on every account.
- **`backfill_items` ✅ works.** Args: `board_id`, `group_id` (no `on_match` here despite the schema). Returns `UploadJobInit { job_id, upload_url }`. The `upload_url` is a pre-signed S3 PUT URL valid 10 minutes (`X-Amz-Expires=600`). After uploading a CSV, poll via `fetch_job_status(job_id)`.
- **`fetch_job_status` returns `ItemsJobStatus`** with: `status` (BulkImportState enum), `progress_percentage` (0–100), `fully_imported` (bool), `failure_reason`, `failure_message`, `report_url`. Initial status is `UPLOAD_PENDING`.
- **`validations(id: ID!)`** — the arg is named `id`, not `board_id`, but takes the board ID.
- **`pin_to_top`, `like_update`, `unlike_update` etc. all use `id` arg** — not entity-specific names.
- **Update mentions render as embedded HTML `<a class="user_mention_editor router">` tags** in the body when read back. Pass them via `mentionsList: '[{"id":"...","type":"User"}]'`.

### Round-3 findings (cross-product demo build, May 2026)

- **`board_relation.boardIds` IS settable at creation via `create_column.defaults`.** Patch7 incorrectly stated this was impossible — the `defaults: JSON` argument on the `create_column` mutation accepts `{"boardIds":[...]}` and wires the column at creation. Verified end-to-end. Only `update_column.settings` is broken (still rejects `boardIds`). See §5 for the exact mutation shape, mandatory-column workaround, and reverse-side reflection guidance.
- **`create_sprint` is not in the schema.** Native engineering sprint board pair (Sprints/Tasks/Epics/Bugs Queue/Retrospectives/Capacity) must be provisioned via UI sprint template. See §1.5 / §13.
- **`update_board` returns bare JSON.** Args: `board_id, board_attribute, new_value`. NO `{ id }` selection — fails with `must not have a selection since type "JSON" has no subfields`. Multiple updates in one document need GraphQL aliases.
- **`update_board_hierarchy` is the right tool for moving boards between workspaces or folders.** Args: `board_id, attributes: { workspace_id?, folder_id? }`. Response type is `UpdateBoardHierarchyResult { success, message, board }` — NO `id` or `errors` fields. Use this when restructuring demo workspaces mid-build.
- **`change_column_metadata.column_property` enum has only 2 values:** `title`, `description`. Don't try to use this to set column settings.
- **`update_column(settings: JSON)` exists but rejects every realistic payload.** The schema lists the arg; the validator rejects `boardIds`, `allowedValues`, etc. with `Column schema validation failed`. Effectively read-only for type-specific settings post-creation.
- **`delete_workspace` is harness-blocked** (Stage 2 classifier). Hand off to UI deletion.
- **`mirror` columns return `"Column value type is not supported"` when read via `get_board_items_page`** — even though they render correctly in the UI. Don't panic when a mirror reads as that string; verify visually in the UI instead.
- **CRM native `board_relation` reads return `null` via API even when set.** `deal_contact`, `account_contact`, etc. populate correctly in the UI but `get_board_items_page` returns null arrays for those columns on some accounts. The data IS there — UI is the source of truth for these specific native columns.
- **"Form auto-creates a Name question."** When you call `create_form`, the backing board comes pre-seeded with a `Name` question (id: `name`, type: `Name`). Trying to `create` another Name question fails with `ExceededUniqueQuestionTypeCount`. To customize, use `form_questions_editor(action: "update", questionId: "name", ...)` instead.
- **Widget API has NO read/list/delete endpoint.** `create_widget` is one-way. There is no `widgets` query, no `delete_widget` mutation accessible to the MCP. To remove a broken widget, you must delete it via the dashboard UI. Plan for this when widgets reference deleted boards (their references stay broken until manually removed).

### Data shapes seen on the wire
- `boards.columns[].settings_str` is a JSON-encoded string — parse to inspect a column's actual stored config.
- `notetaker.meetings` returns a doubly-nested `{meetings: {meetings: [...], page_info: {cursor}}}`.
- `aggregate` query takes `query: AggregateQueryInput!` with fields `select` and `from` (singular). Don't use `selects`/`from_table`. (`board_insights` is the easier MCP-wrapped alternative.)
- `search` namespace returns `{results: [{id, indexed_data, live_data}]}` for items/boards/docs. `live_data` may be null for stale or deleted records.
- `object_types_unique_keys` returns `{object_type_unique_key, app_name, app_feature_name, description}`. Native object keys: `monday_documents::doc`, `monday_workflows::workflow`, `service::portal-object`, `solutionsv2_monday-dashboards::dashboard_object`, `solutionsv2_new-form::form`. Many third-party app keys appear too.

---

## 26. Demo-build mode

This skill is most often used to build **demo accounts** — fully-loaded accounts (all products enabled) used to show prospects what monday can do. Demos amplify a few priorities on top of the rest of this manual:

### What "good" looks like in a demo
- **Believable data.** Real-sounding company names, contact names, deal values, dates near today (some past, some future, some overdue). Avoid `Item 1`, `Test`, `asdf`. Avoid obviously LLM-flavoured names like "Acme Innovations".
- **Visual polish.** Use status column colors deliberately (red/yellow/green map to risk; not random). Group items meaningfully — e.g., in a sales pipeline, groups = stages. Set group colors via the `groupColor` arg on `create_group` (palette: `#037f4c`, `#00c875`, `#9cd326`, `#cab641`, `#ffcb00`, `#784bd1`, `#9d50dd`, `#007eb5`, `#579bfc`, `#66ccff`, `#bb3354`, `#df2f4a`, `#ff007f`, `#ff5ac4`, `#ff642e`, `#fdab3d`, `#7f5347`, `#c4c4c4`, `#757575`).
- **Filled cells.** Empty columns look unfinished. Seed every column on every demo item — even if it's a sensible default.
- **Working dashboards.** A dashboard with empty widgets is worse than no dashboard. Seed enough items, with enough variety, that every widget on the dashboard has something to show. NUMBER widgets need numeric data; CHART widgets need >1 group; BATTERY widgets need at least one "done" item.
- **Realistic dates.** Spread dates across past/present/future so timeline/calendar/gantt widgets render meaningfully. Seed items in a mix of statuses including some `Stuck` and some `Done` so progress visualizations are non-trivial.
- **Cross-product moments.** The most impressive demos span products: a Deal in CRM that links to a Project in Work Management that links to a Sprint in Dev that has a Service ticket. Build at least one of these flows when relevant.

### Demo build sequence (overrides §24 ordering for speed)
1. `get_user_context` → confirm products + grab favorites/relevant boards (often you'll re-use existing demo boards).
2. **Search first** — `search` for any name the user mentions. Demo accounts accumulate cruft; check for an existing version before building a new one.
3. Pick one demo workspace per scenario. Use `WorkspaceKind: open`. Name it explicitly — `[DEMO] <Scenario>` so it's obvious in lists.
4. Folders by domain inside the demo workspace.
5. Boards with full column sets, real-feel names. **Always seed at least 8–15 items per board** — this is the threshold below which dashboards/widgets look fake.
6. Cross-board links — `change_item_column_values` with `{"item_ids": [...]}` for `board_relation` cells. No precondition call needed.
7. At least one Doc per scenario (project brief, meeting notes, runbook) — populate it with `create_doc` + `create_doc_blocks` (≤25 blocks per call). Demos lose credibility when "Documents" is empty.
8. At least one Form per scenario where intake makes sense (lead capture, support ticket, request form).
9. Dashboard with **multiple widget types** mixed (one NUMBER, one CHART, one BATTERY, one CALENDAR/GANTT) so the dashboard isn't monotone.
10. Optionally one webhook subscribed to a meaningful event (e.g., `create_item` on the leads board) wired to a placeholder URL — shows the integration story.

### Cross-product demo archetypes (build any of these end-to-end)
- **Lead-to-cash:** CRM Leads → Contacts → Accounts → Deals → (deal-won automation conceptually) → Work Management Project → Dev Sprint tickets → Service for post-sale support.
- **Agency:** Work Management Client board → Project per client (Connect Boards) → Tasks board with sub-items → Timesheet (`time_tracking` column) → Dashboard with workload chart per assignee.
- **Product team:** Dev Roadmap → Epics → Sprints (`get_monday_dev_sprints_boards`) → Bugs board → Customer feedback loop from Service tickets via Connect Boards.
- **Marketing:** `marketing_campaigns` campaign board → content brief Docs → Content calendar (Calendar widget) → asset Files columns → cross-link to CRM accounts being targeted.
- **Service desk:** Service ticket board with SLA → Customer board → escalation to Dev bug board → KB Articles (`create_article`) for self-serve.

### Seed-data techniques
- For 50–500 items, drive `create_item` in a loop via `all_monday_api` multi-mutation documents (10–25 items per request to stay under complexity).
- For 500+ items, use `backfill_items` (≤20k rows, no side effects — perfect for demo seeding) over `ingest_items`. `ingest_items` triggers automations and is for production integrations; you don't want demo seeding to fire emails.
- People columns: pull real user IDs from `list_users_and_teams` and assign them across items so the People column shows avatars.
- Dates: spread across `today - 30d` to `today + 60d`. Mix in 1–2 overdue items so red/warning states render.
- Status: distribute 30/40/20/10 across `Working on it` / `Done` / `Stuck` / blank — don't put everything in one status.
- Numbers: draw from a realistic range for the domain (deal sizes $5k–$500k, story points 1/2/3/5/8/13, ticket priorities 1–4).

### Cloning and templates
- **Duplicating a doc:** `duplicate_doc`.
- **Duplicating a board:** `duplicate_board` mutation. `DuplicateBoardType` enum (verified): `duplicate_board_with_structure` (structure only), `duplicate_board_with_pulses` (structure + items), `duplicate_board_with_pulses_and_updates` (structure + items + updates).
- **Duplicating individual content:** `duplicate_item`, `duplicate_group`.
- **Object schemas:** `create_object_schema` + `connect_board_to_object_schema` lets you define a column structure once and apply it to multiple boards. Use this when building a series of similar demo boards (e.g., one per region).
- **Managed columns:** `create_status_managed_column` + `attach_status_managed_column` on each board makes labels consistent across the demo so widgets aggregating across boards group cleanly.

### Demo tear-down / refresh
- Prefer `archive_board` / `archive_group` / `archive_item` (or generic `archive_object`) over `delete_*` so demos are recoverable. Note: workspaces have no archive — only `delete_workspace`.
- For a clean reset between sessions, use `delete_item` in a batch via `all_monday_api`, then re-seed — faster than rebuilding boards.
- Keep a `[DEMO] Master` workspace with golden-source boards. Spin up a fresh prospect demo by calling `duplicate_board` against those masters into a new `[DEMO] <Prospect>` workspace.

### Demo anti-patterns (in addition to §22)
- **Empty dashboards.** Always populate enough seed data that every widget is non-trivial.
- **Single-status items.** Distribute statuses across the spectrum.
- **Lorem ipsum / Item 1 / Test.** Use believable names — pull from a list of realistic company/contact names if needed.
- **One-product demos when multi-product is asked for.** If the prospect's pitch involves 2+ products, the demo should show cross-product flow via `board_relation` + mirrors.
- **No Docs.** A demo without a Doc looks like a half-finished build. Ship at least one per scenario.
- **No People assignments.** Empty People columns kill the visual. Spread users across items.
- **Same-day dates everywhere.** Spread dates so timeline/calendar widgets render variation.
- **Building in `Main workspace`.** Always create a dedicated `[DEMO] <Scenario>` workspace.

---

## 27. Quick reference — the verified facts you must not invent

- **Product kinds** (8): `core`, `crm`, `software`, `service`, `marketing` / `marketing_campaigns`, `project_management`, `forms`, `whiteboard`.
- **BoardKind** (3): `public`, `private`, `share`. (No "portfolio" kind — portfolios are Projects.)
- **WorkspaceKind** (3): `open`, `closed`, `template`.
- **DashboardKind** (2): `PUBLIC`, `PRIVATE`.
- **ColumnType** (40+): see §4.
- **WebhookEventType** (22): see §11.
- **Widget types** in `all_widgets_schema`: `NUMBER`, `CHART`, `BATTERY`, `CALENDAR`, `GANTT`, `LISTVIEW`, `APP_FEATURE`. Anything else is unsupported via `create_widget`.

If you find yourself about to state a fact in any of these categories that doesn't match the above, re-check via `get_type_details` — the schema may have evolved.
