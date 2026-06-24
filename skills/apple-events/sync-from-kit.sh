#!/usr/bin/env bash
# Sync shared docs from the apple-sync-kit repo into this skill's references/.
#
# The canonical docs live in `apple-sync-kit/docs/`. This script snapshots them
# into `references/docs/` so the skill works standalone without the kit repo.
# Re-run whenever the canonical docs are updated.
#
# Skill-specific files (SKILL.md, cloud-sync.md, evals/, worker/) are never
# touched — only references/docs/ is synced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/references/docs"

# Walk up the tree looking for a sibling apple-sync-kit/docs.
KIT_DOCS=""
dir="$SCRIPT_DIR"
while [[ "$dir" != "/" ]]; do
  candidate="$dir/apple-sync-kit/docs"
  if [[ -d "$candidate" ]]; then
    KIT_DOCS="$candidate"
    break
  fi
  dir="$(dirname "$dir")"
done

# No local checkout: shallow-clone to a temp dir.
TMP_DIR=""
if [[ -z "$KIT_DOCS" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "No local apple-sync-kit found; cloning from origin into $TMP_DIR ..."
  git clone --depth 1 https://github.com/FradSer/apple-sync-kit.git "$TMP_DIR/kit"
  KIT_DOCS="$TMP_DIR/kit/docs"
fi

if [[ ! -d "$KIT_DOCS" ]]; then
  echo "error: canonical docs not found at $KIT_DOCS" >&2
  exit 1
fi

echo "Syncing shared docs from: $KIT_DOCS"
echo "              into skill at: $DEST"

mkdir -p "$DEST"
# -c (checksum) so content-only edits sync even when size and mtime coincide;
# plain -a compares size+mtime and would silently skip them.
rsync -ac --delete \
  --exclude 'plans/' \
  --exclude 'retros/' \
  "$KIT_DOCS/" "$DEST/"

echo "Done. Synced files:"
ls "$DEST"
