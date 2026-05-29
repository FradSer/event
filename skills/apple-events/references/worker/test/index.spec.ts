import { env, SELF } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";

const BASE = "https://example.com";
const AUTH = { Authorization: "Bearer test-token" };

// Start every test from empty tables so cases never observe each other's rows.
beforeEach(async () => {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM reminders"),
    env.DB.prepare("DELETE FROM calendar_events"),
    env.DB.prepare("DELETE FROM reminder_lists"),
  ]);
});

type PushItem = { id: string; data: unknown; last_modified: string };
type PushBody = { synced: number; skipped: number };
type PullItem = {
  id: string;
  data: unknown;
  deleted: boolean;
  updated_at: string;
  last_modified: string;
};
type PullBody = { items: PullItem[]; cursor: string; has_more: boolean };

function push(entity: string, deviceId: string, items: PushItem[]): Promise<Response> {
  return SELF.fetch(`${BASE}/api/v1/${entity}/push`, {
    method: "POST",
    headers: { ...AUTH, "Content-Type": "application/json" },
    body: JSON.stringify({ device_id: deviceId, items }),
  });
}

async function pull(
  entity: string,
  opts: { device?: string; cursor?: string } = {}
): Promise<PullBody> {
  const params = new URLSearchParams();
  if (opts.device) params.set("device", opts.device);
  if (opts.cursor) params.set("cursor", opts.cursor);
  const query = params.toString();
  const res = await SELF.fetch(
    `${BASE}/api/v1/${entity}/pull${query ? `?${query}` : ""}`,
    { headers: AUTH }
  );
  expect(res.status).toBe(200);
  return (await res.json()) as PullBody;
}

describe("health", () => {
  it("responds without auth", async () => {
    const res = await SELF.fetch(`${BASE}/health`);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });
});

describe("auth", () => {
  it("rejects API requests without a bearer token", async () => {
    const res = await SELF.fetch(`${BASE}/api/v1/reminders/pull`);
    expect(res.status).toBe(401);
  });

  it("rejects the purge endpoint without a bearer token", async () => {
    const res = await SELF.fetch(`${BASE}/api/v1/purge`, { method: "POST" });
    expect(res.status).toBe(401);
  });
});

describe("push / pull", () => {
  it("pushes an item and pulls it back from another device", async () => {
    const res = await push("reminders", "device-a", [
      { id: "r1", data: { title: "Buy milk" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ synced: 1, skipped: 0 } satisfies PushBody);

    const body = await pull("reminders", { device: "device-b" });
    expect(body.items).toHaveLength(1);
    expect(body.items[0].id).toBe("r1");
    expect(body.items[0].data).toEqual({ title: "Buy milk" });
    expect(body.items[0].deleted).toBe(false);
  });

  it("rejects a stale push via the last-write-wins guard", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "current" }, last_modified: "2026-03-10T12:00:00Z" },
    ]);
    const res = await push("reminders", "device-a", [
      { id: "r1", data: { title: "stale" }, last_modified: "2026-03-10T09:00:00Z" },
    ]);
    expect(await res.json()).toEqual({ synced: 0, skipped: 1 } satisfies PushBody);

    const body = await pull("reminders", { device: "device-b" });
    expect(body.items[0].data).toEqual({ title: "current" });
  });

  it("rejects a batch larger than the maximum", async () => {
    const items = Array.from({ length: 501 }, (_, i) => ({
      id: `r${i}`,
      data: {},
      last_modified: "2026-03-10T10:00:00Z",
    }));
    const res = await push("reminders", "device-a", items);
    expect(res.status).toBe(400);
  });

  it("rejects a malformed JSON body", async () => {
    const res = await SELF.fetch(`${BASE}/api/v1/reminders/push`, {
      method: "POST",
      headers: { ...AUTH, "Content-Type": "application/json" },
      body: "{ not json",
    });
    expect(res.status).toBe(400);
  });

  it("rejects an item with an unparseable last_modified", async () => {
    const res = await push("reminders", "device-a", [
      { id: "r1", data: {}, last_modified: "not-a-date" },
    ]);
    expect(res.status).toBe(400);
  });

  it("rejects an unknown entity", async () => {
    const res = await SELF.fetch(`${BASE}/api/v1/nonsense/pull`, { headers: AUTH });
    expect(res.status).toBe(400);
  });
});

