import { Hono } from "hono";
import type { MiddlewareHandler } from "hono";
import { bearerAuth } from "hono/bearer-auth";

type Bindings = {
  DB: D1Database;
  API_TOKEN: string;
};

type PushItem = {
  id: string;
  data: unknown;
  last_modified: string;
};

type PushRequest = {
  device_id: string;
  items: PushItem[];
};

const MAX_BATCH_SIZE = 500;

// Hardcoded SQL per entity to avoid any table-name injection risk.
// Each key maps to the full set of prepared statements needed.
type EntitySQL = {
  upsert: string;
  selectPage: string;
  softDelete: string;
  purgeDeleted: string;
};

// `?4` is the requesting device: `source_device IS NOT ?4` excludes a device's
// own writes (NULL-safe), and `?4 = ''` disables the filter when no device is given.
function selectPageSQL(table: string): string {
  return (
    `SELECT id, data, deleted, updated_at, last_modified FROM ${table} ` +
    "WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) " +
    "AND (?4 = '' OR source_device IS NOT ?4) " +
    "ORDER BY updated_at ASC, id ASC LIMIT ?3"
  );
}

function upsertSQL(table: string): string {
  return (
    `INSERT INTO ${table} (id, data, last_modified, updated_at, source_device)
      VALUES (?1, ?2, ?3, datetime('now'), ?4)
      ON CONFLICT(id) DO UPDATE SET
        data = excluded.data, last_modified = excluded.last_modified,
        deleted = 0, updated_at = datetime('now'), source_device = excluded.source_device
      WHERE ${table}.last_modified <= excluded.last_modified`
  );
}

function entitySQL(table: string): EntitySQL {
  return {
    upsert: upsertSQL(table),
    selectPage: selectPageSQL(table),
    softDelete: `UPDATE ${table} SET deleted = 1, updated_at = datetime('now') WHERE id = ? AND last_modified <= ?`,
    purgeDeleted: `DELETE FROM ${table} WHERE deleted = 1 AND updated_at < datetime('now', '-30 days')`,
  };
}

const ENTITY_SQL: Record<string, EntitySQL> = {
  reminders: entitySQL("reminders"),
  calendar_events: entitySQL("calendar_events"),
  reminder_lists: entitySQL("reminder_lists"),
};

const ENTITY_NAMES = Object.keys(ENTITY_SQL);

function getSQL(entity: string): EntitySQL | null {
  return ENTITY_SQL[entity] ?? null;
}

// Normalize an ISO 8601 timestamp to UTC for consistent string comparison.
// Accepts "2026-03-10T14:00:00Z", "2026-03-10T14:00:00+08:00", or bare
// "2026-03-10 14:00:00". Returns null when the input is not a valid date.
function normalizeTimestamp(ts: string): string | null {
  const d = new Date(ts);
  if (isNaN(d.getTime())) {
    return null;
  }
  return d.toISOString();
}

// Delete soft-deleted records older than 30 days across all entities.
async function purgeExpired(db: D1Database): Promise<Record<string, number>> {
  const results = await db.batch(
    ENTITY_NAMES.map((name) => db.prepare(ENTITY_SQL[name].purgeDeleted))
  );
  const purged: Record<string, number> = {};
  for (let i = 0; i < ENTITY_NAMES.length; i++) {
    purged[ENTITY_NAMES[i]] = results[i].meta.changes ?? 0;
  }
  return purged;
}

const app = new Hono<{ Bindings: Bindings }>();

// Auth middleware for all /api/* routes. The handler is memoized per worker
// instance since the token only changes when the worker is redeployed.
let authMiddleware: MiddlewareHandler | undefined;
app.use("/api/*", (c, next) => {
  authMiddleware ??= bearerAuth({ token: c.env.API_TOKEN });
  return authMiddleware(c, next);
});

// Health check (no auth required)
app.get("/health", (c) => c.json({ status: "ok" }));

