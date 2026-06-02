#!/usr/bin/env bash
set -euo pipefail

# verify-linux-build.sh
#
# Docker-based Linux build verification for the event CLI.
# Uses swift:6.0-jammy to confirm the project compiles and runs on Linux
# without any EventKit dependencies leaking into cross-platform modules.

IMAGE="swift:6.0-jammy"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# MARK: - Preflight

if ! command -v docker &>/dev/null; then
  echo "FAIL: docker is not installed or not in PATH"
  exit 1
fi

echo "==> Verifying Docker is responsive..."
docker info >/dev/null 2>&1 || {
  echo "FAIL: docker daemon is not running"
  exit 1
}

echo "==> Using image: $IMAGE"
echo "==> Project directory: $PROJECT_DIR"
echo ""

# MARK: - Step 1: swift build

echo "--- Step 1/6: swift build on Linux ---"
if ! docker run --rm \
  -v "$PROJECT_DIR":/app \
  -w /app \
  "$IMAGE" \
  bash -c "swift build 2>&1"; then
  echo "FAIL: swift build failed on Linux"
  exit 1
fi
echo "PASS: swift build succeeded"
echo ""

# MARK: - Step 2: EventModelsTests

echo "--- Step 2/6: swift test --filter EventModelsTests ---"
if ! docker run --rm \
  -v "$PROJECT_DIR":/app \
  -w /app \
  "$IMAGE" \
  bash -c "swift test --filter EventModelsTests 2>&1"; then
  echo "FAIL: EventModelsTests failed on Linux"
  exit 1
fi
echo "PASS: EventModelsTests passed"
echo ""

# MARK: - Step 3: EventSyncTests

echo "--- Step 3/6: swift test --filter EventSyncTests ---"
if ! docker run --rm \
  -v "$PROJECT_DIR":/app \
  -w /app \
  "$IMAGE" \
  bash -c "swift test --filter EventSyncTests 2>&1"; then
  echo "FAIL: EventSyncTests failed on Linux"
  exit 1
fi
echo "PASS: EventSyncTests passed"
echo ""

# MARK: - Step 4: event --help

echo "--- Step 4/6: .build/debug/event --help ---"
HELP_OUTPUT=""
if ! HELP_OUTPUT=$(docker run --rm \
  -v "$PROJECT_DIR":/app \
  -w /app \
  "$IMAGE" \
  bash -c ".build/debug/event --help 2>&1"); then
  echo "FAIL: event --help failed to run on Linux"
  exit 1
fi

echo "$HELP_OUTPUT"

if echo "$HELP_OUTPUT" | grep -q "USAGE"; then
  echo "PASS: event --help output is valid"
else
  echo "FAIL: event --help output does not contain expected content"
  exit 1
fi
echo ""

# MARK: - Step 5: No EventKit imports in cross-platform modules

echo "--- Step 5/6: Verify no EventKit imports in EventModels/EventSync ---"
EVENTKIT_IMPORTS=$(grep -r "import EventKit" \
  "$PROJECT_DIR/Sources/EventModels" \
  "$PROJECT_DIR/Sources/EventSync" \
  2>/dev/null || true)

if [ -n "$EVENTKIT_IMPORTS" ]; then
  echo "FAIL: Found EventKit imports in cross-platform modules:"
  echo "$EVENTKIT_IMPORTS"
  exit 1
fi
echo "PASS: No EventKit imports in EventModels or EventSync"
echo ""

# MARK: - Step 6: No EventKit strings in Linux binary

echo "--- Step 6/6: Check binary for EventKit string references ---"
EVENTKIT_STRINGS=""
if ! EVENTKIT_STRINGS=$(docker run --rm \
  -v "$PROJECT_DIR":/app \
  -w /app \
  "$IMAGE" \
  bash -c "strings .build/debug/event | grep -i eventkit || true"); then
  echo "FAIL: Could not inspect Linux binary"
  exit 1
fi

if [ -n "$EVENTKIT_STRINGS" ]; then
  echo "FAIL: Found EventKit references in Linux binary:"
  echo "$EVENTKIT_STRINGS"
  exit 1
fi
echo "PASS: No EventKit references in Linux binary"
echo ""

# MARK: - Summary

echo "=============================="
echo "All Linux verification checks passed."
echo "=============================="
