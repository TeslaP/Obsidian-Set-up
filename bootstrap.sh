#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_PATH="${VAULT_PATH:-$HOME/notes.md}"
SKILLS_DIR="$HOME/.claude/skills"

echo "=== Obsidian + Claude Code bootstrap ==="
echo "Vault path: $VAULT_PATH"
echo "Skills dir: $SKILLS_DIR"
echo ""

# --- Obsidian vault structure ---
echo "Creating vault folder structure..."
mkdir -p "$VAULT_PATH"/{Decisions,Inbox,Notes/Meetings,People,Summaries,"Weekly updates","Bi-weekly updates"}

# Copy .obsidian config
echo "Installing Obsidian config..."
mkdir -p "$VAULT_PATH/.obsidian/plugins/dataview"
cp "$SCRIPT_DIR/obsidian/.obsidian/app.json" "$VAULT_PATH/.obsidian/"
cp "$SCRIPT_DIR/obsidian/.obsidian/appearance.json" "$VAULT_PATH/.obsidian/"
cp "$SCRIPT_DIR/obsidian/.obsidian/community-plugins.json" "$VAULT_PATH/.obsidian/"
cp "$SCRIPT_DIR/obsidian/.obsidian/core-plugins.json" "$VAULT_PATH/.obsidian/"
cp "$SCRIPT_DIR/obsidian/.obsidian/graph.json" "$VAULT_PATH/.obsidian/"
cp "$SCRIPT_DIR/obsidian/.obsidian/plugins/dataview/manifest.json" "$VAULT_PATH/.obsidian/plugins/dataview/"

# Copy templates
echo "Installing templates..."
cp "$SCRIPT_DIR/obsidian/templates/decision_template.md" "$VAULT_PATH/Decisions/_template.md"
cp "$SCRIPT_DIR/obsidian/templates/person_template.md" "$VAULT_PATH/People/_template.md"

# Vault .gitignore (for if you git-init the vault itself)
if [ ! -f "$VAULT_PATH/.gitignore" ]; then
  cat > "$VAULT_PATH/.gitignore" <<'GITIGNORE'
.obsidian/workspace*.json
.obsidian/cache/
.trash/
Notes/.smart-env/
.DS_Store
**/.DS_Store
**/*.mp4
**/*.m4a
**/*.wav
GITIGNORE
  echo "Created vault .gitignore"
fi

echo ""

# --- Claude Code skills ---
echo "Installing custom skills..."
mkdir -p "$SKILLS_DIR"

for skill in meeting-summary weekly-update; do
  if [ -d "$SKILLS_DIR/$skill" ]; then
    echo "  Updating $skill..."
    rm -rf "$SKILLS_DIR/$skill"
  else
    echo "  Installing $skill..."
  fi
  cp -r "$SCRIPT_DIR/skills/$skill" "$SKILLS_DIR/$skill"
done

echo ""

# --- Zoom recording path reminder ---
echo "=== Manual steps ==="
echo ""
echo "1. Open Obsidian and point it at: $VAULT_PATH"
echo "   Obsidian will auto-install the dataview plugin from community-plugins.json"
echo ""
echo "2. Route Zoom local recordings to the vault:"
echo "   Zoom > Settings > Recording > Local Recording > Change"
echo "   Set path to: $VAULT_PATH/Notes/Meetings/"
echo "   Enable: 'Create audio transcript'"
echo ""
echo "3. (Optional) Set up vault backup:"
echo "   cd $VAULT_PATH && git init && git remote add origin <your-remote>"
echo "   See scripts/vault-backup.sh in the project repo for daily auto-commit"
echo ""
echo "Done."
