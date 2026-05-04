#!/usr/bin/env bash
# Install monday-architect + refresh-monday-skill into ~/.claude/skills/
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/greg375/monday-architect-skill/main/install.sh | bash
# or:
#   ./install.sh

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
REPO_RAW="https://raw.githubusercontent.com/greg375/monday-architect-skill/main"

echo "Installing monday-architect skill into ${SKILLS_DIR}"

mkdir -p "${SKILLS_DIR}/monday-architect"
mkdir -p "${SKILLS_DIR}/refresh-monday-skill"

# If running inside a clone, copy from local; otherwise fetch.
if [[ -f "$(dirname "$0")/skills/monday-architect/SKILL.md" ]]; then
  cp "$(dirname "$0")/skills/monday-architect/SKILL.md" "${SKILLS_DIR}/monday-architect/SKILL.md"
  cp "$(dirname "$0")/skills/refresh-monday-skill/SKILL.md" "${SKILLS_DIR}/refresh-monday-skill/SKILL.md"
else
  curl -fsSL "${REPO_RAW}/skills/monday-architect/SKILL.md" -o "${SKILLS_DIR}/monday-architect/SKILL.md"
  curl -fsSL "${REPO_RAW}/skills/refresh-monday-skill/SKILL.md" -o "${SKILLS_DIR}/refresh-monday-skill/SKILL.md"
fi

INSTALLED_VERSION="$(grep '^version:' "${SKILLS_DIR}/monday-architect/SKILL.md" | head -1 | sed 's/version: //')"
echo "✓ monday-architect ${INSTALLED_VERSION} installed."
echo "✓ refresh-monday-skill installed."
echo ""
echo "Next steps:"
echo "  1. Connect the monday.com MCP at https://claude.ai/customize/connectors"
echo "  2. Open Claude Code and start a fresh session — the skill will auto-trigger on any monday-related prompt."
echo "  3. To verify the skill against your account, run: /refresh-monday-skill"
