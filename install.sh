#!/usr/bin/env bash
set -euo pipefail

# install.sh
#
# Fork-local installer: builds the event Swift CLI, builds the mcp-server
# (local stdio MCP server for Claude Desktop), and registers the event MCP
# server in Claude Desktop's config. Unlike upstream's Homebrew tap, this
# covers the mcp-server/ addition that only exists in this fork.
#
# Safe to re-run on the same machine (idempotent): rebuilds both components
# and overwrites only the "event" entry in Claude Desktop's mcpServers,
# leaving any other configured servers untouched.

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

echo "==> Installing event CLI + mcp-server from: $PROJECT_DIR"
echo ""

# MARK: - Preflight

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "FAIL: this installer is macOS-only (EventKit + Claude Desktop are Mac-only)."
  exit 1
fi

if ! command -v swift &>/dev/null; then
  echo "FAIL: swift is not installed or not in PATH. Install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

if ! command -v node &>/dev/null; then
  echo "FAIL: node is not installed or not in PATH. mcp-server requires Node.js >=20."
  exit 1
fi

NODE_MAJOR="$(node -e 'console.log(process.versions.node.split(".")[0])')"
if [[ "$NODE_MAJOR" -lt 20 ]]; then
  echo "FAIL: node $(node -v) found, but mcp-server requires Node.js >=20."
  exit 1
fi

if ! command -v pnpm &>/dev/null; then
  echo "FAIL: pnpm is not installed or not in PATH. Install it:"
  echo "  npm install -g pnpm"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "FAIL: python3 is not installed or not in PATH (needed to merge the Claude Desktop config)."
  exit 1
fi

echo "==> Preflight OK: swift, node $(node -v), pnpm $(pnpm --version), python3 all present"
echo ""

# MARK: - Step 1: Build the event CLI

echo "==> Building event CLI (swift build -c release)..."
(cd "$PROJECT_DIR" && swift build -c release)

EVENT_BINARY="$PROJECT_DIR/.build/release/event"
if [[ ! -x "$EVENT_BINARY" ]]; then
  echo "FAIL: build succeeded but $EVENT_BINARY is missing or not executable."
  exit 1
fi

# MARK: - Step 2: Install the event CLI to /usr/local/bin

echo "==> Installing event CLI to /usr/local/bin/event..."
if [[ -w /usr/local/bin ]]; then
  cp "$EVENT_BINARY" /usr/local/bin/event
  chmod 755 /usr/local/bin/event
  echo "    Installed: $(/usr/local/bin/event --version)"
else
  echo "    /usr/local/bin is not writable by $(whoami) — run this yourself, then re-run install.sh:"
  echo ""
  echo "      sudo cp \"$EVENT_BINARY\" /usr/local/bin/event"
  echo "      sudo chmod 755 /usr/local/bin/event"
  echo ""
  echo "    Continuing with the mcp-server build; event CLI install is still pending."
fi
echo ""

# MARK: - Step 3: Build mcp-server

echo "==> Building mcp-server (pnpm install && pnpm build)..."
(cd "$PROJECT_DIR/mcp-server" && pnpm install && pnpm build)

MCP_INDEX="$PROJECT_DIR/mcp-server/dist/index.js"
if [[ ! -f "$MCP_INDEX" ]]; then
  echo "FAIL: mcp-server build succeeded but $MCP_INDEX is missing."
  exit 1
fi
echo ""

# MARK: - Step 4: Register the event MCP server in Claude Desktop's config

echo "==> Configuring Claude Desktop (merging into mcpServers.event)..."
python3 - "$CLAUDE_DESKTOP_CONFIG" "$MCP_INDEX" <<'PYEOF'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
mcp_index_path = sys.argv[2]

if config_path.exists():
    raw = config_path.read_text()
    try:
        config = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError as e:
        backup = config_path.with_suffix(config_path.suffix + ".bak")
        backup.write_text(raw)
        print(f"    WARN: existing config was not valid JSON ({e}).", file=sys.stderr)
        print(f"    Backed up unparseable config to {backup}, starting fresh.", file=sys.stderr)
        config = {}
else:
    config = {}

config.setdefault("mcpServers", {})
config["mcpServers"]["event"] = {
    "command": "node",
    "args": [mcp_index_path],
}

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(config, indent=2) + "\n")
print(f"    Updated {config_path}")
PYEOF
echo ""

# MARK: - Done

echo "==> Done."
echo ""
echo "Next steps:"
echo "  1. Quit and reopen Claude Desktop to pick up the new mcpServers.event entry."
echo "  2. On first tool call, macOS will prompt for Reminders/Calendar access — approve it."
echo "  3. Optional: install the AdvancedReminderEdit Shortcut for tags/flagged/url/subtasks:"
echo "     https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808"
