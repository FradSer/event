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