describe("device filter", () => {
  it("excludes a device's own writes when that device pulls", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "from a" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    const ownView = await pull("reminders", { device: "device-a" });
    expect(ownView.items).toHaveLength(0);

    const otherView = await pull("reminders", { device: "device-b" });
    expect(otherView.items).toHaveLength(1);
  });
});

describe("soft delete", () => {
  it("marks an item deleted and surfaces it on pull", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "x" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    const delRes = await SELF.fetch(`${BASE}/api/v1/reminders/r1`, {
      method: "DELETE",
      headers: { ...AUTH, "Content-Type": "application/json" },
      body: JSON.stringify({ last_modified: "2026-03-10T11:00:00Z" }),
    });
    expect(await delRes.json()).toEqual({ deleted: true });

    const body = await pull("reminders", { device: "device-b" });
    expect(body.items).toHaveLength(1);
    expect(body.items[0].deleted).toBe(true);
  });
});

describe("pagination", () => {
  it("walks all results across cursor pages", async () => {
    const items = Array.from({ length: 150 }, (_, i) => ({
      id: `r${String(i).padStart(3, "0")}`,
      data: { n: i },
      last_modified: "2026-03-10T10:00:00Z",
    }));
    await push("reminders", "device-a", items);

    const first = await pull("reminders", { device: "device-b" });
    expect(first.items).toHaveLength(100);
    expect(first.has_more).toBe(true);

    const second = await pull("reminders", {
      device: "device-b",
      cursor: first.cursor,
    });
    expect(second.items).toHaveLength(50);
    expect(second.has_more).toBe(false);

    const ids = new Set([...first.items, ...second.items].map((item) => item.id));
    expect(ids.size).toBe(150);
  });
});

