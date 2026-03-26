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

const ALLOWED_ENTITIES = new Set(["reminders", "calendar_events", "reminder_lists"]);

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
  const entity = c.req.param("entity");
  if (!ALLOWED_ENTITIES.has(entity)) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const body = await c.req.json<PushRequest>();
  const { device_id, items } = body;

  if (!device_id || !Array.isArray(items)) {
    return c.json({ error: "Missing device_id or items" }, 400);
  }

  let synced = 0;
  let skipped = 0;

  for (const item of items) {
    const existing = await c.env.DB.prepare(
      `SELECT last_modified FROM ${entity} WHERE id = ?`
    )
      .bind(item.id)
      .first<{ last_modified: string }>();

    if (!existing) {
      await c.env.DB.prepare(
        `INSERT INTO ${entity} (id, data, last_modified, updated_at) VALUES (?, ?, ?, datetime('now'))`
      )
        .bind(item.id, JSON.stringify(item.data), item.last_modified)
        .run();
      synced++;
    } else if (item.last_modified >= existing.last_modified) {
      await c.env.DB.prepare(
        `UPDATE ${entity} SET data = ?, last_modified = ?, deleted = 0, updated_at = datetime('now') WHERE id = ?`
      )
        .bind(JSON.stringify(item.data), item.last_modified, item.id)
        .run();
      synced++;
    } else {
      skipped++;
    }
  }

  return c.json({ synced, skipped });
});

// Pull: incremental cursor-based fetch using composite (updated_at, id) cursor
app.get("/api/v1/:entity/pull", async (c) => {
  const entity = c.req.param("entity");
  if (!ALLOWED_ENTITIES.has(entity)) {
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

  const { results } = await c.env.DB.prepare(
    `SELECT id, data, deleted, updated_at FROM ${entity} WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3`
  )
    .bind(cursorTime, cursorId, limit)
    .all<{ id: string; data: string; deleted: number; updated_at: string }>();

  const hasMore = results.length === limit;
  const page = hasMore ? results.slice(0, limit - 1) : results;

  const items = page.map((row) => ({
    id: row.id,
    data: JSON.parse(row.data),
    deleted: row.deleted === 1,
    updated_at: row.updated_at,
  }));

  const last = page[page.length - 1];
  const newCursor = last ? `${last.updated_at}|${last.id}` : rawCursor;

  return c.json({ items, cursor: newCursor, has_more: hasMore });
});

// Soft delete
app.delete("/api/v1/:entity/:id", async (c) => {
  const entity = c.req.param("entity");
  const id = c.req.param("id");

  if (!ALLOWED_ENTITIES.has(entity)) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  await c.env.DB.prepare(
    `UPDATE ${entity} SET deleted = 1, updated_at = datetime('now') WHERE id = ?`
  )
    .bind(id)
    .run();

  return c.json({ deleted: true });
});

export default app;
