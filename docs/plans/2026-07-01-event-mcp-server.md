# Local stdio MCP Server for `event` CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Claude Desktop (which has no Bash tool) CRUD access to Apple Reminders and Calendar by wrapping the existing `event` CLI in a local, stdio-transport MCP server.

**Architecture:** A small TypeScript package (`mcp-server/`) shells out to the already-installed `event` binary (`--json` output) for every operation, translates MCP tool calls into `event` CLI invocations, and speaks the MCP protocol over stdio using the official `@modelcontextprotocol/sdk`. This is local-only — no network exposure, no OAuth, no new write-path or tag convention (still Shortcuts-based, via the `event` CLI). It does **not** address claude.ai Web/Cloud Cowork access; that requires a separate, later Cloudflare Worker + OAuth design.

**Tech Stack:** TypeScript (Node.js ≥20), `@modelcontextprotocol/sdk` (low-level `Server` API, matching the verified real-world usage in FradSer/mcp-server-apple-events), vitest, pnpm.

## Global Constraints

- Node.js `>=20.0.0` (matches the pattern used by the reference implementation FradSer/mcp-server-apple-events)
- Dependency pin: `@modelcontextprotocol/sdk@^1.29.0` — this is the stable, widely-deployed package. Do **not** use `@modelcontextprotocol/server` (a separate, `2.0.0-beta.1` package found on the SDK repo's `main`-branch README; not what production servers use).
- Transport: stdio only. No HTTP/SSE, no OAuth, no public exposure — this plan is scoped to local Claude Desktop use.
- All Reminders/Calendar mutations go through the `event` CLI (`/usr/local/bin/event` on this machine) exclusively — do not bundle a separate Swift/EventKit binary. This preserves a single tag-writing convention (Shortcuts-based) instead of introducing a second one.
- TypeScript conventions: `"type": "module"`, ES2022 target, `strict: true`, matching `skills/apple-events/references/worker/tsconfig.json`.
- Package manager: pnpm (matches the existing `skills/apple-events/references/worker/` project).
- Conventional commits (`feat:`, `fix:`, `chore:`) per this repo's `.git-agent/config.yml` convention.
- **Local commits to this worktree branch are pre-authorized** (confirmed 2026-07-01) — implementer subagents may `git commit` after each task without pausing for per-commit confirmation. **Pushing to any remote is not authorized** — no `git push` at any point in this plan without the user explicitly asking for it.
- No placeholder code; every CLI flag mapped in this plan was verified directly via `event <subcommand> --help` on 2026-07-01.

---

### Task 1: `event` CLI subprocess wrapper

**Files:**
- Create: `mcp-server/package.json`
- Create: `mcp-server/tsconfig.json`
- Create: `mcp-server/.gitignore`
- Create: `mcp-server/src/eventCli.ts`
- Create: `mcp-server/test/fixtures/echo-args.mjs`
- Create: `mcp-server/test/fixtures/fake-event-fail.mjs`
- Test: `mcp-server/test/eventCli.test.ts`

**Interfaces:**
- Produces: `runEventCli(args: string[]): Promise<unknown>` — spawns the `event` binary, parses stdout as JSON.
- Produces: `runEventCliText(args: string[]): Promise<string>` — spawns the `event` binary, returns trimmed raw stdout (for commands like `delete` that don't support `--json`).
- Produces: `valueArgs(entries: Array<[string, string | number | undefined]>): string[]` — builds `--flag value` pairs, skipping `undefined` values.
- Produces: `flagArgs(entries: Array<[string, boolean | undefined]>): string[]` — builds presence-only `--flag` entries when `true`.
- Produces: `class EventCliError extends Error` with `stderr: string` and `exitCode: number | null`.
- Produces: `eventBinPath(): string` — resolves `process.env.EVENT_BIN ?? "event"`.

- [ ] **Step 1: Create the package scaffold**

Create `mcp-server/package.json`:

```json
{
  "name": "event-mcp-server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": {
    "event-mcp-server": "./dist/index.js"
  },
  "engines": {
    "node": ">=20.0.0"
  },
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",
    "test": "vitest run",
    "typecheck": "tsc -p tsconfig.json --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.29.0"
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
    "typescript": "^5.5.0",
    "vitest": "~4.1.6"
  }
}
```

Create `mcp-server/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "types": ["node"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "noImplicitAny": true,
    "skipLibCheck": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  },
  "include": ["src/**/*.ts"]
}
```

Create `mcp-server/.gitignore`:

```
node_modules/
dist/
```

- [ ] **Step 2: Install dependencies**

Run: `cd mcp-server && pnpm install`
Expected: `pnpm-lock.yaml` created, `node_modules/` populated, no errors.

- [ ] **Step 3: Write the failing tests for the CLI wrapper**

Create `mcp-server/test/fixtures/echo-args.mjs` (executable fake binary that echoes back whatever argv it received, as JSON):

```js
#!/usr/bin/env node
process.stdout.write(JSON.stringify({ receivedArgs: process.argv.slice(2) }));
```

Create `mcp-server/test/fixtures/fake-event-fail.mjs` (executable fake binary simulating a CLI error):

```js
#!/usr/bin/env node
process.stderr.write("Error: Not found: reminder does not exist");
process.exit(1);
```

Create `mcp-server/test/eventCli.test.ts`:

```ts
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
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `cd mcp-server && pnpm test`
Expected: FAIL — `Cannot find module '../src/eventCli.js'` (module doesn't exist yet).

- [ ] **Step 5: Implement the wrapper**

Create `mcp-server/src/eventCli.ts`:

```ts
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export class EventCliError extends Error {
  readonly stderr: string;
  readonly exitCode: number | null;

  constructor(message: string, stderr: string, exitCode: number | null) {
    super(message);
    this.name = "EventCliError";
    this.stderr = stderr;
    this.exitCode = exitCode;
  }
}

export function eventBinPath(): string {
  return process.env.EVENT_BIN ?? "event";
}

async function execEventCli(args: string[]): Promise<string> {
  try {
    const { stdout } = await execFileAsync(eventBinPath(), args);
    return stdout.trim();
  } catch (error) {
    const execError = error as { code?: number | null; stderr?: string; message: string };
    throw new EventCliError(
      `event CLI failed: ${execError.message}`,
      execError.stderr ?? "",
      execError.code ?? null,
    );
  }
}

export async function runEventCli(args: string[]): Promise<unknown> {
  const output = await execEventCli(args);
  if (output.length === 0) {
    return null;
  }
  return JSON.parse(output);
}

export async function runEventCliText(args: string[]): Promise<string> {
  return execEventCli(args);
}

export function valueArgs(
  entries: Array<[string, string | number | undefined]>,
): string[] {
  const args: string[] = [];
  for (const [flag, value] of entries) {
    if (value === undefined) continue;
    args.push(flag, String(value));
  }
  return args;
}

export function flagArgs(entries: Array<[string, boolean | undefined]>): string[] {
  const args: string[] = [];
  for (const [flag, present] of entries) {
    if (present) args.push(flag);
  }
  return args;
}
```

- [ ] **Step 6: Make the fixtures executable**

Run: `chmod +x mcp-server/test/fixtures/echo-args.mjs mcp-server/test/fixtures/fake-event-fail.mjs`
Expected: no output, exit code 0.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd mcp-server && pnpm test`
Expected: PASS — 3 tests green (`runEventCli` × 2, `runEventCliText` × 1).

- [ ] **Step 8: Commit**

```bash
cd mcp-server && git add package.json tsconfig.json .gitignore src/eventCli.ts test/eventCli.test.ts test/fixtures/
git commit -m "feat(mcp-server): add event CLI subprocess wrapper"
```

(Local commit to this worktree branch, no push — per Global Constraints.)

---

### Task 2: MCP tool definitions and handlers

**Files:**
- Create: `mcp-server/src/tools/remindersTasks.ts`
- Create: `mcp-server/src/tools/remindersLists.ts`
- Create: `mcp-server/src/tools/calendarEvents.ts`
- Test: `mcp-server/test/tools/remindersTasks.test.ts`
- Test: `mcp-server/test/tools/remindersLists.test.ts`
- Test: `mcp-server/test/tools/calendarEvents.test.ts`

**Interfaces:**
- Consumes: `runEventCli`, `runEventCliText`, `valueArgs`, `flagArgs` from `../eventCli.js` (Task 1).
- Produces: `remindersTasksTool: Tool`, `handleRemindersTasks(args: Record<string, unknown>): Promise<CallToolResult>`.
- Produces: `remindersListsTool: Tool`, `handleRemindersLists(args: Record<string, unknown>): Promise<CallToolResult>`.
- Produces: `calendarEventsTool: Tool`, `handleCalendarEvents(args: Record<string, unknown>): Promise<CallToolResult>`.
- `Tool` and `CallToolResult` types come from `@modelcontextprotocol/sdk/types.js`.

- [ ] **Step 1: Write the failing test for `reminders_tasks`**

Create `mcp-server/test/tools/remindersTasks.test.ts`:

```ts
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mcp-server && pnpm test -- remindersTasks`
Expected: FAIL — `Cannot find module '../../src/tools/remindersTasks.js'`.

- [ ] **Step 3: Implement `reminders_tasks`**

Create `mcp-server/src/tools/remindersTasks.ts`:

```ts
import type { CallToolResult, Tool } from "@modelcontextprotocol/sdk/types.js";
import { flagArgs, runEventCli, runEventCliText, valueArgs } from "../eventCli.js";

export const remindersTasksTool: Tool = {
  name: "reminders_tasks",
  description: "Manage Apple Reminders tasks. Actions: list, create, update, delete, search.",
  inputSchema: {
    type: "object",
    properties: {
      action: {
        type: "string",
        enum: ["list", "create", "update", "delete", "search"],
        description: "The operation to perform.",
      },
      id: { type: "string", description: "Reminder ID (required for update, delete)." },
      title: { type: "string", description: "Reminder title (required for create)." },
      list: { type: "string", description: "List name to filter by or create in." },
      due: { type: "string", description: "Due date, format yyyy-MM-dd HH:mm:ss." },
      clearDue: { type: "boolean", description: "Remove the due date (update only)." },
      start: { type: "string", description: "Start date, format yyyy-MM-dd HH:mm:ss (update only)." },
      clearStart: { type: "boolean", description: "Remove the start date (update only)." },
      priority: { type: "integer", enum: [0, 1, 5, 9], description: "0=none, 1=high, 5=medium, 9=low." },
      notes: { type: "string", description: "Reminder notes." },
      url: { type: "string", description: "URL to associate with the reminder." },
      tags: { type: "string", description: "Comma-separated tags." },
      parentTitle: { type: "string", description: "Parent reminder title, to create/convert to a subtask." },
      flagged: { type: "boolean", description: "Mark as flagged." },
      location: { type: "string", description: "Location trigger name, e.g. 'Home'." },
      latitude: { type: "number", description: "Location trigger latitude." },
      longitude: { type: "number", description: "Location trigger longitude." },
      radius: { type: "number", description: "Geofence radius in meters, default 100." },
      proximity: { type: "string", enum: ["enter", "leave"], description: "Location trigger proximity." },
      clearLocation: { type: "boolean", description: "Remove location-based alarms (update only)." },
      completed: {
        type: "boolean",
        description: "For update: mark as completed/uncompleted. For list/search: include completed reminders.",
      },
      keyword: { type: "string", description: "Search keyword (required for search)." },
    },
    required: ["action"],
  },
};

export async function handleRemindersTasks(args: Record<string, unknown>): Promise<CallToolResult> {
  const action = args.action as string;

  switch (action) {
    case "list": {
      const cliArgs = [
        "reminders",
        "list",
        ...valueArgs([["--list", args.list as string | undefined]]),
        ...flagArgs([["--completed", args.completed as boolean | undefined]]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "search": {
      const cliArgs = [
        "reminders",
        "search",
        "--keyword",
        String(args.keyword),
        ...valueArgs([["--list", args.list as string | undefined]]),
        ...flagArgs([["--completed", args.completed as boolean | undefined]]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "create": {
      const cliArgs = [
        "reminders",
        "create",
        "--title",
        String(args.title),
        ...valueArgs([
          ["--list", args.list as string | undefined],
          ["--due", args.due as string | undefined],
          ["--priority", args.priority as number | undefined],
          ["--notes", args.notes as string | undefined],
          ["--url", args.url as string | undefined],
          ["--tags", args.tags as string | undefined],
          ["--parent-title", args.parentTitle as string | undefined],
          ["--flagged", args.flagged === undefined ? undefined : String(args.flagged)],
          ["--location", args.location as string | undefined],
          ["--latitude", args.latitude as number | undefined],
          ["--longitude", args.longitude as number | undefined],
          ["--radius", args.radius as number | undefined],
          ["--proximity", args.proximity as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "update": {
      const cliArgs = [
        "reminders",
        "update",
        "--id",
        String(args.id),
        ...valueArgs([
          ["--title", args.title as string | undefined],
          ["--completed", args.completed === undefined ? undefined : String(args.completed)],
          ["--priority", args.priority as number | undefined],
          ["--due", args.due as string | undefined],
          ["--start", args.start as string | undefined],
          ["--notes", args.notes as string | undefined],
          ["--tags", args.tags as string | undefined],
          ["--url", args.url as string | undefined],
          ["--parent-title", args.parentTitle as string | undefined],
          ["--flagged", args.flagged === undefined ? undefined : String(args.flagged)],
          ["--location", args.location as string | undefined],
          ["--latitude", args.latitude as number | undefined],
          ["--longitude", args.longitude as number | undefined],
          ["--radius", args.radius as number | undefined],
          ["--proximity", args.proximity as string | undefined],
        ]),
        ...flagArgs([
          ["--clear-due", args.clearDue as boolean | undefined],
          ["--clear-start", args.clearStart as boolean | undefined],
          ["--clear-location", args.clearLocation as boolean | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "delete": {
      const result = await runEventCliText(["reminders", "delete", "--id", String(args.id)]);
      return { content: [{ type: "text", text: result }] };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown action for reminders_tasks: ${String(action)}` }],
        isError: true,
      };
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mcp-server && pnpm test -- remindersTasks`
Expected: PASS — 6 tests green.

- [ ] **Step 5: Write the failing test for `reminders_lists`**

Create `mcp-server/test/tools/remindersLists.test.ts`:

```ts
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
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `cd mcp-server && pnpm test -- remindersLists`
Expected: FAIL — `Cannot find module '../../src/tools/remindersLists.js'`.

