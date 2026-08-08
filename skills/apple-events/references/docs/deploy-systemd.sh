#!/usr/bin/env bash
# deploy-systemd.sh — wire a sync CLI's credentials into a systemd user service.
#
# Why this exists: systemd user services do NOT inherit interactive shell
# profiles (~/.bashrc, ~/.zshrc), so exporting the sync vars there has no effect
# on a long-running service such as an agent gateway. The robust mechanism is a
# systemd EnvironmentFile drop-in. This script writes that env file (mode 0600)
# and the drop-in, reloads, restarts the service, and verifies the variables
# landed in the running process — idempotently, so it is safe to re-run.
#
# Credentials are read from the environment, never passed as argv, so they never
# appear in `ps`. Provide them inline or source an existing env file first.
#
# Usage:
#   NOTE_SYNC_API_URL=https://<worker>.workers.dev \
#   NOTE_SYNC_API_TOKEN=<token> \
#   NOTE_ENCRYPTION_KEY=<base64 key> \
#     ./deploy-systemd.sh note <service>      # e.g. openclaw-gateway
#
#   # event uses the EVENT_* vars and `event`:
#   EVENT_SYNC_API_URL=... EVENT_SYNC_API_TOKEN=... EVENT_ENCRYPTION_KEY=... \
#     ./deploy-systemd.sh event <service>
#
# <PREFIX>_SYNC_DEVICE_ID is optional and defaults to the short hostname.
set -euo pipefail

CLI="${1:-}"
SERVICE="${2:-}"

usage() { echo "usage: $0 <note|event> <systemd-user-service>" >&2; exit 2; }
[[ -n "$CLI" && -n "$SERVICE" ]] || usage

case "$CLI" in
  note)  PREFIX=NOTE;  NS=note-sync ;;
  event) PREFIX=EVENT; NS=event-sync ;;
  *) echo "error: unknown cli '$CLI' (expected note or event)" >&2; usage ;;
esac

url_var="${PREFIX}_SYNC_API_URL"
token_var="${PREFIX}_SYNC_API_TOKEN"
key_var="${PREFIX}_ENCRYPTION_KEY"
dev_var="${PREFIX}_SYNC_DEVICE_ID"

url="${!url_var:-}"
token="${!token_var:-}"
key="${!key_var:-}"
device="${!dev_var:-$(hostname -s)}"

missing=()
[[ -n "$url" ]]   || missing+=("$url_var")
[[ -n "$token" ]] || missing+=("$token_var")
[[ -n "$key" ]]   || missing+=("$key_var")
if (( ${#missing[@]} )); then
  echo "error: missing required env vars: ${missing[*]}" >&2
  exit 1
fi

CONF_DIR="$HOME/.config/$NS"
CONF_FILE="$CONF_DIR/env.conf"
DROPIN_DIR="$HOME/.config/systemd/user/${SERVICE}.service.d"
DROPIN_FILE="$DROPIN_DIR/${NS}.conf"

# 1. Credential env file, locked down to the owner.
mkdir -p "$CONF_DIR"
( umask 077
  cat > "$CONF_FILE" <<EOF
${PREFIX}_SYNC_API_URL=$url
${PREFIX}_SYNC_API_TOKEN=$token
${PREFIX}_ENCRYPTION_KEY=$key
${PREFIX}_SYNC_DEVICE_ID=$device
EOF
)
chmod 600 "$CONF_FILE"
echo "wrote $CONF_FILE (0600)"

# 2. systemd drop-in pointing the service at that env file.
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<EOF
[Service]
EnvironmentFile=$CONF_FILE
EOF
echo "wrote $DROPIN_FILE"

# 3. Reload units and restart the service so it picks up the env file.
systemctl --user daemon-reload
systemctl --user restart "$SERVICE"
echo "restarted $SERVICE"

# 4. Verify the variables are actually present in the running process.
pid="$(systemctl --user show -p MainPID --value "$SERVICE" 2>/dev/null || true)"
if [[ -n "$pid" && "$pid" != "0" && -r "/proc/$pid/environ" ]]; then
  if tr '\0' '\n' < "/proc/$pid/environ" | grep -q "^${url_var}="; then
    echo "verified: ${PREFIX}_* loaded into $SERVICE (pid $pid)"
  else
    echo "error: ${PREFIX}_* NOT found in $SERVICE environ (pid $pid)" >&2
    exit 1
  fi
else
  echo "note: could not read /proc/<pid>/environ for $SERVICE; skipped verify"
fi
