# Cloud Sync Setup (`event sync`)

`event sync` syncs reminders, calendar events, and lists across devices through
a Cloudflare Worker backed by D1. This is a one-time setup; afterward you just
run `event sync`.

The Worker is the canonical one in the `apple-sync-kit` repo; the same Worker
also backs the `note` CLI. The recommended setup is **one shared Worker + one
D1 serving all five tables** (`reminders`, `calendar_events`, `reminder_lists`,
`notes`, `note_folders`), with both CLIs pointed at the same URL and token. This
skill does not bundle the Worker source — when you need to deploy,
`./references/fetch-worker.sh` pulls it into a gitignored `references/worker/`
scratch directory.

The local side of the sync depends on the platform: macOS bridges EventKit and
D1, while Linux (and other non-Apple platforms) bridges a local SQLite database
at `~/.local/share/event-sync/local.db` and D1. On Linux, `event sync` is the
first step on a fresh machine — it populates that local database before the
`event reminders` / `calendar` / `lists` commands have anything to show.

## 1. Deploy the Worker (one-time)

**Already running the shared Worker for `note`?** Skip this section — just set
`EVENT_SYNC_API_URL` / `EVENT_SYNC_API_TOKEN` to that Worker's URL and token in
step 3.

Otherwise fetch the canonical Worker and deploy it once for both CLIs:

```bash
./references/fetch-worker.sh              # pulls the canonical Worker into references/worker/
cd references/worker && pnpm install
pnpm exec wrangler login
pnpm exec wrangler d1 create apple-sync   # copy the database_id into wrangler.toml
cp wrangler.toml.example wrangler.toml    # defaults to all five tables + migrations/all
# fill in database_id in wrangler.toml (ENTITIES + migrations_dir already set for the shared setup)
pnpm run db:migrate:remote                # one pass: creates all five tables
openssl rand -hex 32 | pnpm exec wrangler secret put API_TOKEN   # auto-generate and set a strong shared token
pnpm run deploy                           # prints https://<worker>.workers.dev
```

For an `event`-only deployment, set
`ENTITIES="reminders,calendar_events,reminder_lists"` and
`migrations_dir="migrations/events"` in `wrangler.toml` before migrating.

Upgrading an existing deployment: the pull cursor is keyed on a monotonic `seq`
column added by migration `0002_events_seq_cursor`. After pulling new changes,
re-run `pnpm run db:migrate:remote` then `pnpm run deploy`. Devices still holding
an older timestamp cursor self-heal on their next pull (they restart once and
re-converge), so no client action is needed.

## 2. Generate the encryption key (one-time)

Reminders and calendar events are end-to-end encrypted before they leave the
device, so sync **requires** an encryption key. Generate it once and use the
**same value on every device** (lists are not encrypted and need no key):

```bash
openssl rand -base64 32   # generate once; copy this exact value to every device
```

Without a matching `EVENT_ENCRYPTION_KEY`, `event sync push`/`pull` of reminders
and calendar events fails immediately (the device cannot encrypt outgoing data
or decrypt what other devices wrote). Lose the key and the encrypted cloud data
becomes unrecoverable — keep it in a password manager.

## 3. Configure each device

Set three environment variables — add them to `~/.zshrc` (or `~/.bashrc`) so they
persist across shells:

```bash
export EVENT_SYNC_API_URL=https://<your-worker>.workers.dev
export EVENT_SYNC_API_TOKEN=<the API_TOKEN from step 1>
export EVENT_ENCRYPTION_KEY=<the base64 key from step 2>   # identical on every device
# EVENT_SYNC_DEVICE_ID is optional; defaults to the machine hostname
```

When sharing one Worker with `note`, `EVENT_SYNC_API_URL` / `NOTE_SYNC_API_URL`
point at the same URL and `EVENT_SYNC_API_TOKEN` / `NOTE_SYNC_API_TOKEN` hold the
same token. The encryption keys stay independent — `EVENT_ENCRYPTION_KEY` is
event-specific and the Worker only ever stores ciphertext.

Verify with `event sync status` — it should report `Config source: environment
variables`. If the connection env vars are unset, `event` falls back to a config
file written by `event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>`;
`EVENT_ENCRYPTION_KEY` is read from the environment only and is never written to
that file.

### Headless / systemd services

Shell profiles (`~/.bashrc`, `~/.zshrc`) only affect interactive shells. If
`event` runs inside a systemd-managed service (e.g. an agent gateway), the
service process inherits **none** of those exports. See
[Systemd Deployment](references/docs/systemd-deployment.md) for the full setup
(env file + systemd drop-in).

## 4. Sync

```bash
event sync   # full bidirectional sync: pull, then push
```

Run it on each device. The device id (hostname by default) keeps devices
distinct, and a device never pulls back its own writes. On Linux, run this first
on a new machine to populate the local SQLite database before reading data with
the other `event` commands.

## Notes

- Encryption is mandatory for reminders and calendar events and uses AES-GCM:
  sensitive fields (notes, URL, location, alarms, recurrence, attendees) are
  sealed before upload and stored as ciphertext in the cloud; title, list, and
  dates stay plaintext so search still works. If `event sync` errors with a
  message about `EVENT_ENCRYPTION_KEY` not being configured, the key is unset or
  doesn't match — re-export the same base64 value used on your other devices.
- Calendar sync covers events from one year in the past to two years ahead;
  events outside this window are not pushed or pulled, but are not deleted from
  the cloud while they still exist locally.
- The pull cursor is keyed on a monotonic per-table `seq` (assigned by the
  Worker as `MAX(seq)+1` on every write), not on a wall-clock timestamp, so a
  change can never be stranded by a cursor that sits above it.
- Conflicts resolve by last-write-wins: a pull never overwrites a local copy
  modified more recently than the server's version. When the local store
  (EventKit on macOS, SQLite on Linux) provides no modification or creation
  timestamp, the local copy is left unchanged until the next push.
- Reminder lists carry no modification timestamp; concurrent renames resolve
  by last-write-wins on pull with no conflict warning.
- Advanced reminder fields (`tags`, `flagged`, subtask relationships) are
  macOS/Shortcut-only and are not applied during sync pull. Basic fields plus
  `url`, `location`, `alarms`, `recurrenceRules`, and calendar `attendees` are
  part of the sync payload and are restored on pull.
- A daily cron on the Worker purges records soft-deleted over 30 days ago.