- [ ] **Step 7: Implement `reminders_lists`**

Create `mcp-server/src/tools/remindersLists.ts`:

```ts
import type { CallToolResult, Tool } from "@modelcontextprotocol/sdk/types.js";
import { runEventCli, runEventCliText } from "../eventCli.js";

export const remindersListsTool: Tool = {
  name: "reminders_lists",
  description: "Manage Apple Reminders lists. Actions: list, create, update, delete.",
  inputSchema: {
    type: "object",
    properties: {
      action: {
        type: "string",
        enum: ["list", "create", "update", "delete"],
        description: "The operation to perform.",
      },
      id: { type: "string", description: "List ID (required for update, delete)." },
      name: { type: "string", description: "List name (required for create, update)." },
    },
    required: ["action"],
  },
};

export async function handleRemindersLists(args: Record<string, unknown>): Promise<CallToolResult> {
  const action = args.action as string;

  switch (action) {
    case "list": {
      const result = await runEventCli(["reminders", "lists", "list", "--json"]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "create": {
      const result = await runEventCli([
        "reminders",
        "lists",
        "create",
        "--name",
        String(args.name),
        "--json",
      ]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "update": {
      const result = await runEventCli([
        "reminders",
        "lists",
        "update",
        "--id",
        String(args.id),
        "--name",
        String(args.name),
        "--json",
      ]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "delete": {
      const result = await runEventCliText(["reminders", "lists", "delete", "--id", String(args.id)]);
      return { content: [{ type: "text", text: result }] };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown action for reminders_lists: ${String(action)}` }],
        isError: true,
      };
  }
}
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `cd mcp-server && pnpm test -- remindersLists`
Expected: PASS — 5 tests green.

