import { Hono } from "hono";
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

// Hardcoded SQL per entity to avoid any table-name injection risk.
// Each key maps to the full set of prepared statements needed.
type EntitySQL = {
  selectLastModified: string;
  insert: string;
  update: string;
  selectPage: string;
  softDelete: string;
};

const ENTITY_SQL: Record<string, EntitySQL> = {
  reminders: {
    selectLastModified: "SELECT last_modified FROM reminders WHERE id = ?",
    insert:
      "INSERT INTO reminders (id, data, last_modified, updated_at, source_device) VALUES (?, ?, ?, datetime('now'), ?)",
    update:
      "UPDATE reminders SET data = ?, last_modified = ?, deleted = 0, updated_at = datetime('now'), source_device = ? WHERE id = ?",
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM reminders WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE reminders SET deleted = 1, updated_at = datetime('now') WHERE id = ?",
  },
  calendar_events: {
    selectLastModified: "SELECT last_modified FROM calendar_events WHERE id = ?",
    insert:
      "INSERT INTO calendar_events (id, data, last_modified, updated_at, source_device) VALUES (?, ?, ?, datetime('now'), ?)",
    update:
      "UPDATE calendar_events SET data = ?, last_modified = ?, deleted = 0, updated_at = datetime('now'), source_device = ? WHERE id = ?",
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM calendar_events WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE calendar_events SET deleted = 1, updated_at = datetime('now') WHERE id = ?",
  },
  reminder_lists: {
    selectLastModified: "SELECT last_modified FROM reminder_lists WHERE id = ?",
    insert:
      "INSERT INTO reminder_lists (id, data, last_modified, updated_at, source_device) VALUES (?, ?, ?, datetime('now'), ?)",
    update:
      "UPDATE reminder_lists SET data = ?, last_modified = ?, deleted = 0, updated_at = datetime('now'), source_device = ? WHERE id = ?",
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM reminder_lists WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE reminder_lists SET deleted = 1, updated_at = datetime('now') WHERE id = ?",
  },
};

function getSQL(entity: string): EntitySQL | null {
  return ENTITY_SQL[entity] ?? null;
}

const app = new Hono<{ Bindings: Bindings }>();

// Auth middleware for all /api/* routes
app.use("/api/*", async (c, next) => {
  const auth = bearerAuth({ token: c.env.API_TOKEN });
  return auth(c, next);
});

// Health check (no auth required)
app.get("/health", (c) => c.json({ status: "ok" }));

// Push: batch upsert with last-write-wins
app.post("/api/v1/:entity/push", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const body = await c.req.json<PushRequest>();
  const { device_id, items } = body;

  if (!device_id || !Array.isArray(items)) {
    return c.json({ error: "Missing device_id or items" }, 400);
  }

  if (items.length === 0) {
    return c.json({ synced: 0, skipped: 0 });
  }

  // Phase 1: Batch-check existing records
  const selectStmts = items.map((item) =>
    c.env.DB.prepare(sql.selectLastModified).bind(item.id)
  );
  const selectResults = await c.env.DB.batch(selectStmts);

  // Phase 2: Determine writes
  const writeStmts: D1PreparedStatement[] = [];
  let synced = 0;
  let skipped = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const existing = selectResults[i].results[0] as
      | { last_modified: string }
      | undefined;

    if (!existing) {
      writeStmts.push(
        c.env.DB.prepare(sql.insert).bind(
          item.id,
          JSON.stringify(item.data),
          item.last_modified,
          device_id
        )
      );
      synced++;
    } else if (item.last_modified >= existing.last_modified) {
      writeStmts.push(
        c.env.DB.prepare(sql.update).bind(
          JSON.stringify(item.data),
          item.last_modified,
          device_id,
          item.id
        )
      );
      synced++;
    } else {
      skipped++;
    }
  }

  // Phase 3: Batch-execute writes
  if (writeStmts.length > 0) {
    await c.env.DB.batch(writeStmts);
  }

  return c.json({ synced, skipped });
});

// Pull: incremental cursor-based fetch using composite (updated_at, id) cursor
app.get("/api/v1/:entity/pull", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const rawCursor = c.req.query("cursor") ?? "";
  const limit = 101; // fetch one extra to detect has_more

  let cursorTime: string;
  let cursorId: string;

  if (rawCursor.includes("|")) {
    [cursorTime, cursorId] = rawCursor.split("|", 2);
  } else {
    cursorTime = rawCursor || "1970-01-01T00:00:00";
    cursorId = "";
  }

  const { results } = await c.env.DB.prepare(sql.selectPage)
    .bind(cursorTime, cursorId, limit)
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

// Soft delete
app.delete("/api/v1/:entity/:id", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  const id = c.req.param("id");

  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  await c.env.DB.prepare(sql.softDelete).bind(id).run();

  return c.json({ deleted: true });
});

export default app;
