import { afterEach, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { TOOLS, dispatchToolCall, resolveHandler } from "../src/server.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

describe("TOOLS", () => {
  it("declares exactly the three supported tools", () => {
    expect(TOOLS.map((tool) => tool.name).sort()).toEqual([
      "calendar_events",
      "reminders_lists",
      "reminders_tasks",
    ]);
  });
});

describe("resolveHandler", () => {
  it("resolves a handler for each declared tool", () => {
    for (const tool of TOOLS) {
      expect(resolveHandler(tool.name)).toBeTypeOf("function");
    }
  });

  it("returns undefined for an unknown tool name", () => {
    expect(resolveHandler("not_a_real_tool")).toBeUndefined();
  });
});

describe("dispatchToolCall", () => {
  const originalEventBin = process.env.EVENT_BIN;

  afterEach(() => {
    if (originalEventBin === undefined) {
      delete process.env.EVENT_BIN;
    } else {
      process.env.EVENT_BIN = originalEventBin;
    }
  });

  it("returns isError with stderr text when the event CLI fails", async () => {
    process.env.EVENT_BIN = path.join(__dirname, "fixtures", "fake-event-fail.mjs");
    const result = await dispatchToolCall("reminders_tasks", { action: "list" });
    expect(result.isError).toBe(true);
    expect((result.content[0] as { type: string; text: string }).text).toContain(
      "Not found: reminder does not exist",
    );
  });

  it("returns unknown-tool error for an unregistered name", async () => {
    const result = await dispatchToolCall("not_a_real_tool", {});
    expect(result.isError).toBe(true);
  });
});
