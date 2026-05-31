#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="aspire-release-blog"
SKILL_SOURCE="$SCRIPT_DIR/skills/$SKILL_NAME"
SKILLS_DIR="${COPILOT_SKILLS_DIR:-$HOME/.copilot/skills}"
SKILL_TARGET="$SKILLS_DIR/$SKILL_NAME"

if [[ ! -d "$SKILL_SOURCE" ]]; then
  echo "Skill source not found: $SKILL_SOURCE" >&2
  exit 1
fi

mkdir -p "$SKILLS_DIR"
ln -sfn "$SKILL_SOURCE" "$SKILL_TARGET"

echo "Installed $SKILL_NAME to $SKILL_TARGET"
echo "Run Copilot CLI from your aspire-blog checkout and invoke /$SKILL_NAME <version>"
