# Cloud Sync Setup (`event sync`)

`event sync` syncs reminders, calendar events, and lists across devices through
a Cloudflare Worker backed by D1. This is a one-time setup; afterward you just
run `event sync`.

The Worker source is bundled with this skill at `references/worker/`.

## 1. Deploy the Worker (one-time)

Run these from the bundled worker directory (`references/worker/`):

```bash
pnpm install
pnpm exec wrangler login
cp wrangler.example.toml wrangler.toml    # copy the config template
pnpm exec wrangler d1 create event-sync   # copy the database_id into wrangler.toml
pnpm run db:migrate:remote                # create the D1 tables
openssl rand -hex 32 | pnpm exec wrangler secret put API_TOKEN   # auto-generate and set a strong shared token
pnpm run deploy                           # prints https://<worker>.workers.dev
```

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
distinct, and a device never pulls back its own writes.

## Notes

- Calendar sync covers events from one year in the past to two years ahead;
  events outside this window are not pushed or pulled, but are not deleted from
  the cloud while they still exist locally.
- Conflicts resolve by last-write-wins: a pull never overwrites a local copy
  modified more recently than the server's version. When EventKit provides no
  modification or creation timestamp, the local copy is left unchanged until the
  next push.
- Reminder lists carry no modification timestamp; concurrent renames resolve
  by last-write-wins on pull with no conflict warning.
- Advanced reminder fields (`tags`, `flagged`, subtask relationships) are not
  applied during sync pull; only basic EventKit fields are synced.
- A daily cron on the Worker purges records soft-deleted over 30 days ago.
