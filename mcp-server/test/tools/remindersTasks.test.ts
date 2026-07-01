import { afterEach, beforeEach, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { handleRemindersTasks } from "../../src/tools/remindersTasks.js";

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

describe("handleRemindersTasks", () => {
  it("builds the list command with a list filter and completed flag", async () => {
    const result = await handleRemindersTasks({ action: "list", list: "Work", completed: true });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "list",
      "--list",
      "Work",
      "--completed",
      "--json",
    ]);
  });

  it("builds the create command with title and priority", async () => {
    const result = await handleRemindersTasks({ action: "create", title: "Buy milk", priority: 1 });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "create",
      "--title",
      "Buy milk",
      "--priority",
      "1",
      "--json",
    ]);
  });

  it("builds the update command with completed=true and clearDue", async () => {
    const result = await handleRemindersTasks({
      action: "update",
      id: "abc-123",
      completed: true,
      clearDue: true,
    });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "update",
      "--id",
      "abc-123",
      "--completed",
      "true",
      "--clear-due",
      "--json",
    ]);
  });

  it("builds the search command with a keyword", async () => {
    const result = await handleRemindersTasks({ action: "search", keyword: "groceries" });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "search",
      "--keyword",
      "groceries",
      "--json",
    ]);
  });

  it("builds the delete command without --json", async () => {
    const result = await handleRemindersTasks({ action: "delete", id: "abc-123" });
    expect(receivedArgs(result)).toEqual(["reminders", "delete", "--id", "abc-123"]);
  });

  it("returns an error result for an unknown action", async () => {
    const result = await handleRemindersTasks({ action: "bogus" });
    expect(result.isError).toBe(true);
  });
});
