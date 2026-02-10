#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/skills/file-aspire-bug"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"
ln -sf "$SKILL_SOURCE" "$SKILLS_DIR/file-aspire-bug"

echo "Installed: $SKILLS_DIR/file-aspire-bug -> $SKILL_SOURCE"
echo "Use /file-aspire-bug in any Claude Code session."