- [ ] **Step 9: Write the failing test for `calendar_events`**

Create `mcp-server/test/tools/calendarEvents.test.ts`:

```ts
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
```

- [ ] **Step 10: Run the test to verify it fails**

Run: `cd mcp-server && pnpm test -- calendarEvents`
Expected: FAIL — `Cannot find module '../../src/tools/calendarEvents.js'`.

- [ ] **Step 11: Implement `calendar_events`**

Create `mcp-server/src/tools/calendarEvents.ts`:

```ts
import type { CallToolResult, Tool } from "@modelcontextprotocol/sdk/types.js";
import { runEventCli, runEventCliText, valueArgs } from "../eventCli.js";

export const calendarEventsTool: Tool = {
  name: "calendar_events",
  description: "Manage Apple Calendar events. Actions: list, create, update, delete.",
  inputSchema: {
    type: "object",
    properties: {
      action: {
        type: "string",
        enum: ["list", "create", "update", "delete"],
        description: "The operation to perform.",
      },
      id: { type: "string", description: "Event ID (required for update, delete)." },
      title: { type: "string", description: "Event title (required for create)." },
      start: {
        type: "string",
        description: "Start date. yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed.",
      },
      end: {
        type: "string",
        description: "End date. yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed.",
      },
      calendar: { type: "string", description: "Calendar name, to filter (list) or target (create)." },
      location: { type: "string", description: "Event location." },
      notes: { type: "string", description: "Event notes." },
      span: {
        type: "string",
        enum: ["this", "future", "all"],
        description: "Delete span for recurring events, default 'this'.",
      },
    },
    required: ["action"],
  },
};

export async function handleCalendarEvents(args: Record<string, unknown>): Promise<CallToolResult> {
  const action = args.action as string;

  switch (action) {
    case "list": {
      const cliArgs = [
        "calendar",
        "list",
        ...valueArgs([
          ["--start", args.start as string | undefined],
          ["--end", args.end as string | undefined],
          ["--calendar", args.calendar as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "create": {
      const cliArgs = [
        "calendar",
        "create",
        "--title",
        String(args.title),
        "--start",
        String(args.start),
        "--end",
        String(args.end),
        ...valueArgs([
          ["--calendar", args.calendar as string | undefined],
          ["--location", args.location as string | undefined],
          ["--notes", args.notes as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "update": {
      const cliArgs = [
        "calendar",
        "update",
        "--id",
        String(args.id),
        ...valueArgs([
          ["--title", args.title as string | undefined],
          ["--start", args.start as string | undefined],
          ["--end", args.end as string | undefined],
          ["--location", args.location as string | undefined],
          ["--notes", args.notes as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "delete": {
      const cliArgs = [
        "calendar",
        "delete",
        "--id",
        String(args.id),
        ...valueArgs([["--span", args.span as string | undefined]]),
      ];
      const result = await runEventCliText(cliArgs);
      return { content: [{ type: "text", text: result }] };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown action for calendar_events: ${String(action)}` }],
        isError: true,
      };
  }
}
```

- [ ] **Step 12: Run the test to verify it passes**

Run: `cd mcp-server && pnpm test -- calendarEvents`
Expected: PASS — 5 tests green.

- [ ] **Step 13: Run the full test suite**

Run: `cd mcp-server && pnpm test`
Expected: PASS — all 19 tests green (3 from Task 1 + 16 from Task 2).

- [ ] **Step 14: Commit**

```bash
cd mcp-server && git add src/tools/ test/tools/
git commit -m "feat(mcp-server): add reminders_tasks, reminders_lists, calendar_events tools"
```

(Local commit to this worktree branch, no push — per Global Constraints.)

---

### Task 3: MCP server wiring and stdio transport

**Files:**
- Create: `mcp-server/src/server.ts`
- Create: `mcp-server/src/index.ts`
- Test: `mcp-server/test/server.test.ts`

**Interfaces:**
- Consumes: `remindersTasksTool`, `handleRemindersTasks` from `./tools/remindersTasks.js`; `remindersListsTool`, `handleRemindersLists` from `./tools/remindersLists.js`; `calendarEventsTool`, `handleCalendarEvents` from `./tools/calendarEvents.js` (all Task 2).
- Produces: `TOOLS: Tool[]`, `resolveHandler(toolName: string): ((args: Record<string, unknown>) => Promise<CallToolResult>) | undefined`, `createServer(): Server` from `src/server.ts`.

- [ ] **Step 1: Write the failing test for tool wiring**

Create `mcp-server/test/server.test.ts`:

```ts
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mcp-server && pnpm test -- server.test`
Expected: FAIL — `Cannot find module '../src/server.js'`.

- [ ] **Step 3: Implement the server wiring**

Create `mcp-server/src/server.ts`:

```ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolResult,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { calendarEventsTool, handleCalendarEvents } from "./tools/calendarEvents.js";
import { remindersListsTool, handleRemindersLists } from "./tools/remindersLists.js";
import { remindersTasksTool, handleRemindersTasks } from "./tools/remindersTasks.js";

