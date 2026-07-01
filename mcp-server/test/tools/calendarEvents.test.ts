import { afterEach, beforeEach, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { handleCalendarEvents } from "../../src/tools/calendarEvents.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ECHO_BIN = path.join(__dirname, "..", "fixtures", "echo-args.mjs");
const originalEventBin = process.env.EVENT_BIN;

beforeEach(() => {
  process.env.EVENT_BIN = ECHO_BIN;
});

afterEach(() => {
  if (originalEventBin === undefined) {
    delete process.env.EVENT_BIN;
  } else {
    process.env.EVENT_BIN = originalEventBin;
  }
});

function receivedArgs(result: { content: Array<{ type: string; text: string }> }): string[] {
  return (JSON.parse(result.content[0].text) as { receivedArgs: string[] }).receivedArgs;
}

describe("handleCalendarEvents", () => {
  it("builds the list command with a date range", async () => {
    const result = await handleCalendarEvents({
      action: "list",
      start: "2026-07-01",
      end: "2026-07-31",
    });
    expect(receivedArgs(result)).toEqual([
      "calendar",
      "list",
      "--start",
      "2026-07-01",
      "--end",
      "2026-07-31",
      "--json",
    ]);
  });

  it("builds the create command with title, start, end", async () => {
    const result = await handleCalendarEvents({
      action: "create",
      title: "Standup",
      start: "2026-07-02 09:00:00",
      end: "2026-07-02 09:30:00",
    });
    expect(receivedArgs(result)).toEqual([
      "calendar",
      "create",
      "--title",
      "Standup",
      "--start",
      "2026-07-02 09:00:00",
      "--end",
      "2026-07-02 09:30:00",
      "--json",
    ]);
  });

  it("builds the update command with only the changed field", async () => {
    const result = await handleCalendarEvents({ action: "update", id: "evt-1", title: "Renamed" });
    expect(receivedArgs(result)).toEqual([
      "calendar",
      "update",
      "--id",
      "evt-1",
      "--title",
      "Renamed",
      "--json",
    ]);
  });

  it("builds the delete command with span, without --json", async () => {
    const result = await handleCalendarEvents({ action: "delete", id: "evt-1", span: "all" });
    expect(receivedArgs(result)).toEqual(["calendar", "delete", "--id", "evt-1", "--span", "all"]);
  });

  it("returns an error result for an unknown action", async () => {
    const result = await handleCalendarEvents({ action: "bogus" });
    expect(result.isError).toBe(true);
  });
});
