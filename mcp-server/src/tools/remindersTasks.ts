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