export const TOOLS: Tool[] = [remindersTasksTool, remindersListsTool, calendarEventsTool];

type ToolHandler = (args: Record<string, unknown>) => Promise<CallToolResult>;

const HANDLERS: Record<string, ToolHandler> = {
  reminders_tasks: handleRemindersTasks,
  reminders_lists: handleRemindersLists,
  calendar_events: handleCalendarEvents,
};

export function resolveHandler(toolName: string): ToolHandler | undefined {
  return HANDLERS[toolName];
}

export function createServer(): Server {
  const server = new Server(
    { name: "event-mcp-server", version: "0.1.0" },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const handler = resolveHandler(request.params.name);
    if (!handler) {
      return {
        content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }],
        isError: true,
      };
    }
    return handler((request.params.arguments as Record<string, unknown>) ?? {});
  });

  return server;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mcp-server && pnpm test -- server.test`
Expected: PASS — 3 tests green.

- [ ] **Step 5: Create the entrypoint**

Create `mcp-server/src/index.ts`:

```ts
#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./server.js";

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`event-mcp-server failed to start: ${message}\n`);
  process.exit(1);
});
```

- [ ] **Step 6: Build**

Run: `cd mcp-server && pnpm build`
Expected: `dist/index.js`, `dist/server.js`, `dist/eventCli.js`, `dist/tools/*.js` created, no TypeScript errors.

- [ ] **Step 7: Run the full test suite one more time**

Run: `cd mcp-server && pnpm test`
Expected: PASS — all 22 tests green.

- [ ] **Step 8: Manual smoke test with the MCP Inspector**

Run: `cd mcp-server && npx @modelcontextprotocol/inspector node dist/index.js`
Expected: Inspector opens in the browser; clicking "List Tools" shows `reminders_tasks`, `reminders_lists`, `calendar_events`; calling `reminders_tasks` with `{"action": "list"}` returns real reminder data from EventKit (may trigger a one-time Reminders permission dialog).

- [ ] **Step 9: Commit**

```bash
cd mcp-server && git add src/server.ts src/index.ts test/server.test.ts
git commit -m "feat(mcp-server): wire up MCP server with stdio transport"
```

(Local commit to this worktree branch, no push — per Global Constraints.)

---

### Task 4: Claude Desktop configuration and live verification

**Files:**
- Modify: `~/Library/Application Support/Claude/claude_desktop_config.json` (outside the repo — machine-local, not committed)

**Interfaces:**
- Consumes: `mcp-server/dist/index.js` (Task 3 build output).

- [ ] **Step 1: Confirm the build path**

Run: `ls -la /Users/mvroeder/dev/apple-events-cli/mcp-server/dist/index.js`
Expected: file exists (built in Task 3, Step 6).

- [ ] **Step 2: Add the server to Claude Desktop's config**

Read the existing config first (it may already have other `mcpServers` entries that must be preserved):

Run: `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json 2>&1 || echo "does not exist yet"`

Add (merge, don't overwrite) this entry under `mcpServers`:

```json
{
  "mcpServers": {
    "event": {
      "command": "node",
      "args": ["/Users/mvroeder/dev/apple-events-cli/mcp-server/dist/index.js"]
    }
  }
}
```

Note: this uses an absolute, machine-specific path — a deliberate, flagged exception to the "no absolute paths in configs" preference, because this config file already lives outside any git repo, at a fixed per-machine location (`~/Library/Application Support/Claude/`), same as `~/.config/event-sync/config.json`. It never gets committed or shared across machines. If this is later published as an npm package (matching the reference implementation's `npx mcp-server-apple-events` pattern), the config could switch to `{"command": "npx", "args": ["-y", "event-mcp-server"]}` and drop the absolute path entirely.

- [ ] **Step 3: Restart Claude Desktop**

Quit and reopen the Claude Desktop app so it picks up the new `mcpServers` entry.

- [ ] **Step 4: Verify the tools appear**

In Claude Desktop, open the MCP tools/connectors indicator (hammer/plug icon in the message composer) and confirm `reminders_tasks`, `reminders_lists`, `calendar_events` are listed under the `event` server.

- [ ] **Step 5: End-to-end test — create, verify, clean up**

In a Claude Desktop conversation, ask Claude to create a reminder titled `[TEST] MCP server probe` with notes `Created via event-mcp-server smoke test`. Confirm:
1. Claude Desktop shows a tool-call to `reminders_tasks` with `action: "create"`.
2. The first call in the session may show a native macOS Reminders permission dialog — approve it.
3. Ask Claude to search for `MCP server probe` — confirm it finds the reminder just created.
4. Ask Claude to mark it completed, then delete it via the `reminders_tasks` `delete` action.
5. Confirm no error responses (`isError: true`) appeared in any of the above steps.

- [ ] **Step 6: Update the skill documentation**

Add this section to `skills/apple-events/SKILL.md`, directly after the existing "## Setup & Constraints" section (before "## General Usage"):

```markdown
## Claude Desktop (MCP server)

Claude Desktop has no Bash tool, so it cannot call `event` directly. Use the local
stdio MCP server in `mcp-server/` instead: build it with `pnpm build` inside
`mcp-server/`, then add it to `~/Library/Application Support/Claude/claude_desktop_config.json`:

    {
      "mcpServers": {
        "event": {
          "command": "node",
          "args": ["/absolute/path/to/apple-events-cli/mcp-server/dist/index.js"]
        }
      }
    }

Restart Claude Desktop. It exposes three tools: `reminders_tasks`, `reminders_lists`,
`calendar_events` — same underlying CLI, same Shortcuts-based tag convention, local-only
(stdio transport, no network exposure, no OAuth). It does not work from claude.ai Web.
```

(Local commit to this worktree branch, no push — per Global Constraints.)

---
