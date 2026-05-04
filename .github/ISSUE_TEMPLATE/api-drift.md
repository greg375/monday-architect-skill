---
name: API drift
about: Something in the skill no longer matches the live monday API
title: "[drift] <short summary>"
labels: drift
---

**Skill version installed:** <!-- run `head -10 ~/.claude/skills/monday-architect/SKILL.md` and paste the version line -->

**API version your account is on:** <!-- run `query { version { kind value } }` via the MCP -->

**What the skill says:** <!-- quote the line from SKILL.md, with section number if possible -->

**What the live API actually returns:** <!-- paste the relevant introspection output -->

**How you noticed:** Did `/refresh-monday-skill` flag this, or did a build fail at runtime?

**Suggested fix:** <!-- optional -->
