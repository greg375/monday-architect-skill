# Scheduled drift detection

The `/refresh-monday-skill` skill runs on demand and edits files in `~/.claude/skills/`. If you want **automatic** monthly drift checks (so you don't forget), you can wire one up via Claude Code's scheduled remote agents. Because remote agents run in Anthropic's cloud, they can't patch your local skill files directly — but they can detect drift and notify you.

## What you'll set up

A monthly recurring routine that:
1. Connects to your monday.com MCP.
2. Runs the same introspection checks `/refresh-monday-skill` runs locally.
3. Reports drift to a notification destination of your choice.
4. Stays silent on clean runs.

When you see a drift report, you run `/refresh-monday-skill` locally to apply the patches.

## Pick your notification destination

The remote agent needs *somewhere* to deliver the drift report. Pick whichever you have connected:

| Destination | Connector required | Best for |
|---|---|---|
| **Slack DM** | Slack MCP | Fast, low-friction. Use if Slack is your daily driver. |
| **Gmail draft** | Gmail MCP | Audit trail in your inbox. Drafts (not auto-sent) so you review before action. |
| **monday item** | monday MCP (already attached) | Keeps drift history inside monday on a "skill maintenance" board. No extra connector needed. |
| **Claude Code routines UI** | None | Just check https://claude.ai/code/routines manually after the 1st of each month. Lowest friction; easiest to forget. |

Connect any missing connectors at https://claude.ai/customize/connectors before setting up the routine.

If you have **no notification connector available** and don't want to add one, the "Claude Code routines UI" option works — the routine still runs and produces a report, you just have to remember to look.

## Setup

In Claude Code, run:

```
/schedule
```

When the schedule skill asks what you want, paste a variant of this (replace the destination block with your choice):

> Create a monthly recurring scheduled agent that runs on the 1st of each month at 09:00 in my local timezone. The agent should:
>
> 1. Clone https://github.com/greg375/monday-architect-skill so it has access to the canonical `skills/monday-architect/SKILL.md`.
> 2. Connect to my monday.com MCP and introspect the live schema (run `get_user_context`, `get_graphql_schema` for read+write, `all_widgets_schema`, and `get_type_details` for: BoardKind, WorkspaceKind, DashboardKind, ColumnType, WebhookEventType, WorkspacesQueryAccountProductKind, ViewKind, SearchStrategy, NotificationTargetType, DuplicateBoardType, BoardMuteState; plus `{ version { kind value } }`).
> 3. Compare every result against the canonical facts in §25 and §27 of `SKILL.md`.
> 4. **If drift is detected:** \[INSERT YOUR DESTINATION CHOICE — see options below].
> 5. If no drift, stay silent (no notification, just log to the routines UI).

### Destination snippets

**Slack DM:**
> Send a Slack DM to my user (resolve via `slack_search_users(query: "<my name>")` first) with a concise drift report (max 30 lines), formatted as: title line with date and API version, counts of drift/gone/new findings, one-line per finding, and a footer pointing at https://github.com/greg375/monday-architect-skill telling me to run `/refresh-monday-skill` locally.

**Gmail draft:**
> Create a Gmail draft to my own email address with the subject "monday-architect drift detected — \<date>" and a concise body (max 30 lines): counts of drift/gone/new findings, one-line per finding, and a footer pointing at https://github.com/greg375/monday-architect-skill telling me to run `/refresh-monday-skill` locally. Do not send — just save as a draft.

**monday item:**
> Create an item on monday board <BOARD_ID> in group <GROUP_ID> with the item name "Drift report — \<date>" and an update post on it containing the full report (max 30 lines). Use `create_item` then `create_update`. The board should be a "skill maintenance" board you've created in advance for this purpose.

**Claude Code routines UI only:**
> Just print the report to your output. Do not send any external notification.

## What the routine cannot do

- **It cannot patch your local skill files.** The remote agent has no access to `~/.claude/skills/` on your machine. After receiving a drift report, run `/refresh-monday-skill` locally to apply patches with the live schema in context.
- **It cannot test demo build flows end-to-end.** Schema introspection catches renamed/removed mutations and changed enum values, but not behavioral changes (e.g. a mutation that still exists but now requires a permission it didn't before, or a feature that's been quietly disabled). For high-stakes demos, run a manual end-to-end test in a throwaway workspace.

## Cron schedule reference

Cron expressions are UTC. Most timezones with DST will drift one hour twice a year on a monthly check — pick whichever cron value gets you "9am-ish year-round."

| Local time | Approx cron (UTC) |
|---|---|
| Europe/London 09:00 | `0 8 1 * *` (BST) / `0 9 1 * *` (GMT). Use `0 8 1 * *` year-round. |
| Europe/Paris 09:00 | `0 7 1 * *` (CEST) / `0 8 1 * *` (CET). Use `0 7 1 * *` year-round. |
| America/New_York 09:00 | `0 13 1 * *` (EDT) / `0 14 1 * *` (EST). Use `0 13 1 * *` year-round. |
| America/Los_Angeles 09:00 | `0 16 1 * *` (PDT) / `0 17 1 * *` (PST). Use `0 16 1 * *` year-round. |
| UTC 09:00 | `0 9 1 * *` |

For a monthly run, the DST drift (one hour) is negligible.

## Maintenance loop summary

```
[1st of month, 09:00 local]
        │
        ▼
Remote routine runs introspection
        │
        ├─ No drift → silent (just logs to routine UI)
        │
        └─ Drift detected → notification (Slack / Gmail / monday)
                │
                ▼
        You run /refresh-monday-skill locally
                │
                ▼
        Skill patches applied → commit + push to repo
                │
                ▼
        Other users `git pull` to update their copy
```

## Manual alternative

If you don't want a scheduled agent, just remember to run `/refresh-monday-skill` before any high-stakes demo, or set yourself a calendar reminder for the 1st of each month.
