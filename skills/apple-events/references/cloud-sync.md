# Cloud Sync Setup (`event sync`)

`event sync` syncs reminders, calendar events, and lists across devices through
a Cloudflare Worker backed by D1. This is a one-time setup; afterward you just
run `event sync`.

The Worker source is bundled with this skill at `references/worker/`.

The local side of the sync depends on the platform: macOS bridges EventKit and
D1, while Linux (and other non-Apple platforms) bridges a local SQLite database
at `~/.local/share/event-sync/local.db` and D1. On Linux, `event sync` is the
first step on a fresh machine — it populates that local database before the
`event reminders` / `calendar` / `lists` commands have anything to show.

## 1. Deploy the Worker (one-time)

Run these from the bundled worker directory (`references/worker/`):

```bash
pnpm install
pnpm exec wrangler login
cp wrangler.toml.example wrangler.toml    # copy the config template
pnpm exec wrangler d1 create event-sync   # copy the database_id into wrangler.toml
pnpm run db:migrate:remote                # create the D1 tables
openssl rand -hex 32 | pnpm exec wrangler secret put API_TOKEN   # auto-generate and set a strong shared token
pnpm run deploy                           # prints https://<worker>.workers.dev
```

Upgrading an existing deployment: the pull cursor is keyed on a monotonic `seq`
column added by migration `0002_seq_cursor`. After pulling new changes, re-run
`pnpm run db:migrate:remote` then `pnpm run deploy`. Devices still holding an
older timestamp cursor self-heal on their next pull (they restart once and
re-converge), so no client action is needed.

## 2. Configure each device

Set two environment variables — add them to `~/.zshrc` (or `~/.bashrc`) so they
persist across shells:

```bash
export EVENT_SYNC_API_URL=https://<your-worker>.workers.dev
export EVENT_SYNC_API_TOKEN=<the API_TOKEN from step 1>
# EVENT_SYNC_DEVICE_ID is optional; defaults to the machine hostname
```

Verify with `event sync status` — it should report `Config source: environment
variables`. If the env vars are unset, `event` falls back to a config file
written by `event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>`.

## 3. Sync

```bash
event sync   # full bidirectional sync: pull, then push
```

Run it on each device. The device id (hostname by default) keeps devices
distinct, and a device never pulls back its own writes. On Linux, run this first
on a new machine to populate the local SQLite database before reading data with
the other `event` commands.

## Notes

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
  macOS/Shortcut-only and are not applied during sync pull; only basic fields
  are synced.
- A daily cron on the Worker purges records soft-deleted over 30 days ago.
