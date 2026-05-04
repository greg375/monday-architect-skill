# Install on Claude.ai (web or desktop app) as native Skills

If your Claude.ai account has the Skills feature enabled (visible in your account settings as **Capabilities → Skills** or similar), you can upload this skill directly without using a Project workaround.

This is now the recommended path for non-Claude-Code users. Once uploaded, the skill auto-triggers on relevant prompts the same way it does in Claude Code — no Project setup, no custom-instructions length cap, no manual re-paste on updates.

## Install steps

1. Go to the [latest GitHub release](https://github.com/greg375/monday-architect-skill/releases/latest) and download both zip files:
   - `monday-architect.zip` — the operator's manual (auto-triggers on monday topics)
   - `refresh-monday-skill.zip` — the drift detector (run via `/refresh-monday-skill`)

2. Open Claude.ai (web or desktop app) → **Settings** → **Capabilities** (or **Skills**, depending on your version).

3. Click **Upload skill** (or **Add skill**) and select `monday-architect.zip`. Repeat for `refresh-monday-skill.zip`.

4. Connect the **monday.com MCP connector** at https://claude.ai/customize/connectors if you haven't already.

5. Start a new chat and test:
   > "Plan a sales pipeline demo on monday with deals, accounts, contacts, and an exec dashboard."

   The skill should auto-trigger; you'll see the planning output follow the §Phase-2 blueprint structure.

## Updating to a newer version

When the repo ships a new release:

1. Download the new zips from the [releases page](https://github.com/greg375/monday-architect-skill/releases).
2. In Claude.ai → **Capabilities → Skills**, remove the old version of each skill.
3. Upload the new zips.

(Or run `/refresh-monday-skill` in any Claude session to detect drift before deciding whether to update.)

## How does this differ from the Claude Code install?

| | Claude Code | Claude.ai Skills upload | Claude.ai Project (legacy fallback) |
|---|---|---|---|
| Auto-triggers on monday topics | ✅ | ✅ | ⚠️ Always-on (heavier on context) |
| `/refresh-monday-skill` command | ✅ | ✅ | ❌ |
| Update via single command | ✅ `git pull && bash install.sh` | ⚠️ Manual: download + re-upload | ❌ Manual paste |
| Length cap | None | None (skills are loaded on demand) | ~30K char custom instructions |
| Distribution to teammates | Repo + install.sh | Send them the zips or repo link | Each teammate creates their own Project |

**Recommendation:** if your Claude.ai account has Skills enabled, use this path. It's strictly better than the Project approach.

## If your account doesn't have Skills

Skills was rolled out in stages. If you don't see a **Capabilities → Skills** option in settings, fall back to the [Project setup](claude-ai-project-setup.md) — paste-and-go custom instructions instead.