// Push: batch upsert with last-write-wins
app.post("/api/v1/:entity/push", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  let body: PushRequest;
  try {
    body = await c.req.json<PushRequest>();
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const { device_id, items } = body;

  if (!device_id || !Array.isArray(items)) {
    return c.json({ error: "Missing device_id or items" }, 400);
  }

  if (items.length === 0) {
    return c.json({ synced: 0, skipped: 0 });
  }

  if (items.length > MAX_BATCH_SIZE) {
    return c.json(
      { error: `Batch size ${items.length} exceeds maximum of ${MAX_BATCH_SIZE}` },
      400
    );
  }

  // Atomic upsert: INSERT ... ON CONFLICT with last_modified guard
  const stmts: D1PreparedStatement[] = [];
  for (const item of items) {
    if (!item || typeof item.id !== "string" || item.id.length === 0) {
      return c.json({ error: "Each item requires a non-empty string id" }, 400);
    }
    const normalizedLM = normalizeTimestamp(item.last_modified);
    if (normalizedLM === null) {
      return c.json({ error: `Invalid last_modified for item '${item.id}'` }, 400);
    }
    stmts.push(
      c.env.DB.prepare(sql.upsert).bind(
        item.id,
        JSON.stringify(item.data),
        normalizedLM,
        device_id
      )
    );
  }

  const results = await c.env.DB.batch(stmts);
  const synced = results.reduce((n, r) => n + (r.meta.changes ?? 0), 0);

  return c.json({ synced, skipped: items.length - synced });
});

// Pull: incremental cursor-based fetch using composite (updated_at, id) cursor
app.get("/api/v1/:entity/pull", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const rawCursor = c.req.query("cursor") ?? "";
  const device = c.req.query("device") ?? "";
  const limit = 101; // fetch one extra to detect has_more

  let cursorTime: string;
  let cursorId: string;

  if (rawCursor.includes("|")) {
    [cursorTime, cursorId] = rawCursor.split("|", 2);
  } else {
    // Sentinel matches the SQLite datetime('now') format ("YYYY-MM-DD HH:MM:SS").
    cursorTime = rawCursor || "1970-01-01 00:00:00";
    cursorId = "";
  }

  const { results } = await c.env.DB.prepare(sql.selectPage)
    .bind(cursorTime, cursorId, limit, device)
    .all<{
      id: string;
      data: string;
      deleted: number;
      updated_at: string;
      last_modified: string;
    }>();

  const hasMore = results.length === limit;
  const page = hasMore ? results.slice(0, limit - 1) : results;

  const items = page.map((row) => ({
    id: row.id,
    data: JSON.parse(row.data),
    deleted: row.deleted === 1,
    updated_at: row.updated_at,
    last_modified: row.last_modified,
  }));

  const last = page[page.length - 1];
  const newCursor = last ? `${last.updated_at}|${last.id}` : rawCursor;

  return c.json({ items, cursor: newCursor, has_more: hasMore });
});

// Soft delete with last_modified guard
app.delete("/api/v1/:entity/:id", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  const id = c.req.param("id");

  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const body: { last_modified?: string } = await c.req
    .json<{ last_modified?: string }>()
    .catch(() => ({}));

  let lastModified: string;
  if (typeof body.last_modified === "string") {
    const normalized = normalizeTimestamp(body.last_modified);
    if (normalized === null) {
      return c.json({ error: "Invalid last_modified" }, 400);
    }
    lastModified = normalized;
  } else {
    lastModified = new Date().toISOString();
  }

  const result = await c.env.DB.prepare(sql.softDelete).bind(id, lastModified).run();

  return c.json({ deleted: (result.meta.changes ?? 0) > 0 });
});

// Purge soft-deleted records older than 30 days (manual trigger;
// also runs on the scheduled cron defined in wrangler.toml)
app.post("/api/v1/purge", async (c) => {
  return c.json({ purged: await purgeExpired(c.env.DB) });
});

export default {
  fetch: app.fetch,
  async scheduled(_event, env) {
    await purgeExpired(env.DB);
  },
} satisfies ExportedHandler<Bindings>;
