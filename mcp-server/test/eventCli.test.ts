import { afterEach, beforeEach, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { EventCliError, runEventCli, runEventCliText } from "../src/eventCli.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = path.join(__dirname, "fixtures");
const originalEventBin = process.env.EVENT_BIN;

beforeEach(() => {
  delete process.env.EVENT_BIN;
});

afterEach(() => {
  if (originalEventBin === undefined) {
    delete process.env.EVENT_BIN;
  } else {
    process.env.EVENT_BIN = originalEventBin;
  }
});

describe("runEventCli", () => {
  it("parses JSON stdout from a successful call", async () => {
    process.env.EVENT_BIN = path.join(FIXTURES_DIR, "echo-args.mjs");
    const result = await runEventCli(["reminders", "list", "--json"]);
    expect(result).toEqual({ receivedArgs: ["reminders", "list", "--json"] });
  });

  it("throws EventCliError with stderr on non-zero exit", async () => {
    process.env.EVENT_BIN = path.join(FIXTURES_DIR, "fake-event-fail.mjs");
    await expect(
      runEventCli(["reminders", "update", "--id", "missing"]),
    ).rejects.toThrow(EventCliError);
  });
});

describe("runEventCliText", () => {
  it("returns trimmed raw stdout without JSON parsing", async () => {
    process.env.EVENT_BIN = path.join(FIXTURES_DIR, "echo-args.mjs");
    const result = await runEventCliText(["reminders", "delete", "--id", "abc"]);
    expect(result).toBe(
      JSON.stringify({ receivedArgs: ["reminders", "delete", "--id", "abc"] }),
    );
  });
});
