import { describe, expect, it } from "vitest";
import { TOOLS, resolveHandler } from "../src/server.js";

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
