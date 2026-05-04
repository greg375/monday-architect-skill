# Use the skill in a Claude.ai Project (no Claude Code required)

This skill was designed for Claude Code, where it auto-triggers from `~/.claude/skills/`. If you want to use it from the regular Claude.ai web app instead — for demos, prospects, or teammates who don't use Claude Code — you can install it as a **Claude.ai Project** with custom instructions and the monday MCP connector attached.

## What you'll get

A Project on claude.ai where every new chat:
- Has the monday-architect skill loaded as the system prompt.
- Has the monday.com MCP tools available natively.
- Can plan and build full demo accounts end-to-end without you re-priming the context every time.

## Setup (5 minutes)

### 1. Create the Project

1. Open claude.ai → click **Projects** in the sidebar → **New Project**.
2. Name it: `monday demos` (or whatever fits).
3. Description: `Build, audit, and refresh monday.com demos using the verified monday-architect skill.`

### 2. Connect the monday.com MCP

In the Project settings, go to **Connectors** and connect the official monday.com MCP at <https://mcp.monday.com/mcp> (you'll be prompted to authenticate to your monday account).

If you also want Slack / Gmail / Google Calendar etc. for demo prep, attach those too.

### 3. Paste the trimmed skill as custom instructions

Open `docs/claude-ai-project-instructions.md` from this repo. Copy the entire contents into the Project's **Custom instructions** field. (It's a trimmed, demo-focused version of the full SKILL.md — the heavy advanced-API-surface sections are dropped to fit Claude.ai's instruction-length cap, while keeping all the load-bearing decision logic, value shapes, and anti-patterns.)

Save.

### 4. Test it

Start a new chat inside the Project. Say:

> Plan a sales-pipeline demo with deals, accounts, contacts, and an exec dashboard.

Claude should: pick `crm` as the product, propose a CRM-native schema with `board_relation` + `mirror`, list the dashboard widgets it'll build, and ask you to approve before executing. If it does anything else — generic Status columns, single boards with no relationships, refusing widgets — the instructions aren't loading. Re-check the Project's custom instructions field.

## What's different vs Claude Code

| Capability | Claude Code | Claude.ai Project |
|---|---|---|
| Skill auto-triggers on monday topics | ✅ via `~/.claude/skills/` | ✅ via Project custom instructions |
| Full skill content (700 lines, 65KB) | ✅ | ⚠️ Trimmed to ~30K char cap |
| `/refresh-monday-skill` drift detector | ✅ | ❌ — run it from Claude Code, then re-paste the updated instructions |
| Per-machine install (`install.sh`) | ✅ | ❌ N/A — Project is account-scoped |
| Distribution to teammates | One install command per person | Each teammate creates their own Project + pastes instructions |
| Live monday MCP | Auto-connected | Connect once per Project |

## Updating the Project when the skill ships a new version

1. Wait for a new version tag in this repo (or run `/refresh-monday-skill` from Claude Code yourself).
2. Re-copy the contents of `docs/claude-ai-project-instructions.md` into the Project's custom instructions.
3. Save. Existing chats in the Project keep their old context; new chats pick up the new instructions.

## Demo opener template

Once the Project is set up, paste this as the first message of any new demo session:

```
Building a [SCENARIO TYPE] demo for [PROSPECT NAME] in monday account [ACCOUNT].
Products available on this account: [list — confirm by asking me or via get_user_context].
Objective: [what the prospect cares about — sales pipeline, project tracking, support queue, etc.].
Cross-product story: [yes/no — if yes, which products to span].

Follow the §22 output contract: present a full plan (product, workspaces, boards, columns,
relationships, dashboards, forms, docs) before executing anything. Pause for my approval.
After approval, execute in §23 order. Use [DEMO TEST <prospect>] workspace naming.
At the end of the demo, archive the workspace (don't delete) so I can replay if needed.
```

Adapt as needed.

## Why a trimmed version

The full skill is ~65KB / 667 lines. Claude.ai Project custom instructions have a length cap (currently around 30KB / 8000 tokens at last check). The trimmed version (`claude-ai-project-instructions.md`) drops:

- The deep "verified by execution" appendices (§25 round-2 findings, §27 cheat sheet) — these were the *evidence* for the skill's claims, not the claims themselves.
- The advanced-API surface that's rarely needed in demos (audit logs, objects platform, marketplace search, schema introspection deep-dives, raw GraphQL fallback patterns).
- The §3.5/§3.6 portfolio mutation shapes (you'll only need these if a demo specifically requires Projects + Portfolios — keep the full skill installed in Claude Code for those builds).
- The §16 user/teams/permissions admin surface.

What's preserved (and what makes the skill valuable for demos):

- §0 introspection rule
- §1 product picker
- §2 workspaces + folders
- §3 object-type picker
- §4 column model with verified value shapes
- §5 cross-board relationships
- §6 items, groups, bulk operations
- §7 widget catalog with all 16 chart variants
- §8 forms
- §9 docs
- §22 anti-patterns
- §23 planning output contract
- §24 execution order
- §25 demo-build mode
