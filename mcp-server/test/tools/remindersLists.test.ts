import { afterEach, beforeEach, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { handleRemindersLists } from "../../src/tools/remindersLists.js";

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

describe("handleRemindersLists", () => {
  it("builds the list command", async () => {
    const result = await handleRemindersLists({ action: "list" });
    expect(receivedArgs(result)).toEqual(["reminders", "lists", "list", "--json"]);
  });

  it("builds the create command with a name", async () => {
    const result = await handleRemindersLists({ action: "create", name: "Groceries" });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "lists",
      "create",
      "--name",
      "Groceries",
      "--json",
    ]);
  });

  it("builds the update command with id and name", async () => {
    const result = await handleRemindersLists({ action: "update", id: "list-1", name: "Shopping" });
    expect(receivedArgs(result)).toEqual([
      "reminders",
      "lists",
      "update",
      "--id",
      "list-1",
      "--name",
      "Shopping",
      "--json",
    ]);
  });

  it("builds the delete command without --json", async () => {
    const result = await handleRemindersLists({ action: "delete", id: "list-1" });
    expect(receivedArgs(result)).toEqual(["reminders", "lists", "delete", "--id", "list-1"]);
  });

  it("returns an error result for an unknown action", async () => {
    const result = await handleRemindersLists({ action: "bogus" });
    expect(result.isError).toBe(true);
  });
});