describe("cursor validation", () => {
  it("rejects a cursor with an empty timestamp segment", async () => {
    const res = await SELF.fetch(
      `${BASE}/api/v1/reminders/pull?cursor=${encodeURIComponent("|r1")}`,
      { headers: AUTH }
    );
    expect(res.status).toBe(400);
  });

  it("does not re-emit an item whose id contains a pipe across cursor pages", async () => {
    await push("reminders", "device-a", [
      { id: "a", data: { title: "first" }, last_modified: "2026-03-10T10:00:00Z" },
      { id: "a|b", data: { title: "piped" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    const first = await pull("reminders", { device: "device-b" });
    expect(first.items.map((item) => item.id).sort()).toEqual(["a", "a|b"]);

    // The returned cursor ends in "|a|b"; only by parsing the id segment as
    // everything after the first pipe is "a|b" excluded from the next page.
    const second = await pull("reminders", { device: "device-b", cursor: first.cursor });
    expect(second.items).toHaveLength(0);
  });
});

describe("data integrity", () => {
  it("skips rows with corrupt JSON instead of failing the pull", async () => {
    await env.DB.prepare(
      "INSERT INTO reminders (id, data, last_modified, updated_at, deleted, seq) VALUES (?, ?, ?, datetime('now'), 0, 1)"
    )
      .bind("bad-json", "{ not json", "2026-03-10T10:00:00Z")
      .run();
    await push("reminders", "device-a", [
      { id: "good", data: { title: "ok" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    const body = await pull("reminders", { device: "device-b" });
    expect(body.items.map((item) => item.id)).toEqual(["good"]);
  });
});

describe("monotonic seq cursor (migration 0002)", () => {
  // Given a device has already pulled an item (its cursor sits at the tip),
  // When that item is updated again on another device (e.g. marked completed),
  // Then the first device re-pulls the item from its stored cursor.
  // This is the core guarantee: a completion can never be stranded above a cursor.
  it("re-delivers an updated item to a device that already pulled past it", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "task", done: false }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    const firstPull = await pull("reminders", { device: "device-b" });
    expect(firstPull.items).toHaveLength(1);
    const cursorAtTip = firstPull.cursor;

    // Pulling again from the tip yields nothing (already caught up).
    const caughtUp = await pull("reminders", { device: "device-b", cursor: cursorAtTip });
    expect(caughtUp.items).toHaveLength(0);

    // The item is completed on device-a and re-pushed with a newer last_modified.
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "task", done: true }, last_modified: "2026-03-10T12:00:00Z" },
    ]);

    const afterComplete = await pull("reminders", { device: "device-b", cursor: cursorAtTip });
    expect(afterComplete.items).toHaveLength(1);
    expect(afterComplete.items[0].id).toBe("r1");
    expect(afterComplete.items[0].data).toEqual({ title: "task", done: true });
  });

  // Given rows exist with small seq values,
  // When a device pulls with a stale legacy `updated_at` timestamp cursor
  //   (the format used before migration 0002, lexically far above any seq),
  // Then the Worker restarts from the beginning instead of stranding the device.
  // Regression for the production incident where a bulk D1 write flattened every
  // row's updated_at below a device's stored cursor, yielding zero rows forever.
  it("self-heals a legacy timestamp cursor instead of stranding", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "a" }, last_modified: "2026-03-10T10:00:00Z" },
      { id: "r2", data: { title: "b" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);

    // A far-future timestamp reproduces the incident condition: the cursor sits
    // lexically/temporally above every row's wall clock, so the old
    // `updated_at > cursor` query matched nothing and stranded the device.
    const legacyCursor = "2099-12-31 23:59:59|some-old-id";
    const healed = await pull("reminders", { device: "device-b", cursor: legacyCursor });

    expect(healed.items.map((i) => i.id).sort()).toEqual(["r1", "r2"]);
    // And the cursor it hands back is a normalized integer seq cursor.
    expect(healed.cursor).toMatch(/^\d+\|/);
  });

  // The returned cursor's seq segment is a non-negative integer that advances on
  // every write -- never a wall-clock value that could move backward.
  it("advances a numeric cursor on each write", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: {}, last_modified: "2026-03-10T10:00:00Z" },
    ]);
    const first = await pull("reminders", { device: "device-b" });
    const firstSeq = Number(first.cursor.split("|")[0]);
    expect(Number.isInteger(firstSeq)).toBe(true);

    await push("reminders", "device-a", [
      { id: "r2", data: {}, last_modified: "2026-03-10T10:00:00Z" },
    ]);
    const second = await pull("reminders", { device: "device-b", cursor: first.cursor });
    const secondSeq = Number(second.cursor.split("|")[0]);
    expect(secondSeq).toBeGreaterThan(firstSeq);
  });

  // A soft delete after a device has pulled past the row still propagates,
  // because the delete bumps seq forward like any other write.
  it("delivers a soft delete to a device that already pulled the row", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: { title: "x" }, last_modified: "2026-03-10T10:00:00Z" },
    ]);
    const seen = await pull("reminders", { device: "device-b" });
    const cursorAtTip = seen.cursor;

    const delRes = await SELF.fetch(`${BASE}/api/v1/reminders/r1`, {
      method: "DELETE",
      headers: { ...AUTH, "Content-Type": "application/json" },
      body: JSON.stringify({ last_modified: "2026-03-10T11:00:00Z" }),
    });
    expect(await delRes.json()).toEqual({ deleted: true });

    const afterDelete = await pull("reminders", { device: "device-b", cursor: cursorAtTip });
    expect(afterDelete.items).toHaveLength(1);
    expect(afterDelete.items[0].id).toBe("r1");
    expect(afterDelete.items[0].deleted).toBe(true);
  });
});

describe("purge", () => {
  it("reports zero when no soft-deleted records are old enough", async () => {
    await push("reminders", "device-a", [
      { id: "r1", data: {}, last_modified: "2026-03-10T10:00:00Z" },
    ]);
    const res = await SELF.fetch(`${BASE}/api/v1/purge`, {
      method: "POST",
      headers: AUTH,
    });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      purged: { reminders: 0, calendar_events: 0, reminder_lists: 0 },
    });
  });
});
