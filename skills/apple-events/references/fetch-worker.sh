#!/usr/bin/env bash
# Fetch the canonical D1 sync Worker from the apple-sync-kit repo into this skill.
#
# The Worker source lives canonically in `apple-sync-kit/worker/`. This skill
# does NOT commit a copy; run this script when you need to deploy to populate a
# gitignored `references/worker/` scratch directory. Re-run it to update.
#
# Your filled-in `wrangler.toml` (database_id, ENTITIES, migrations_dir) is
# preserved across re-fetches; everything else is overwritten from canonical.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
DEST="$SCRIPT_DIR/worker"

# Prefer a local sibling checkout (fast, offline, reflects uncommitted work).
# Walk up the tree looking for a sibling `apple-sync-kit/worker` so the script
# works regardless of how deep this skill sits under the workspace root.
KIT_DIR=""
dir="$SCRIPT_DIR"
while [[ "$dir" != "/" ]]; do
  candidate="$dir/apple-sync-kit/worker"
  if [[ -f "$candidate/src/index.ts" ]]; then
    KIT_DIR="$candidate"
    break
  fi
  dir="$(dirname "$dir")"
done

# No local checkout: shallow-clone the canonical repo to a temp dir.
TMP_DIR=""
if [[ -z "$KIT_DIR" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "No local apple-sync-kit found; cloning from origin into $TMP_DIR ..."
  git clone --depth 1 https://github.com/FradSer/apple-sync-kit.git "$TMP_DIR/kit"
  KIT_DIR="$TMP_DIR/kit/worker"
fi

if [[ ! -f "$KIT_DIR/src/index.ts" ]]; then
  echo "error: canonical Worker not found at $KIT_DIR/src/index.ts" >&2
  exit 1
fi

echo "Fetching canonical Worker from: $KIT_DIR"
echo "          into this skill at: $DEST"

mkdir -p "$DEST"

# rsync the canonical tree into the gitignored scratch dir. Preserve only the
# filled-in wrangler.toml and local build state; everything else comes from
# canonical.
rsync -a --delete \
  --exclude 'wrangler.toml' \
  --exclude 'node_modules' \
  --exclude '.wrangler' \
  --exclude 'pnpm-lock.yaml' \
  "$KIT_DIR/" "$DEST/"

# The canonical test suite targets the kit repo's shared wrangler.toml (all five
# entities) and does not pass against a narrower consumer config. Drop it here;
# run tests in the kit repo instead.
rm -rf "$DEST/test"

echo "Done. Next: cd worker && pnpm install && pnpm exec wrangler deploy"
